#!/usr/bin/env node
/**
 * Claude Code Statusline - GSD + Ohama Edition
 *
 * Shows: [update] model | task | dir | context | 5h usage | 7d usage
 *
 * Features:
 * - Color-coded context usage bar
 * - Current task display from todos
 * - GSD update notification
 * - OAuth-based usage API (5h session + 7d weekly with reset times)
 * - GSD project state (.planning/STATE.md)
 * - Error logging to centralized log
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const https = require('https');

// Try to load logger (may not exist in older installations)
let logger;
try {
  logger = require('./gsd-logger');
} catch {
  logger = {
    error: () => {},
    debug: () => {}
  };
}

const homeDir = os.homedir();

// ANSI color helpers
const dim = s => `\x1b[2m${s}\x1b[22m`;
const bold = s => `\x1b[1m${s}\x1b[22m`;
const green = s => `\x1b[32m${s}\x1b[39m`;
const yellow = s => `\x1b[33m${s}\x1b[39m`;
const red = s => `\x1b[31m${s}\x1b[39m`;
const cyan = s => `\x1b[36m${s}\x1b[39m`;
const magenta = s => `\x1b[35m${s}\x1b[39m`;
const orange = s => `\x1b[38;5;208m${s}\x1b[39m`;
const blink = s => `\x1b[5m${s}\x1b[25m`;

// ============================================================
// Model name shortener
// ============================================================
function shortenModelName(name) {
  const shortNames = {
    'Claude Opus 4.5': 'Opus4.5',
    'Claude Sonnet 4': 'Sonnet4',
    'Claude Haiku 3.5': 'Haiku3.5',
    'claude-opus-4-5-20251101': 'Opus4.5',
    'claude-sonnet-4-20250514': 'Sonnet4',
    'claude-haiku-3-5-20241022': 'Haiku3.5',
  };
  return shortNames[name] || name;
}

// ============================================================
// Usage API (OAuth-based rate limit fetching)
// ============================================================
const CACHE_TTL_SUCCESS_MS = 30 * 1000;
const CACHE_TTL_FAILURE_MS = 15 * 1000;
const API_TIMEOUT_MS = 3000;

function getUsageCachePath() {
  return path.join(homeDir, '.claude/hud/.usage-cache.json');
}

function readUsageCache() {
  try {
    const cachePath = getUsageCachePath();
    if (!fs.existsSync(cachePath)) return null;
    const cache = JSON.parse(fs.readFileSync(cachePath, 'utf-8'));
    // Parse date strings back to Date objects
    if (cache.data) {
      if (cache.data.fiveHourResetsAt) {
        cache.data.fiveHourResetsAt = new Date(cache.data.fiveHourResetsAt);
      }
      if (cache.data.weeklyResetsAt) {
        cache.data.weeklyResetsAt = new Date(cache.data.weeklyResetsAt);
      }
    }
    return cache;
  } catch {
    return null;
  }
}

function writeUsageCache(data, error = false) {
  try {
    const cachePath = getUsageCachePath();
    const cacheDir = path.dirname(cachePath);
    if (!fs.existsSync(cacheDir)) {
      fs.mkdirSync(cacheDir, { recursive: true });
    }
    fs.writeFileSync(cachePath, JSON.stringify({ timestamp: Date.now(), data, error }, null, 2));
  } catch {
    // Ignore
  }
}

function isUsageCacheValid(cache) {
  const ttl = cache.error ? CACHE_TTL_FAILURE_MS : CACHE_TTL_SUCCESS_MS;
  return Date.now() - cache.timestamp < ttl;
}

function readFileCredentials() {
  try {
    const credPath = path.join(homeDir, '.claude/.credentials.json');
    if (!fs.existsSync(credPath)) return null;
    const parsed = JSON.parse(fs.readFileSync(credPath, 'utf-8'));
    const creds = parsed.claudeAiOauth || parsed;
    if (creds.accessToken) {
      return { accessToken: creds.accessToken, expiresAt: creds.expiresAt };
    }
  } catch {}
  return null;
}

function validateCredentials(creds) {
  if (!creds?.accessToken) return false;
  if (creds.expiresAt != null && creds.expiresAt <= Date.now()) return false;
  return true;
}

function fetchUsageFromApi(accessToken) {
  return new Promise((resolve) => {
    const req = https.request({
      hostname: 'api.anthropic.com',
      path: '/api/oauth/usage',
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'anthropic-beta': 'oauth-2025-04-20',
      },
      timeout: API_TIMEOUT_MS,
    }, (res) => {
      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode === 200) {
          try { resolve(JSON.parse(data)); } catch { resolve(null); }
        } else {
          resolve(null);
        }
      });
    });
    req.on('error', () => resolve(null));
    req.on('timeout', () => { req.destroy(); resolve(null); });
    req.end();
  });
}

function parseUsageResponse(response) {
  const fiveHour = response.five_hour?.utilization;
  const sevenDay = response.seven_day?.utilization;
  if (fiveHour == null && sevenDay == null) return null;

  const clamp = v => (v == null || !isFinite(v)) ? 0 : Math.max(0, Math.min(100, v));
  const parseDate = dateStr => {
    if (!dateStr) return null;
    try {
      const date = new Date(dateStr);
      return isNaN(date.getTime()) ? null : date;
    } catch { return null; }
  };

  return {
    fiveHourPercent: clamp(fiveHour),
    weeklyPercent: clamp(sevenDay),
    fiveHourResetsAt: parseDate(response.five_hour?.resets_at),
    weeklyResetsAt: parseDate(response.seven_day?.resets_at),
  };
}

async function getUsage() {
  const cache = readUsageCache();
  if (cache && isUsageCacheValid(cache)) {
    return cache.data;
  }

  const creds = readFileCredentials();
  if (!creds || !validateCredentials(creds)) {
    writeUsageCache(null, true);
    return null;
  }

  const response = await fetchUsageFromApi(creds.accessToken);
  if (!response) {
    writeUsageCache(null, true);
    return null;
  }

  const usage = parseUsageResponse(response);
  writeUsageCache(usage, !usage);
  return usage;
}

function formatTimeUntil(date) {
  if (!date) return null;
  const diff = date.getTime() - Date.now();
  if (diff <= 0) return null;

  const minutes = Math.floor(diff / 60000);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);

  if (days > 0) return `${days}d${hours % 24}h`;
  if (hours > 0) return `${hours}h${minutes % 60}m`;
  return `${minutes}m`;
}

function colorByPercent(percent) {
  if (percent >= 90) return red;
  if (percent >= 70) return yellow;
  return green;
}

function renderUsage(usage) {
  if (!usage) return null;

  const parts = [];

  // 5-hour (session)
  const fiveHourColor = colorByPercent(usage.fiveHourPercent);
  let fiveHourStr = `${dim('5h')} ${fiveHourColor(`${Math.round(usage.fiveHourPercent)}%`)}`;
  const fiveHourReset = formatTimeUntil(usage.fiveHourResetsAt);
  if (fiveHourReset) fiveHourStr += ` ${dim('→')} ${dim(fiveHourReset)}`;
  parts.push(fiveHourStr);

  // 7-day (weekly)
  const weeklyColor = colorByPercent(usage.weeklyPercent);
  let weeklyStr = `${dim('7d')} ${weeklyColor(`${Math.round(usage.weeklyPercent)}%`)}`;
  const weeklyReset = formatTimeUntil(usage.weeklyResetsAt);
  if (weeklyReset) weeklyStr += ` ${dim('→')} ${dim(weeklyReset)}`;
  parts.push(weeklyStr);

  return parts.join(dim(' │ '));
}

// ============================================================
// GSD Project State
// ============================================================
function readGsdState(cwd) {
  const statePath = path.join(cwd, '.planning', 'STATE.md');
  if (!fs.existsSync(statePath)) return null;

  try {
    const content = fs.readFileSync(statePath, 'utf-8');
    const result = {};

    // Extract milestone
    const milestoneMatch = content.match(/\*\*Milestone:\*\*\s*(.+?)(?:\s*—|$)/m);
    if (milestoneMatch) result.milestone = milestoneMatch[1].trim();

    // Extract phase (e.g., "07 of 07")
    const phaseMatch = content.match(/\*\*Phase:\*\*\s*(\d+)\s*of\s*(\d+)/m);
    if (phaseMatch) {
      result.currentPhase = parseInt(phaseMatch[1]);
      result.totalPhases = parseInt(phaseMatch[2]);
    }

    // Extract progress percentage
    const progressMatch = content.match(/\*\*Progress:\*\*.*?(\d+)%/m);
    if (progressMatch) result.progress = parseInt(progressMatch[1]);

    // Extract status
    const statusMatch = content.match(/\*\*Status:\*\*\s*(.+?)$/m);
    if (statusMatch) result.status = statusMatch[1].trim();

    return (result.milestone || result.currentPhase) ? result : null;
  } catch {
    return null;
  }
}

function renderGsdState(state) {
  if (!state) return null;

  const parts = [];

  // Phase progress
  if (state.currentPhase && state.totalPhases) {
    const phaseStr = `P${String(state.currentPhase).padStart(2, '0')}/${String(state.totalPhases).padStart(2, '0')}`;
    if (state.progress === 100) {
      parts.push(green(phaseStr + ' ✓'));
    } else if (state.progress != null) {
      parts.push(cyan(phaseStr) + dim(` ${state.progress}%`));
    } else {
      parts.push(cyan(phaseStr));
    }
  }

  return parts.length > 0 ? parts.join(' ') : null;
}

// ============================================================
// Main
// ============================================================
let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', async () => {
  try {
    const data = JSON.parse(input);
    const modelRaw = data.model?.display_name || data.model?.id || 'Claude';
    const model = shortenModelName(modelRaw);
    const cwd = data.cwd || data.workspace?.current_dir || process.cwd();
    const session = data.session_id || '';

    // Context window (prefer used_percentage, fallback to remaining)
    let contextPercent = 0;
    if (data.context_window?.used_percentage != null) {
      contextPercent = Math.round(data.context_window.used_percentage);
    } else if (data.context_window?.remaining_percentage != null) {
      contextPercent = Math.max(0, Math.min(100, 100 - Math.round(data.context_window.remaining_percentage)));
    }

    // Build context bar
    let contextStr = '';
    const filled = Math.floor(contextPercent / 10);
    const bar = '█'.repeat(filled) + '░'.repeat(10 - filled);
    if (contextPercent < 50) {
      contextStr = green(`${bar} ${contextPercent}%`);
    } else if (contextPercent < 65) {
      contextStr = yellow(`${bar} ${contextPercent}%`);
    } else if (contextPercent < 80) {
      contextStr = orange(`${bar} ${contextPercent}%`);
    } else {
      contextStr = blink(red(`💀 ${bar} ${contextPercent}%`));
    }

    // Current task from todos
    let task = '';
    const todosDir = path.join(homeDir, '.claude', 'todos');
    if (session && fs.existsSync(todosDir)) {
      try {
        const files = fs.readdirSync(todosDir)
          .filter(f => f.startsWith(session) && f.includes('-agent-') && f.endsWith('.json'))
          .map(f => ({ name: f, mtime: fs.statSync(path.join(todosDir, f)).mtime }))
          .sort((a, b) => b.mtime - a.mtime);

        if (files.length > 0) {
          const todos = JSON.parse(fs.readFileSync(path.join(todosDir, files[0].name), 'utf8'));
          const inProgress = todos.find(t => t.status === 'in_progress');
          if (inProgress) task = inProgress.activeForm || '';
        }
      } catch (err) {
        logger.debug('gsd-statusline', 'Error reading todos', err);
      }
    }

    // GSD update available?
    let gsdUpdate = '';
    const cacheFile = path.join(homeDir, '.claude', 'cache', 'gsd-update-check.json');
    if (fs.existsSync(cacheFile)) {
      try {
        const cache = JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
        if (cache.update_available) {
          gsdUpdate = yellow('⬆') + ' ';
        }
      } catch (err) {
        logger.debug('gsd-statusline', 'Error reading update cache', err);
      }
    }

    // GSD project state
    const gsdState = readGsdState(cwd);
    const gsdStateStr = renderGsdState(gsdState);

    // Usage API
    const usage = await getUsage();
    const usageStr = renderUsage(usage);

    // Directory (shortened)
    let dirDisplay = cwd;
    if (cwd.startsWith(homeDir)) {
      dirDisplay = '~' + cwd.slice(homeDir.length);
    }
    const dirParts = dirDisplay.split('/').filter(Boolean);
    if (dirParts.length > 3) {
      dirDisplay = dirParts[0] + '/…/' + dirParts.slice(-2).join('/');
    }

    // Build output
    const elements = [];

    // GSD update indicator
    if (gsdUpdate) elements.push(gsdUpdate.trim());

    // Model
    elements.push(cyan(model));

    // Current task (if any)
    if (task) elements.push(bold(task));

    // GSD state (if any)
    if (gsdStateStr) elements.push(gsdStateStr);

    // Directory
    elements.push(magenta(dirDisplay));

    // Context bar
    elements.push(contextStr);

    // Usage (5h + 7d)
    if (usageStr) elements.push(usageStr);

    // Join and output
    const output = elements.join(dim(' │ '));
    // Replace spaces with non-breaking spaces for alignment
    process.stdout.write(output.replace(/ /g, '\u00A0'));

  } catch (err) {
    logger.error('gsd-statusline', 'Error processing statusline data', err);
  }
});
