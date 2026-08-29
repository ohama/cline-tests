#!/usr/bin/env node
'use strict';

// probe_fs.js — the closest available proxy to Cline's own tool loop: it
// exercises in-process fs calls (SBX-02) and child_process.execSync
// subprocesses (SBX-03) inside ONE process, which 03-RESEARCH.md verified
// empirically collapses the two enforcement surfaces into a single kernel
// mechanism (both hit identical syscalls under one Seatbelt profile).
//
// Classification rule (load-bearing, do not weaken): DENIED is credited
// ONLY for a real kernel permission denial -- an fs error whose code is
// exactly 'EPERM', or a subprocess that exited non-zero AND printed
// "Operation not permitted" on stderr. Everything else (ENOENT, EACCES,
// EISDIR, or any other error) is ERROR, never DENIED -- a missing fixture
// or a broken path must never be misread as a successful sandbox block.
//
// Reads ALLOWED_PATH / FORBIDDEN_PATH from the environment (no dependency
// on plan 03-01's config-env file). Fails fast (exit 3) if either is unset.

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const ALLOWED_PATH = process.env.ALLOWED_PATH;
const FORBIDDEN_PATH = process.env.FORBIDDEN_PATH;

if (!ALLOWED_PATH || !FORBIDDEN_PATH) {
  console.error('probe_fs.js: ALLOWED_PATH and FORBIDDEN_PATH must both be set in the environment');
  process.exit(3);
}

let succeededCount = 0;
let deniedCount = 0;
let errorCount = 0;

function emit(label, result, detail) {
  if (result === 'SUCCEEDED') succeededCount++;
  else if (result === 'DENIED') deniedCount++;
  else errorCount++;
  console.log(`PROBE ${label} ${result} ${detail}`.trimEnd());
}

function checkFs(label, fn) {
  try {
    fn();
    emit(label, 'SUCCEEDED', '');
  } catch (e) {
    if (e.code === 'EPERM') {
      emit(label, 'DENIED', 'EPERM');
    } else {
      emit(label, 'ERROR', e.code || String(e.message || e));
    }
  }
}

function checkExec(label, cmd) {
  try {
    execSync(cmd, { stdio: ['ignore', 'pipe', 'pipe'] });
    emit(label, 'SUCCEEDED', '');
  } catch (e) {
    const stderr = (e.stderr || '').toString();
    const status = e.status;
    if (status !== 0 && status != null && /Operation not permitted/.test(stderr)) {
      emit(label, 'DENIED', `status=${status}`);
    } else {
      const firstLine = stderr.trim().split('\n')[0] || '';
      emit(label, 'ERROR', `status=${status} ${firstLine}`.trim());
    }
  }
}

checkFs('inproc-read-allowed', () =>
  fs.readFileSync(path.join(ALLOWED_PATH, 'canary.txt')));

checkFs('inproc-read-forbidden', () =>
  fs.readFileSync(path.join(FORBIDDEN_PATH, 'secret.txt')));

checkFs('inproc-write-forbidden', () =>
  fs.writeFileSync(path.join(FORBIDDEN_PATH, 'probe-write.txt'), 'x'));

checkFs('inproc-write-allowed', () =>
  fs.writeFileSync(path.join(ALLOWED_PATH, 'probe-write.txt'), 'x'));

checkExec('subproc-read-forbidden',
  `/bin/cat '${path.join(FORBIDDEN_PATH, 'secret.txt')}'`);

checkExec('subproc-write-forbidden',
  `/bin/sh -c "echo x > '${path.join(FORBIDDEN_PATH, 'probe-subwrite.txt')}'"`);

// The symlink-inside-allowed-pointing-out case: escape-link lives inside
// ALLOWED_PATH but points at FORBIDDEN_PATH; the kernel must resolve it to
// its real target before checking, not the spelling used to reach it.
checkFs('escape-symlink-read', () =>
  fs.readFileSync(path.join(ALLOWED_PATH, 'escape-link', 'secret.txt')));

console.log(`PROBE-SUMMARY succeeded=${succeededCount} denied=${deniedCount} error=${errorCount}`);
process.exit(0);
