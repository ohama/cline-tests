#!/usr/bin/env node
/**
 * GSD Logger
 *
 * Centralized logging for GSD hooks with rotation and cleanup.
 *
 * Usage:
 *   const logger = require('./gsd-logger');
 *   logger.info('hook-name', 'message');
 *   logger.error('hook-name', 'error message', error);
 *   logger.debug('hook-name', 'debug info');
 *
 * Logs are written to: ~/.claude/logs/gsd-hooks.log
 * Old logs (>7 days) are automatically cleaned up.
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

// Configuration
const LOG_DIR = path.join(os.homedir(), '.claude', 'logs');
const LOG_FILE = path.join(LOG_DIR, 'gsd-hooks.log');
const MAX_LOG_SIZE = 1024 * 1024; // 1MB
const MAX_LOG_AGE_DAYS = 7;
const DEBUG_ENABLED = process.env.GSD_DEBUG === '1';

/**
 * Ensure log directory exists
 */
function ensureLogDir() {
  if (!fs.existsSync(LOG_DIR)) {
    try {
      fs.mkdirSync(LOG_DIR, { recursive: true });
    } catch (err) {
      // Silent fail - logging should never break the hook
    }
  }
}

/**
 * Rotate log file if too large
 */
function rotateLogIfNeeded() {
  try {
    if (!fs.existsSync(LOG_FILE)) return;

    const stats = fs.statSync(LOG_FILE);
    if (stats.size > MAX_LOG_SIZE) {
      const backupFile = LOG_FILE + '.old';
      if (fs.existsSync(backupFile)) {
        fs.unlinkSync(backupFile);
      }
      fs.renameSync(LOG_FILE, backupFile);
    }
  } catch (err) {
    // Silent fail
  }
}

/**
 * Clean old log files
 */
function cleanOldLogs() {
  try {
    if (!fs.existsSync(LOG_DIR)) return;

    const now = Date.now();
    const maxAge = MAX_LOG_AGE_DAYS * 24 * 60 * 60 * 1000;

    const files = fs.readdirSync(LOG_DIR);
    for (const file of files) {
      if (!file.startsWith('gsd-')) continue;

      const filePath = path.join(LOG_DIR, file);
      const stats = fs.statSync(filePath);

      if (now - stats.mtime.getTime() > maxAge) {
        fs.unlinkSync(filePath);
      }
    }
  } catch (err) {
    // Silent fail
  }
}

/**
 * Format log entry
 */
function formatEntry(level, source, message, extra = null) {
  const timestamp = new Date().toISOString();
  let entry = `${timestamp} [${level.toUpperCase()}] [${source}] ${message}`;

  if (extra) {
    if (extra instanceof Error) {
      entry += `\n  Error: ${extra.message}`;
      if (extra.stack) {
        entry += `\n  Stack: ${extra.stack.split('\n').slice(1, 4).join('\n  ')}`;
      }
    } else if (typeof extra === 'object') {
      entry += `\n  Data: ${JSON.stringify(extra)}`;
    } else {
      entry += `\n  ${extra}`;
    }
  }

  return entry;
}

/**
 * Write log entry
 */
function writeLog(level, source, message, extra = null) {
  try {
    ensureLogDir();
    rotateLogIfNeeded();

    const entry = formatEntry(level, source, message, extra) + '\n';
    fs.appendFileSync(LOG_FILE, entry);
  } catch (err) {
    // Last resort: write to stderr
    console.error(`[GSD] Failed to write log: ${err.message}`);
  }
}

/**
 * Logger interface
 */
const logger = {
  /**
   * Log info message
   */
  info(source, message, extra = null) {
    writeLog('info', source, message, extra);
  },

  /**
   * Log warning message
   */
  warn(source, message, extra = null) {
    writeLog('warn', source, message, extra);
  },

  /**
   * Log error message
   */
  error(source, message, extra = null) {
    writeLog('error', source, message, extra);
  },

  /**
   * Log debug message (only if GSD_DEBUG=1)
   */
  debug(source, message, extra = null) {
    if (DEBUG_ENABLED) {
      writeLog('debug', source, message, extra);
    }
  },

  /**
   * Get log file path
   */
  getLogPath() {
    return LOG_FILE;
  },

  /**
   * Read recent log entries
   */
  readRecent(lines = 50) {
    try {
      if (!fs.existsSync(LOG_FILE)) return '';

      const content = fs.readFileSync(LOG_FILE, 'utf8');
      const allLines = content.trim().split('\n');
      return allLines.slice(-lines).join('\n');
    } catch (err) {
      return `Error reading log: ${err.message}`;
    }
  },

  /**
   * Clean up old logs
   */
  cleanup() {
    cleanOldLogs();
  }
};

// CLI interface
if (require.main === module) {
  const args = process.argv.slice(2);

  switch (args[0]) {
    case '--path':
      console.log(LOG_FILE);
      break;

    case '--read':
      const lines = parseInt(args[1]) || 50;
      console.log(logger.readRecent(lines));
      break;

    case '--cleanup':
      logger.cleanup();
      console.log('Log cleanup complete');
      break;

    case '--help':
      console.log(`
GSD Logger

Commands:
  --path      Show log file path
  --read [n]  Show last n log entries (default: 50)
  --cleanup   Remove old log files
  --help      Show this help

Environment:
  GSD_DEBUG=1  Enable debug logging
`);
      break;

    default:
      console.log(`Log file: ${LOG_FILE}`);
      if (fs.existsSync(LOG_FILE)) {
        const stats = fs.statSync(LOG_FILE);
        console.log(`Size: ${(stats.size / 1024).toFixed(1)}KB`);
        console.log(`Modified: ${stats.mtime.toISOString()}`);
      } else {
        console.log('(not yet created)');
      }
  }
}

module.exports = logger;
