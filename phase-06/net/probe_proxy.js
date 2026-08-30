#!/usr/bin/env node
// phase-06/net/probe_proxy.js — re-runnable test client for
// kanban_host_proxy.js, node builtins only (http, https, net, crypto, url).
//
// Usage:
//   probe_proxy.js --url <http(s)://host:port/path> --host <Host header>
//                   [--origin <Origin header>] [--expect-upgrade]
//
// Performs either a plain GET/POST-shaped request or (with
// --expect-upgrade) a raw WebSocket handshake: Connection: Upgrade,
// Upgrade: websocket, a random Sec-WebSocket-Key, Sec-WebSocket-Version: 13.
//
// Prints exactly one line to stdout:
//   UPGRADE status=<n>   — an upgrade response line was read
//   RESPONSE status=<n>  — a plain HTTP response was read
//   ERROR <msg>          — a socket/connection-level error occurred
//   TIMEOUT               — no response within 5s
//
// Exit code: 0 only when --expect-upgrade was given and status was 101, or
// (without --expect-upgrade) when any response arrived at all. Non-zero
// otherwise. 5s hard timeout in every case.
//
// Supports both http: and https: so 06-04.2 can reuse this file unchanged
// against wss://<tailnet name>:8444/api/runtime/ws.

'use strict';

const http = require('http');
const https = require('https');
const net = require('net');
const tls = require('tls');
const crypto = require('crypto');
const { URL } = require('url');

function parseArgs(argv) {
  const out = { expectUpgrade: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--url') {
      out.url = argv[++i];
    } else if (a === '--host') {
      out.host = argv[++i];
    } else if (a === '--origin') {
      out.origin = argv[++i];
    } else if (a === '--expect-upgrade') {
      out.expectUpgrade = true;
    }
  }
  return out;
}

const args = parseArgs(process.argv.slice(2));
if (!args.url || !args.host) {
  console.log('ERROR usage: probe_proxy.js --url <url> --host <Host header> [--origin <o>] [--expect-upgrade]');
  process.exit(2);
}

const TIMEOUT_MS = 5000;
let finished = false;

function finish(line, exitCode) {
  if (finished) return;
  finished = true;
  console.log(line);
  process.exit(exitCode);
}

const target = new URL(args.url);
const isHttps = target.protocol === 'https:';
const port = target.port ? Number(target.port) : isHttps ? 443 : 80;

if (args.expectUpgrade) {
  // Raw WebSocket handshake over a plain (http) or TLS-wrapped (https)
  // socket, so this file works unchanged against a loopback http:// proxy
  // now and a tailnet https:// origin in 06-04.2.
  const key = crypto.randomBytes(16).toString('base64');
  const headers = [
    `GET ${target.pathname}${target.search || ''} HTTP/1.1`,
    `Host: ${args.host}`,
    'Connection: Upgrade',
    'Upgrade: websocket',
    `Sec-WebSocket-Key: ${key}`,
    'Sec-WebSocket-Version: 13',
  ];
  if (args.origin) {
    headers.push(`Origin: ${args.origin}`);
  }
  headers.push('', '');
  const requestText = headers.join('\r\n');

  const onConnect = (socket) => {
    socket.write(requestText);
    let buf = '';
    socket.on('data', (chunk) => {
      buf += chunk.toString('latin1');
      const idx = buf.indexOf('\r\n');
      if (idx !== -1) {
        const statusLine = buf.slice(0, idx);
        const m = statusLine.match(/^HTTP\/1\.[01]\s+(\d{3})/);
        const status = m ? Number(m[1]) : 0;
        socket.destroy();
        if (status === 101) {
          finish(`UPGRADE status=${status}`, 0);
        } else {
          finish(`UPGRADE status=${status}`, 1);
        }
      }
    });
  };

  let socket;
  if (isHttps) {
    socket = tls.connect({ host: target.hostname, port, servername: target.hostname }, () => onConnect(socket));
  } else {
    socket = net.connect({ host: target.hostname, port }, () => onConnect(socket));
  }
  socket.setTimeout(TIMEOUT_MS, () => {
    socket.destroy();
    finish('TIMEOUT', 1);
  });
  socket.on('error', (err) => finish(`ERROR ${err.message}`, 1));
} else {
  const lib = isHttps ? https : http;
  const reqHeaders = { Host: args.host };
  if (args.origin) {
    reqHeaders.Origin = args.origin;
  }
  const req = lib.request(
    {
      hostname: target.hostname,
      port,
      path: `${target.pathname}${target.search || ''}`,
      method: 'GET',
      headers: reqHeaders,
      timeout: TIMEOUT_MS,
    },
    (res) => {
      // Drain the body so the socket can close cleanly; body contents are
      // not this probe's concern (callers assert on status code only).
      res.on('data', () => {});
      res.on('end', () => finish(`RESPONSE status=${res.statusCode}`, 0));
    }
  );
  req.on('timeout', () => {
    req.destroy();
    finish('TIMEOUT', 1);
  });
  req.on('error', (err) => finish(`ERROR ${err.message}`, 1));
  req.end();
}

setTimeout(() => finish('TIMEOUT', 1), TIMEOUT_MS + 500);
