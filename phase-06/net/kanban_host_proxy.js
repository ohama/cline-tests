#!/usr/bin/env node
// phase-06/net/kanban_host_proxy.js — the Host/Origin-rewriting loopback
// reverse proxy that unblocks 06-04.
//
// WHY THIS EXISTS: 06-04 opened the planned Tailscale Serve entry and hit a
// real, previously-unknown blocker — kanban's own compiled dist/cli.js
// (getAllowedHostHeaders() in src/server/middleware.ts) hardcodes the Host
// allowlist to {localhost:<port>, 127.0.0.1:<port>} whenever kanban is
// loopback-bound, with NO CLI flag or environment variable to widen it, and
// this tailscale version's `serve` has no Host-rewrite option of its own.
// So a request arriving with the tailnet hostname in its Host header was
// rejected by kanban itself with 403 "Host not allowed." before any
// application code ran. This small process sits between `tailscale serve`
// and kanban, translating the client-presented Host/Origin into the
// loopback pair kanban already accepts.
//
// WHY NODE, NOT PYTHON3 (both are already present on this machine, neither
// adds a new dependency): node is already a hard runtime dependency of
// kanban itself — /opt/homebrew/bin/kanban is a `#!/usr/bin/env node`
// shebang script, and both existing Phase 5 plists already pin
// /opt/homebrew/bin on PATH for exactly that reason. More importantly,
// node's `http` module surfaces a WebSocket `upgrade` request as a
// first-class event carrying the raw socket (`server.on('upgrade', ...)`),
// so replaying the handshake upstream is a documented pipe, not hand-rolled
// HTTP framing. python3's stdlib `http.server` has no equivalent — it
// cannot express a protocol upgrade at all — so building this in python
// would mean hand-parsing HTTP inside a security-relevant component.
// Neither language adds a dependency; node is the one that does not
// require inventing a parser.
//
// SECURITY NOTE (repeated in phase-06/results/<UTC>-proxy/README.md): this
// proxy does not delete kanban's defense, it translates it. kanban rejects
// a non-loopback Host to stop DNS-rebinding and cross-site attacks against
// a localhost server. This proxy keeps exactly that shape by maintaining
// its own small Host allowlist (PROXY_ALLOWED_HOSTS: the tailnet name with
// and without the Serve port, plus its own loopback identity for local
// probes) and Origin allowlist (PROXY_ALLOWED_ORIGINS: the app's own
// tailnet-facing origin, plus its own loopback identity) and rejecting
// anything else itself, with the rejection never forwarded upstream. The
// only origin it ever launders into the upstream-allowed value is the
// app's own tailnet origin (https://<tailnet name>:8444). It therefore
// never becomes a way to reach kanban with an arbitrary Host or Origin,
// and because it binds loopback only (see the mandatory host argument to
// .listen() below — omitting it would bind every interface, silently
// creating a LAN path and breaking NET-02) it is not a second way into
// this machine at all — the only thing that can reach it is
// `tailscale serve`, itself connecting from loopback on behalf of an
// authenticated tailnet peer.
//
// Zero third-party dependencies: node builtins only (http, net, url).
// Nothing here is ever added to a package manifest, and no `npm install`
// is ever run for this file.
//
// Never logs request bodies or cookies — one line on listen, one line per
// rejection (method, path, offending Host/Origin).

'use strict';

const http = require('http');
const net = require('net');

function required(name) {
  const v = process.env[name];
  if (!v) {
    console.error(`kanban_host_proxy: refusing to start — missing required env var ${name}`);
    process.exit(1);
  }
  return v;
}

const PROXY_HOST = required('KANBAN_PROXY_HOST');
const PROXY_PORT = required('KANBAN_PROXY_PORT');
const UPSTREAM_HOST_HEADER = required('PROXY_UPSTREAM_HOST_HEADER');
const UPSTREAM_ORIGIN = required('PROXY_UPSTREAM_ORIGIN');
const ALLOWED_HOSTS_RAW = required('PROXY_ALLOWED_HOSTS');
const ALLOWED_ORIGINS_RAW = required('PROXY_ALLOWED_ORIGINS');
const KANBAN_HOST = required('KANBAN_HOST');
const KANBAN_PORT = required('KANBAN_PORT');

// PROXY_HOST must be the literal loopback address — never trust an
// environment override to something that is not loopback. This is layer 1
// of the three independent layers this project mandates for the loopback
// bind guarantee (this refusal-to-start check; run_kanban_proxy_service.sh
// asserting the same thing before it ever execs this file; and
// verify_network.sh's own `lsof` check that no wildcard line exists).
// Deliberately expressed without writing a wildcard-address literal
// anywhere in this file — say "a wildcard address" in prose, per the
// project's own no-wildcard-bind-in-repo gate (verify_network.sh check 13).
if (PROXY_HOST !== '127.0.0.1') {
  console.error(
    'kanban_host_proxy: refusing to start — KANBAN_PROXY_HOST must be exactly ' +
      '127.0.0.1 (a listen call with the host argument omitted, or set to ' +
      'a wildcard address, binds every interface on this machine, which ' +
      'would silently create a LAN path and break this project\'s ' +
      'loopback-only guarantee for this proxy).'
  );
  process.exit(1);
}

const PROXY_PORT_NUM = Number(PROXY_PORT);
const KANBAN_PORT_NUM = Number(KANBAN_PORT);

const ALLOWED_HOSTS = new Set(
  ALLOWED_HOSTS_RAW.split(/\s+/).filter(Boolean).map((h) => h.toLowerCase())
);
const ALLOWED_ORIGINS = new Set(
  ALLOWED_ORIGINS_RAW.split(/\s+/).filter(Boolean)
);

function logLine(msg) {
  console.log(`[${new Date().toISOString()}] ${msg}`);
}

// Shared gate used by BOTH the plain-request path and the upgrade path —
// kanban's own evaluateHost()/evaluateCors() rejects a request on either
// path identically, and this proxy mirrors that shape rather than only
// gating one of the two.
function gate(headers) {
  const hostHeader = headers['host'];
  if (!hostHeader || !ALLOWED_HOSTS.has(String(hostHeader).toLowerCase())) {
    return { ok: false, reason: 'host', offending: hostHeader };
  }
  const originHeader = headers['origin'];
  if (originHeader !== undefined && !ALLOWED_ORIGINS.has(String(originHeader))) {
    return { ok: false, reason: 'origin', offending: originHeader };
  }
  return { ok: true };
}

// -----------------------------------------------------------------------
// Plain HTTP request path.
// -----------------------------------------------------------------------
const server = http.createServer((req, res) => {
  const decision = gate(req.headers);
  if (!decision.ok) {
    logLine(
      `REJECT ${req.method} ${req.url} reason=${decision.reason} ` +
        `offending=${JSON.stringify(decision.offending || null)}`
    );
    const message = decision.reason === 'host' ? 'Host not allowed.' : 'Origin not allowed.';
    // Byte-compatible with kanban's own rejectRequest() so a rejection
    // reads identically wherever in the chain it came from.
    res.writeHead(403, {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    });
    res.end(JSON.stringify({ error: message }));
    return;
  }

  const outHeaders = Object.assign({}, req.headers);
  outHeaders['host'] = UPSTREAM_HOST_HEADER;
  if (req.headers['origin'] !== undefined) {
    outHeaders['origin'] = UPSTREAM_ORIGIN;
  }
  // Node's http.request lower-cases/dedupes headers itself; deliberately
  // no X-Forwarded-* is ever added — kanban ignores them, and adding none
  // keeps behaviour identical to a direct loopback call.

  const upstreamReq = http.request(
    {
      host: KANBAN_HOST,
      port: KANBAN_PORT_NUM,
      method: req.method,
      path: req.url,
      headers: outHeaders,
    },
    (upstreamRes) => {
      const inboundOrigin = req.headers['origin'];
      const respHeaders = Object.assign({}, upstreamRes.headers);
      // If we rewrote an inbound Origin and the upstream response carries
      // an Access-Control-Allow-Origin equal to the upstream-allowed
      // value, restore it to the value the actual client sent, so the
      // browser's own same-origin check (against the tailnet origin it
      // believes it is talking to) still succeeds.
      if (
        inboundOrigin !== undefined &&
        respHeaders['access-control-allow-origin'] === UPSTREAM_ORIGIN
      ) {
        respHeaders['access-control-allow-origin'] = inboundOrigin;
      }
      res.writeHead(upstreamRes.statusCode || 502, respHeaders);
      upstreamRes.pipe(res);
    }
  );

  upstreamReq.on('error', (err) => {
    logLine(`UPSTREAM ERROR ${req.method} ${req.url}: ${err.message}`);
    if (!res.headersSent) {
      res.writeHead(502, { 'Content-Type': 'application/json; charset=utf-8' });
    }
    res.end(JSON.stringify({ error: 'Upstream unavailable.' }));
  });

  req.pipe(upstreamReq);
});

// -----------------------------------------------------------------------
// WebSocket upgrade path — kanban's UI builds /api/runtime/ws,
// /api/terminal/io and /api/terminal/control as WebSockets from
// window.location.host (confirmed by reading the shipped bundle
// dist/web-ui/assets/index-*.js), so a proxy that handled only plain HTTP
// would serve the first page perfectly and then be silently dead for live
// card updates and the terminal panes. This is what makes those live.
// -----------------------------------------------------------------------
server.on('upgrade', (req, clientSocket, head) => {
  const decision = gate(req.headers);
  if (!decision.ok) {
    logLine(
      `REJECT-UPGRADE ${req.method} ${req.url} reason=${decision.reason} ` +
        `offending=${JSON.stringify(decision.offending || null)}`
    );
    // Same shape as kanban's own rejectSocket().
    clientSocket.write('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n');
    clientSocket.destroy();
    return;
  }

  const outHeaders = Object.assign({}, req.headers);
  outHeaders['host'] = UPSTREAM_HOST_HEADER;
  if (req.headers['origin'] !== undefined) {
    outHeaders['origin'] = UPSTREAM_ORIGIN;
  }

  const upstreamSocket = net.connect(KANBAN_PORT_NUM, KANBAN_HOST, () => {
    const headerLines = Object.keys(outHeaders)
      .map((k) => `${k}: ${outHeaders[k]}`)
      .join('\r\n');
    upstreamSocket.write(`${req.method} ${req.url} HTTP/1.1\r\n${headerLines}\r\n\r\n`);
    if (head && head.length) {
      upstreamSocket.write(head);
    }
    upstreamSocket.pipe(clientSocket);
    clientSocket.pipe(upstreamSocket);
  });

  const destroyBoth = () => {
    upstreamSocket.destroy();
    clientSocket.destroy();
  };
  upstreamSocket.on('error', destroyBoth);
  upstreamSocket.on('close', destroyBoth);
  clientSocket.on('error', destroyBoth);
  clientSocket.on('close', destroyBoth);
});

server.on('clientError', (err, socket) => {
  if (socket.writable) {
    socket.destroy();
  }
});

// The host argument to .listen() is MANDATORY here — node's
// server.listen(port) with the host omitted binds every interface on this
// machine, which would silently create a LAN path and break this
// project's loopback-only guarantee for this proxy (NET-02). Never omit
// it, and never pass anything but the literal 127.0.0.1 validated above.
server.listen(PROXY_PORT_NUM, PROXY_HOST, () => {
  logLine(
    `kanban_host_proxy listening on ${PROXY_HOST}:${PROXY_PORT_NUM} -> ` +
      `upstream http://${KANBAN_HOST}:${KANBAN_PORT_NUM} ` +
      `(allowed hosts: ${Array.from(ALLOWED_HOSTS).join(', ')})`
  );
});
