#!/usr/bin/env node
/**
 * GSD Update Checker
 *
 * Checks for GSD updates in background, writes result to cache.
 * Called by SessionStart hook - runs once per session.
 *
 * Features:
 * - 24-hour cache TTL (skip check if recent)
 * - Centralized error logging via gsd-logger
 * - Graceful fallback on failures
 * - Proper semver comparison
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawn } = require('child_process');

// Try to load logger (may not exist in older installations)
let logger;
try {
  logger = require('./gsd-logger');
} catch {
  logger = {
    info: () => {},
    error: () => {},
    debug: () => {}
  };
}

const homeDir = os.homedir();
const cwd = process.cwd();
const cacheDir = path.join(homeDir, '.claude', 'cache');
const cacheFile = path.join(cacheDir, 'gsd-update-check.json');
const logDir = path.join(homeDir, '.claude', 'logs');

// Cache TTL in seconds (24 hours)
const CACHE_TTL_SECONDS = 24 * 60 * 60;

// VERSION file locations (check project first, then global)
const projectVersionFile = path.join(cwd, '.claude', 'get-shit-done', 'VERSION');
const globalVersionFile = path.join(homeDir, '.claude', 'get-shit-done', 'VERSION');

// Ensure cache directory exists
if (!fs.existsSync(cacheDir)) {
  fs.mkdirSync(cacheDir, { recursive: true });
}

// Check if cache is still valid
function isCacheValid() {
  if (!fs.existsSync(cacheFile)) {
    logger.debug('gsd-check-update', 'Cache file not found, will check');
    return false;
  }
  try {
    const cache = JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
    const age = Math.floor(Date.now() / 1000) - (cache.checked || 0);
    const valid = age < CACHE_TTL_SECONDS;
    logger.debug('gsd-check-update', `Cache age: ${Math.round(age/3600)}h, valid: ${valid}`);
    return valid;
  } catch (err) {
    logger.error('gsd-check-update', 'Error reading cache', err);
    return false;
  }
}

// Skip if cache is still valid
if (isCacheValid()) {
  logger.debug('gsd-check-update', 'Using cached result');
  process.exit(0);
}

logger.info('gsd-check-update', 'Starting update check');

// Ensure log directory exists
if (!fs.existsSync(logDir)) {
  try {
    fs.mkdirSync(logDir, { recursive: true });
  } catch {}
}

const logFile = path.join(logDir, 'gsd-hooks.log');

// Run check in background (spawn background process)
const child = spawn(process.execPath, ['-e', `
  const fs = require('fs');
  const { execSync } = require('child_process');

  const cacheFile = ${JSON.stringify(cacheFile)};
  const logFile = ${JSON.stringify(logFile)};
  const projectVersionFile = ${JSON.stringify(projectVersionFile)};
  const globalVersionFile = ${JSON.stringify(globalVersionFile)};

  function log(level, message) {
    const timestamp = new Date().toISOString();
    const logLine = timestamp + ' [' + level.toUpperCase() + '] [gsd-check-update] ' + message + '\\n';
    try {
      fs.appendFileSync(logFile, logLine);
    } catch {}
  }

  // Check project directory first (local install), then global
  let installed = '0.0.0';
  let versionSource = 'none';
  try {
    if (fs.existsSync(projectVersionFile)) {
      installed = fs.readFileSync(projectVersionFile, 'utf8').trim();
      versionSource = 'project';
    } else if (fs.existsSync(globalVersionFile)) {
      installed = fs.readFileSync(globalVersionFile, 'utf8').trim();
      versionSource = 'global';
    }
  } catch (e) {
    log('error', 'Error reading VERSION: ' + e.message);
  }

  let latest = null;
  let error = null;
  try {
    latest = execSync('npm view get-shit-done-cc version', {
      encoding: 'utf8',
      timeout: 15000,
      windowsHide: true,
      stdio: ['ignore', 'pipe', 'ignore']
    }).trim();
  } catch (e) {
    error = e.message;
    log('error', 'Error checking npm: ' + error);
  }

  // Compare versions properly (semver comparison)
  function compareVersions(v1, v2) {
    if (!v1 || !v2) return false;
    const parts1 = v1.split('.').map(Number);
    const parts2 = v2.split('.').map(Number);
    for (let i = 0; i < 3; i++) {
      const p1 = parts1[i] || 0;
      const p2 = parts2[i] || 0;
      if (p1 < p2) return true;  // v1 < v2, update available
      if (p1 > p2) return false;
    }
    return false; // equal
  }

  const updateAvailable = latest && compareVersions(installed, latest);

  const result = {
    update_available: updateAvailable,
    installed,
    installed_source: versionSource,
    latest: latest || 'unknown',
    checked: Math.floor(Date.now() / 1000),
    error: error || null
  };

  fs.writeFileSync(cacheFile, JSON.stringify(result, null, 2));
  log('info', 'Check complete: installed=' + installed + ' latest=' + (latest || 'unknown') + ' update=' + updateAvailable);
`], {
  stdio: 'ignore',
  detached: true,
  windowsHide: true
});

child.unref();
