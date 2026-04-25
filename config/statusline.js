#!/usr/bin/env node
// Claude Code Statusline - Unified
// Modes: custom (2+adaptive line), --minimal (1-line, block bar), --gsd (adds GSD features)
// Auto-degrades to minimal when terminal < 70 columns
// Reserves 30% width for Claude Code UI when running piped (configurable via CLAUDE_STATUSLINE_WIDTH_PCT)

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync } = require('child_process');
const crypto = require('crypto');
const readline = require('readline');

// ── Helpers ──────────────────────────────────────────────────────────

const RST = '\x1b[0m';
const DIM = '\x1b[2m';
const BOLD = '\x1b[1m';
const c = {
  cyan:      s => `\x1b[36m${s}${RST}`,
  magenta:   s => `\x1b[35m${s}${RST}`,
  yellow:    s => `\x1b[33m${s}${RST}`,
  green:     s => `\x1b[32m${s}${RST}`,
  orange:    s => `\x1b[38;5;208m${s}${RST}`,
  red:       s => `\x1b[31m${s}${RST}`,
  blinkRed:  s => `\x1b[5;31m${s}${RST}`,
  gray:      s => `\x1b[90m${s}${RST}`,
  brightBlue:s => `\x1b[94m${s}${RST}`,
  dim:       s => `${DIM}${s}${RST}`,
  bold:      s => `${BOLD}${s}${RST}`,
};

const SEP = ` ${c.gray('│')} `;

function stripAnsi(str) {
  return str.replace(/\x1b\[\??[0-9;]*[a-zA-Z]|\x1b\][^\x07]*\x07|\x1b[()][AB012]/g, '');
}

function displayWidth(str) {
  const clean = stripAnsi(str);
  let w = 0;
  for (const ch of clean) {
    const cp = ch.codePointAt(0);
    // Zero-width: variation selectors, ZWJ, combining marks
    if (
      (cp >= 0xFE00 && cp <= 0xFE0F) ||
      cp === 0x200D ||
      (cp >= 0x0300 && cp <= 0x036F)
    ) {
      w += 0;
    // Wide chars: emoji, CJK, full-width
    } else if (
      cp >= 0x1F000 ||
      (cp >= 0x2600 && cp <= 0x27BF) ||
      (cp >= 0x2B00 && cp <= 0x2BFF) ||
      (cp >= 0x4E00 && cp <= 0x9FFF) ||
      (cp >= 0x3000 && cp <= 0x303F) ||
      (cp >= 0xFF00 && cp <= 0xFFEF)
    ) {
      w += 2;
    } else {
      w += 1;
    }
  }
  return w;
}

function getTermColsFromProcTree() {
  // Walk up the process tree to find a TTY and read its real width.
  // Needed because the statusline runs piped (no direct TTY access).
  // The /dev/pts/N path is read from /proc symlinks, not user input.
  try {
    let pid = process.ppid;
    for (let i = 0; i < 5 && pid > 1; i++) {
      const fds = fs.readdirSync(`/proc/${pid}/fd`);
      for (const fd of fds) {
        try {
          const link = fs.readlinkSync(`/proc/${pid}/fd/${fd}`);
          if (link.startsWith('/dev/pts/') || link === '/dev/tty') {
            // eslint-disable-next-line no-child-process -- shell needed for stdin redirect; path is from procfs, not user input
            const out = require('child_process').execSync(
              `stty size < ${link}`, { shell: true, timeout: 500 }
            ).toString().trim();
            const cols = parseInt(out.split(/\s+/)[1], 10);
            if (cols > 0) return cols;
          }
        } catch {}
      }
      const stat = fs.readFileSync(`/proc/${pid}/stat`, 'utf8');
      pid = parseInt(stat.split(' ')[3], 10);
    }
  } catch {}
  return 0;
}

function getTermCols() {
  // Direct TTY — full width
  let cols = process.stdout.columns || process.stderr.columns;
  if (cols) return cols;

  // Piped context — detect from env, proc tree, or tput
  cols = parseInt(process.env.COLUMNS, 10);
  if (cols > 0) return cols;

  cols = getTermColsFromProcTree();
  if (!cols) {
    try {
      cols = parseInt(execFileSync('tput', ['cols'],
        { stdio: ['inherit', 'pipe', 'pipe'], timeout: 500 }
      ).toString().trim(), 10);
    } catch {}
  }

  return cols || 120;
}

function getLayoutCols() {
  const raw = getTermCols();
  const isPiped = !process.stdout.columns && !process.stderr.columns;
  if (!isPiped) return raw;
  const pct = parseFloat(process.env.CLAUDE_STATUSLINE_WIDTH_PCT) || 0.7;
  return Math.floor(raw * Math.min(Math.max(pct, 0.3), 1.0));
}

function padLine(left, right) {
  const cols = getLayoutCols();
  const leftW = displayWidth(left);
  const rightW = displayWidth(right);
  const gap = Math.max(1, cols - leftW - rightW);
  return left + ' '.repeat(gap) + right;
}

function parseArgs(argv) {
  return {
    minimal: argv.includes('--minimal'),
    gsd: argv.includes('--gsd'),
  };
}

function gitExec(args, cwd) {
  try {
    return execFileSync('git', args, { cwd, encoding: 'utf8', timeout: 2000, stdio: ['pipe','pipe','pipe'] }).trim();
  } catch { return ''; }
}

const GIT_CACHE_MAX_AGE = 5; // seconds

function getCachedGit(cwd) {
  const dirHash = crypto.createHash('md5').update(cwd).digest('hex').slice(0, 8);
  const cacheFile = path.join(os.tmpdir(), `statusline-git-${dirHash}`);

  // Check cache freshness
  try {
    const stat = fs.statSync(cacheFile);
    if ((Date.now() - stat.mtimeMs) / 1000 < GIT_CACHE_MAX_AGE) {
      return JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
    }
  } catch {}

  // Cache miss — run git commands
  const branch = gitExec(['rev-parse', '--abbrev-ref', 'HEAD'], cwd);
  const result = { branch, staged: 0, modified: 0, untracked: 0 };

  if (branch) {
    const status = gitExec(['status', '--porcelain'], cwd);
    if (status) {
      const lines = status.split('\n').filter(Boolean);
      result.staged = lines.filter(l => l[0] !== ' ' && l[0] !== '?').length;
      result.modified = lines.filter(l => l[1] === 'M').length;
      result.untracked = lines.filter(l => l.startsWith('??')).length;
    }
  }

  // Write cache with 'wx' flag to prevent race condition overwrites
  try {
    const fd = fs.openSync(cacheFile, 'wx', 0o600);
    fs.writeSync(fd, JSON.stringify(result));
    fs.closeSync(fd);
  } catch (err) {
    // File exists from another process - that's fine, skip write
    if (err.code !== 'EEXIST') throw err;
  }

  return result;
}

function formatTokens(n) {
  if (n == null) return '';
  if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + 'M';
  if (n >= 1_000) return (n / 1_000).toFixed(0) + 'k';
  return String(n);
}

function formatDuration(ms) {
  if (ms == null) return '';
  const totalSec = Math.floor(ms / 1000);
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  if (h > 0) return `${h}h${String(m).padStart(2,'0')}m`;
  if (m > 0) return `${m}m${String(s).padStart(2,'0')}s`;
  return `${s}s`;
}

// ── Token Speed Tracker ──────────────────────────────────────────────

const SPEED_CACHE_MAX_AGE = 2000; // ms - same window as claude-hud
const MAX_TRANSCRIPT_LINES = 50000; // Prevent memory issues with very long sessions

function getTokenSpeed(contextWindow) {
  const outputTokens = contextWindow?.current_usage?.output_tokens;
  if (typeof outputTokens !== 'number' || !Number.isFinite(outputTokens)) {
    return null;
  }

  const now = Date.now();
  const cacheFile = path.join(os.tmpdir(), 'statusline-speed-cache.json');
  let previous = null;

  try {
    if (fs.existsSync(cacheFile)) {
      const stat = fs.statSync(cacheFile);
      if ((now - stat.mtimeMs) < SPEED_CACHE_MAX_AGE) {
        previous = JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
      }
    }
  } catch {}

  let speed = null;
  if (previous && outputTokens >= previous.outputTokens) {
    const deltaTokens = outputTokens - previous.outputTokens;
    const deltaMs = now - previous.timestamp;
    if (deltaTokens > 0 && deltaMs > 0 && deltaMs <= SPEED_CACHE_MAX_AGE) {
      speed = Math.round(deltaTokens / (deltaMs / 1000));
    }
  }

  // Write cache with 'wx' flag to prevent race condition overwrites
  try {
    const fd = fs.openSync(cacheFile, 'wx', 0o600);
    fs.writeSync(fd, JSON.stringify({ outputTokens, timestamp: now }));
    fs.closeSync(fd);
  } catch (err) {
    // File exists from another process - that's fine, skip write
    if (err.code !== 'EEXIST') throw err;
  }

  return speed;
}

// ── Transcript Parser (Tools & Agents) ────────────────────────────────

async function parseTranscript(transcriptPath) {
  const result = {
    tools: [],
    agents: [],
    todos: [],
    sessionStart: null,
  };

  if (!transcriptPath || !fs.existsSync(transcriptPath)) {
    return result;
  }

  // Validate transcriptPath is within allowed directories (~/.claude or /tmp)
  const homeDir = os.homedir();
  const resolvedPath = path.resolve(transcriptPath);
  const isAllowedPath = resolvedPath.startsWith(homeDir) || resolvedPath.startsWith(os.tmpdir());
  if (!isAllowedPath) {
    return result;
  }

  const toolMap = new Map();
  const agentMap = new Map();
  let latestTodos = [];
  const taskIdToIndex = new Map();

  let fileStream = null;
  try {
    fileStream = fs.createReadStream(transcriptPath);
    const rl = readline.createInterface({
      input: fileStream,
      crlfDelay: Infinity,
    });

    let lineCount = 0;
    for await (const line of rl) {
      if (!line.trim()) continue;
      lineCount++;
      if (lineCount > MAX_TRANSCRIPT_LINES) break;

      try {
        const entry = JSON.parse(line);
        if (!result.sessionStart && entry.timestamp) {
          result.sessionStart = new Date(entry.timestamp);
        }
        processTranscriptEntry(entry, toolMap, agentMap, latestTodos, taskIdToIndex, result);
      } catch {
        // Skip malformed lines
      }
    }
  } catch {
    // Return partial results on error
  } finally {
    // Ensure stream is closed to prevent file handle leaks
    if (fileStream) {
      fileStream.destroy();
    }
  }

  result.tools = Array.from(toolMap.values()).slice(-20);
  result.agents = Array.from(agentMap.values()).slice(-10);
  result.todos = latestTodos;
  return result;
}

function processTranscriptEntry(entry, toolMap, agentMap, latestTodos, taskIdToIndex, result) {
  const timestamp = entry.timestamp ? new Date(entry.timestamp) : new Date();
  const content = entry.message?.content;
  if (!content || !Array.isArray(content)) return;

  for (const block of content) {
    if (block.type === 'tool_use' && block.id && block.name) {
      const target = extractToolTarget(block.name, block.input);
      const toolEntry = {
        id: block.id,
        name: block.name,
        target,
        status: 'running',
        startTime: timestamp,
      };

      // Track Task agents
      if (block.name === 'Task') {
        const input = block.input || {};
        agentMap.set(block.id, {
          id: block.id,
          type: input.subagent_type || 'unknown',
          model: input.model || undefined,
          description: input.description || undefined,
          status: 'running',
          startTime: timestamp,
        });
      }

      // Track TodoWrite - use ID-based merge to handle updates correctly
      if (block.name === 'TodoWrite') {
        const input = block.input || {};
        if (input.todos && Array.isArray(input.todos)) {
          // Build a map of existing todos by ID for proper merging
          const existingTodosById = new Map();
          for (const todo of latestTodos) {
            // Use content as ID fallback since Claude's TodoWrite may not always have IDs
            const id = todo.id || todo.content;
            existingTodosById.set(id, todo);
          }

          // Merge new todos with existing ones by ID
          const mergedTodos = [];
          for (const todo of input.todos) {
            const id = todo.id || todo.content || '';
            const existing = existingTodosById.get(id);

            // If todo exists and status is unchanged/missing, keep existing
            if (existing && (!todo.status || todo.status === existing.status)) {
              mergedTodos.push(existing);
            } else {
              // New or updated todo
              mergedTodos.push({
                id: todo.id,
                content: todo.content || '',
                status: normalizeTodoStatus(todo.status),
              });
            }
          }
          latestTodos = mergedTodos;
        }
      }

      // Track TaskCreate - creates individual todos (alternative to TodoWrite)
      if (block.name === 'TaskCreate') {
        const input = block.input || {};
        const subject = typeof input.subject === 'string' ? input.subject : '';
        const description = typeof input.description === 'string' ? input.description : '';
        const content = subject || description || 'Untitled task';
        const status = normalizeTodoStatus(input.status) || 'pending';
        latestTodos.push({
          id: input.taskId || block.id,
          content,
          status,
        });

        // Track task ID for later updates
        const taskId = input.taskId || block.id;
        if (taskId) {
          taskIdToIndex.set(String(taskId), latestTodos.length - 1);
        }
      }

      // Track TaskUpdate - updates existing todos by taskId
      if (block.name === 'TaskUpdate') {
        const input = block.input || {};
        const taskId = input.taskId;
        let index = null;

        // Try to find by taskId mapping
        if (taskId && taskIdToIndex.has(String(taskId))) {
          index = taskIdToIndex.get(String(taskId));
        }

        // Fallback: try numeric index (1-based to 0-based)
        if (index === null && typeof taskId === 'string' && /^\d+$/.test(taskId)) {
          const numericIndex = parseInt(taskId, 10) - 1;
          if (numericIndex >= 0 && numericIndex < latestTodos.length) {
            index = numericIndex;
          }
        }

        if (index !== null && latestTodos[index]) {
          // Update status if provided
          if (input.status) {
            latestTodos[index].status = normalizeTodoStatus(input.status) || latestTodos[index].status;
          }
          // Update content if provided
          const subject = typeof input.subject === 'string' ? input.subject : '';
          const description = typeof input.description === 'string' ? input.description : '';
          const content = subject || description;
          if (content) {
            latestTodos[index].content = content;
          }
        }
      }

      toolMap.set(block.id, toolEntry);
    }

    if (block.type === 'tool_result' && block.tool_use_id) {
      const tool = toolMap.get(block.tool_use_id);
      if (tool) {
        tool.status = block.is_error ? 'error' : 'completed';
        tool.endTime = timestamp;
      }

      const agent = agentMap.get(block.tool_use_id);
      if (agent) {
        agent.status = 'completed';
        agent.endTime = timestamp;
      }
    }
  }
}

function normalizeTodoStatus(status) {
  if (!status) return 'pending';
  const s = String(status).toLowerCase();
  if (s === 'completed' || s === 'done') return 'completed';
  if (s === 'in_progress' || s === 'in-progress' || s === 'running') return 'in_progress';
  return 'pending';
}

function extractToolTarget(toolName, input) {
  if (!input) return undefined;

  switch (toolName) {
    case 'Read':
    case 'Write':
    case 'Edit':
      return input.file_path || input.path;
    case 'Glob':
      return input.pattern;
    case 'Grep':
      return input.pattern;
    case 'Bash':
      const cmd = input.command || '';
      return cmd.length > 30 ? cmd.slice(0, 30) + '...' : cmd;
    default:
      return undefined;
  }
}

function truncatePath(str, maxLen = 20) {
  if (!str) return '';
  const normalized = str.replace(/\\/g, '/');
  if (normalized.length <= maxLen) return normalized;
  const parts = normalized.split('/');
  const filename = parts.pop() || normalized;
  if (filename.length >= maxLen) return filename.slice(0, maxLen - 3) + '...';
  return '.../' + filename;
}

function formatElapsed(startTime, endTime) {
  const now = Date.now();
  // Validate startTime is a valid Date before calling getTime()
  if (!(startTime instanceof Date) || isNaN(startTime.getTime())) {
    return '<1s';
  }
  const start = startTime.getTime();
  const end = endTime?.getTime() || now;
  const ms = end - start;

  if (ms < 1000) return '<1s';
  if (ms < 60000) return `${Math.round(ms / 1000)}s`;
  const mins = Math.floor(ms / 60000);
  const secs = Math.round((ms % 60000) / 1000);
  return `${mins}m ${secs}s`;
}

function renderToolsLine(tools) {
  if (!tools || tools.length === 0) return null;

  const parts = [];
  // Exclude TodoWrite from tools (it has its own line)
  const runningTools = tools.filter(t => t.status === 'running' && t.name !== 'TodoWrite').slice(-2);
  const completedTools = tools.filter(t => (t.status === 'completed' || t.status === 'error') && t.name !== 'TodoWrite');

  // Running tools: ◐ running, ✓ completed
  for (const tool of runningTools) {
    const target = tool.target ? truncatePath(tool.target) : '';
    parts.push(`${c.yellow('◐')} ${c.cyan(tool.name)}${target ? c.dim(`: ${target}`) : ''}`);
  }

  // Completed tool counts
  const toolCounts = new Map();
  for (const tool of completedTools) {
    const count = toolCounts.get(tool.name) || 0;
    toolCounts.set(tool.name, count + 1);
  }

  const sortedTools = Array.from(toolCounts.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 4);

  for (const [name, count] of sortedTools) {
    parts.push(`${c.green('✓')} ${name} ${c.dim(`×${count}`)}`);
  }

  return parts.length > 0 ? parts.join(' | ') : null;
}

function renderAgentsLine(agents) {
  if (!agents || agents.length === 0) return null;

  const runningAgents = agents.filter(a => a.status === 'running');
  const recentCompleted = agents.filter(a => a.status === 'completed').slice(-2);
  const toShow = [...runningAgents, ...recentCompleted].slice(-3);

  if (toShow.length === 0) return null;

  const lines = [];
  for (const agent of toShow) {
    const statusIcon = agent.status === 'running' ? c.yellow('◐') : c.green('✓');
    const type = c.magenta(agent.type);
    const model = agent.model ? c.dim(`[${agent.model}]`) : '';
    const desc = agent.description ? c.dim(`: ${agent.description.slice(0, 40)}`) : '';
    const elapsed = formatElapsed(agent.startTime, agent.endTime);
    lines.push(`${statusIcon} ${type}${model ? ` ${model}` : ''}${desc} ${c.dim(`(${elapsed})`)}`);
  }

  return lines.join('\n');
}

function renderTodosLine(todos) {
  if (!todos || todos.length === 0) return null;

  const completed = todos.filter(t => t.status === 'completed').length;
  const inProgress = todos.filter(t => t.status === 'in_progress').length;
  const pending = todos.filter(t => t.status === 'pending').length;
  const total = todos.length;

  if (total === 0) return null;

  const pct = Math.round((completed / total) * 100);
  const parts = [];

  // Progress bar: █ filled, ░ empty
  const BAR_LEN = 10;
  const filled = Math.round((completed / total) * BAR_LEN);
  const empty = BAR_LEN - filled;
  const bar = c.green('█'.repeat(filled)) + c.gray('░'.repeat(empty));

  parts.push(`${bar} ${c.bold(`${completed}/${total}`)}`);

  // Status indicators: ◐ in_progress, ○ pending
  if (inProgress > 0) parts.push(c.yellow(`◐ ${inProgress}`));
  if (pending > 0) parts.push(c.gray(`○ ${pending}`));

  return parts.join(' | ');
}

function formatCost(usd) {
  if (usd == null) return '';
  if (usd < 0.01) return '$' + usd.toFixed(4);
  return '$' + usd.toFixed(2);
}

function formatRateLimits(rateLimits) {
  if (!rateLimits) return null;
  const parts = [];
  const bolt = String.fromCodePoint(0xF0E7);

  for (const [key, label] of [['five_hour', '5h'], ['seven_day', '7d']]) {
    const window = rateLimits[key];
    if (window?.used_percentage == null) continue;
    const pct = Math.round(window.used_percentage);
    if (pct < 50) continue; // only show when it matters
    let colorFn = c.yellow;
    if (pct >= 85) colorFn = c.blinkRed;
    else if (pct >= 70) colorFn = c.orange;

    let resetStr = '';
    if (pct >= 70 && window.resets_at) {
      const remainMs = (window.resets_at * 1000) - Date.now();
      if (remainMs > 0) resetStr = ' ' + c.dim(formatDuration(remainMs));
    }
    parts.push(colorFn(`${pct}%`) + c.dim(`(${label})`) + resetStr);
  }

  return parts.length > 0 ? bolt + ' ' + parts.join(' ') : null;
}

// ── Thinking effort from transcript ──────────────────────────────────

function getThinkingEffort(transcriptPath) {
  if (!transcriptPath) return '';
  try {
    const content = fs.readFileSync(transcriptPath, 'utf8');
    const lines = content.split('\n').filter(Boolean).reverse();
    for (const line of lines) {
      const match = line.match(/Set model to .+ with (low|medium|high|max) effort/);
      if (match) return match[1];
    }
  } catch {}
  try {
    const homeDir = os.homedir();
    const claudeDir = process.env.CLAUDE_CONFIG_DIR || path.join(homeDir, '.claude');
    const settings = JSON.parse(fs.readFileSync(path.join(claudeDir, 'settings.json'), 'utf8'));
    if (settings.effortLevel) return settings.effortLevel;
  } catch {}
  return '';
}

// ── GSD info ─────────────────────────────────────────────────────────

function getGsdInfo(session) {
  const result = { updateAvailable: false, taskName: '' };
  const homeDir = os.homedir();
  const claudeDir = process.env.CLAUDE_CONFIG_DIR || path.join(homeDir, '.claude');

  // Update check
  const cacheFile = path.join(claudeDir, 'cache', 'gsd-update-check.json');
  if (fs.existsSync(cacheFile)) {
    try {
      const cache = JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
      if (cache.update_available) result.updateAvailable = true;
    } catch {}
  }

  // Current task from todos
  const todosDir = path.join(claudeDir, 'todos');
  if (session && fs.existsSync(todosDir)) {
    try {
      // Sanitize session to prevent path traversal - whitelist only \w and -
      const sanitizedSession = (session || '').replace(/[^\w-]/g, '');
      const files = fs.readdirSync(todosDir)
        .filter(f => f.startsWith(sanitizedSession) && f.includes('-agent-') && f.endsWith('.json'))
        .map(f => ({ name: f, mtime: fs.statSync(path.join(todosDir, f)).mtime }))
        .sort((a, b) => b.mtime - a.mtime);
      if (files.length > 0) {
        const todoPath = path.join(todosDir, files[0].name);
        // Validate resolved path stays within todosDir
        const resolvedPath = path.resolve(todoPath);
        if (!resolvedPath.startsWith(todosDir)) {
          return result;
        }
        const todos = JSON.parse(fs.readFileSync(resolvedPath, 'utf8'));
        const inProgress = todos.find(t => t.status === 'in_progress');
        if (inProgress && inProgress.activeForm) {
          result.taskName = inProgress.activeForm;
        }
      }
    } catch {}
  }

  return result;
}

// ── Custom output (2 + adaptive line) ────────────────────────────────

function writeBridgeFile(session, remaining, used) {
  if (!session || remaining == null) return;
  try {
    // Sanitize session to prevent path traversal
    const sanitizedSession = (session || '').replace(/[^\w-]/g, '');
    const bridgePath = path.join(os.tmpdir(), `claude-ctx-${sanitizedSession}.json`);
    const data = JSON.stringify({
      session_id: session,
      remaining_percentage: remaining,
      used_pct: used,
      timestamp: Math.floor(Date.now() / 1000)
    });
    // Use 'wx' flag to prevent symlink attacks
    const fd = fs.openSync(bridgePath, 'wx', 0o600);
    fs.writeSync(fd, data);
    fs.closeSync(fd);
  } catch {}
}

function truncField(str, max) {
  if (str.length <= max) return str;
  return str.slice(0, Math.max(1, max - 1)) + '\u2026';
}

function fitSegments(left, right, sep, cols) {
  // Assemble left and right, progressively dropping right segments until it fits
  // Safety margin for emoji width variations across terminals
  const safeCols = cols - 4;
  const leftStr = left.join(sep);
  const leftW = displayWidth(leftStr);

  // Try with all right segments, then drop from end
  for (let r = right.length; r >= 0; r--) {
    const rSlice = right.slice(0, r);
    if (rSlice.length === 0) return leftStr;
    const rightStr = rSlice.join(sep);
    const rightW = displayWidth(rightStr);
    if (leftW + 1 + rightW <= safeCols) {
      const gap = Math.max(1, safeCols - leftW - rightW);
      return leftStr + ' '.repeat(gap) + rightStr;
    }
  }
  return leftStr;
}

async function buildCustomOutput(data, gsdInfo) {
  const model = typeof data.model === 'string' ? data.model : (data.model?.display_name || 'Claude');
  const dir = data.workspace?.current_dir || data.cwd || process.cwd();
  const session = data.session_id || '';
  const remaining = data.context_window?.remaining_percentage;
  const usedPercentage = data.context_window?.used_percentage;
  const usedPct = usedPercentage != null ? Math.round(usedPercentage) : null;
  const totalIn = data.context_window?.total_input_tokens;
  const totalOut = data.context_window?.total_output_tokens;
  const costUsd = data.cost?.total_cost_usd;
  const durationMs = data.cost?.total_duration_ms;
  const linesAdded = data.cost?.total_lines_added || 0;
  const linesRemoved = data.cost?.total_lines_removed || 0;
  const transcriptPath = data.transcript_path || '';
  const styleName = data.output_style?.name || 'default';
  const version = data.version || '';
  const agentName = data.agent?.name || '';
  const worktreeName = data.worktree?.name || '';

  // Bridge file (backward compat)
  if (remaining != null) {
    writeBridgeFile(session, remaining, usedPct);
  }

  const git = getCachedGit(dir);
  const cols = getLayoutCols();

  // Parse transcript for tools & agents
  const transcriptData = await parseTranscript(transcriptPath);
  const toolsLine = renderToolsLine(transcriptData.tools);
  const agentsLine = renderAgentsLine(transcriptData.agents);
  const todosLine = renderTodosLine(transcriptData.todos);

  // Token speed
  const tokenSpeed = getTokenSpeed(data.context_window);

  // ── Line 1: model │ branch +staged ~mod │ dir          +lines │ style │ version
  // Priority-based: build left with full names, then progressively truncate
  const dirName = path.basename(dir);
  let branchName = git.branch || '';
  let branchChanges = '';
  if (git.branch) {
    const changes = [];
    if (git.staged) changes.push(c.green(`⇡${git.staged}`));
    if (git.modified) changes.push(c.yellow(`!${git.modified}`));
    if (git.untracked) changes.push(c.gray(`?${git.untracked}`));
    if (changes.length) branchChanges = ' ' + c.yellow(changes.join(' '));
  }

  // Right side segments (lowest priority last = dropped first)
  const l1Right = [];
  if (linesAdded > 0 || linesRemoved > 0) {
    const lp = [];
    if (linesAdded > 0) lp.push(c.green(`+${linesAdded}`));
    if (linesRemoved > 0) lp.push(c.red(`-${linesRemoved}`));
    l1Right.push(lp.join(' '));
  }
  // Current active task from todos
  const activeTask = transcriptData.todos?.find(t => t.status === 'in_progress');
  if (activeTask?.content) {
    const taskLabel = activeTask.content.length > 25 ? activeTask.content.slice(0, 25) + '…' : activeTask.content;
    l1Right.push(c.yellow('◐ ' + taskLabel));
  }
  if (worktreeName) l1Right.push(c.dim(String.fromCodePoint(0xF1BB) + ' ' + worktreeName));
  if (agentName) l1Right.push(c.yellow(String.fromCodePoint(0xF1B3) + ' ' + agentName));
  if (data.session_name) l1Right.push(c.dim(data.session_name));
  // Style y version al final (derecha del todo)
  l1Right.push(c.gray(styleName));
  if (version) l1Right.push(c.dim(version));

  // Try to fit with progressively shorter branch/dir names
  const truncSteps = [
    { branch: branchName.length, dir: dirName.length },
    { branch: Math.min(branchName.length, 24), dir: dirName.length },
    { branch: Math.min(branchName.length, 16), dir: dirName.length },
    { branch: Math.min(branchName.length, 12), dir: Math.min(dirName.length, 12) },
    { branch: 8, dir: 8 },
  ];

  let line1 = '';
  for (const step of truncSteps) {
    const l1Left = [];
    l1Left.push(c.cyan(String.fromCodePoint(0xEE0D) + ' ' + model));
    if (branchName) {
      const bTrunc = truncField(branchName, step.branch);
      l1Left.push(c.magenta(String.fromCodePoint(0xE725) + ' ' + bTrunc) + branchChanges);
    }
    const dTrunc = truncField(dirName, step.dir);
    l1Left.push(c.brightBlue(String.fromCodePoint(0xF07C) + ' ' + dTrunc));

    line1 = fitSegments(l1Left, l1Right, SEP, cols);
    if (displayWidth(line1) <= cols - 4) break;
  }

  // ── Line 2: context-bar │ tokens │ cost │ duration          effort
  const l2Left = [];
  if (usedPct == null) {
    // No context data yet — show an idle bar
    l2Left.push(c.gray('\u2591'.repeat(20) + ' \u2014'));
  } else if (usedPct != null) {
    const pct = Math.floor(usedPct);
    const TOTAL_SEGS = 20;
    const filled = Math.round((pct / 100) * TOTAL_SEGS);
    const empty = TOTAL_SEGS - filled;

    let colorFn;
    let barExtra = '';
    if (pct < 50) {
      colorFn = c.green;
    } else if (pct < 65) {
      colorFn = c.yellow;
    } else if (pct < 80) {
      colorFn = c.orange;
      barExtra = ' ' + String.fromCodePoint(0xF06D);
    } else {
      colorFn = c.blinkRed;
      barExtra = ' ' + String.fromCodePoint(0xEE15); // skull at ≥80%
    }
    const bar = colorFn('\u2588'.repeat(filled)) + c.gray('\u2591'.repeat(empty));
    l2Left.push(`${bar} ${colorFn(`${pct}%`)}${barExtra}`);
  }
  if (totalIn != null || totalOut != null) {
    l2Left.push(c.green(`${String.fromCodePoint(0xF075)} ${formatTokens(totalIn || 0)}↑ ${formatTokens(totalOut || 0)}↓`));
  }
  if (costUsd != null) {
    let costDisplay = formatCost(costUsd);
    if (durationMs > 60000) {
      const perHour = costUsd / (durationMs / 3600000);
      costDisplay += c.dim(' ' + formatCost(perHour) + '/h');
    }
    l2Left.push(c.magenta(costDisplay));
  }
  if (durationMs != null) l2Left.push(c.dim(String.fromCodePoint(0xF017) + ' ' + formatDuration(durationMs)));
  if (tokenSpeed) l2Left.push(c.yellow(`${String.fromCodePoint(0xF0E7)}${tokenSpeed} tok/s`));
  const rateLimitStr = formatRateLimits(data.rate_limits);
  if (rateLimitStr) l2Left.push(rateLimitStr);

  const l2Right = [];
  const vimMode = data.vim?.mode;
  if (vimMode) l2Right.push(c.yellow(`[${vimMode[0]}]`));
  const effort = getThinkingEffort(transcriptPath);
  if (effort && effort !== 'medium') {
    const effortColor = effort === 'max' || effort === 'high' ? c.yellow : c.gray;
    l2Right.push(effortColor(`^${effort}`));
  }

  const line2 = fitSegments(l2Left, l2Right, SEP, cols);

  // ── Line 3: tools + todos combined
  const line3Parts = [];
  if (toolsLine) line3Parts.push(toolsLine);
  if (todosLine) line3Parts.push(todosLine);
  const line3 = line3Parts.join(' │ ');

  // ── Line 4: GSD info (conditional)
  let line4 = '';
  if (gsdInfo) {
    const gsdParts = [];
    if (gsdInfo.taskName) {
      gsdParts.push(c.bold(String.fromCodePoint(0xEEFF) + ' ' + gsdInfo.taskName));
    }
    if (gsdInfo.updateAvailable) {
      gsdParts.push(c.yellow(String.fromCodePoint(0xF071) + ' GSD update available'));
    }
    if (gsdParts.length) line4 = c.dim('GSD') + ' ' + gsdParts.join(SEP);
  }

  return [line1, line2, line3, line4].filter(Boolean).join('\n');
}

// ── Minimal output (1 line, block bar) ───────────────────────────────

async function buildMinimalOutput(data, gsdInfo) {
  const model = typeof data.model === 'string' ? data.model : (data.model?.display_name || 'Claude');
  const dir = data.workspace?.current_dir || data.cwd || process.cwd();
  const session = data.session_id || '';
  const usedPercentage = data.context_window?.used_percentage;
  const usedPct = usedPercentage != null ? Math.round(usedPercentage) : null;
  const totalIn = data.context_window?.total_input_tokens;
  const totalOut = data.context_window?.total_output_tokens;
  const costUsd = data.cost?.total_cost_usd;
  const durationMs = data.cost?.total_duration_ms;
  const linesAdded = data.cost?.total_lines_added || 0;
  const linesRemoved = data.cost?.total_lines_removed || 0;
  const styleName = data.output_style?.name || 'default';
  const version = data.version || '';
  const agentName = data.agent?.name || '';
  const worktreeName = data.worktree?.name || '';
  const remaining = data.context_window?.remaining_percentage;

  // Bridge file
  if (remaining != null) {
    writeBridgeFile(session, remaining, usedPct);
  }

  const git = getCachedGit(dir);
  const cols = getLayoutCols();

  // Parse transcript for tools & todos
  const transcriptData = await parseTranscript(data.transcript_path || '');
  const toolsLine = renderToolsLine(transcriptData.tools);
  const todosLine = renderTodosLine(transcriptData.todos);

  // Token speed
  const tokenSpeed = getTokenSpeed(data.context_window);

  const SEP_MIN = ` ${c.gray('|')} `;
  const parts = [];

  // 1. cwd
  parts.push(c.brightBlue(path.basename(dir)));

  // 2. branch + changes (truncate for narrow terminals)
  if (git.branch) {
    const maxBranch = cols < 60 ? 12 : cols < 80 ? 20 : git.branch.length;
    let branchPart = c.magenta(String.fromCodePoint(0xE725) + ' ' + truncField(git.branch, maxBranch));
    const changes = [];
    if (git.staged) changes.push(c.green(`⇡${git.staged}`));
    if (git.modified) changes.push(c.yellow(`!${git.modified}`));
    if (git.untracked) changes.push(c.gray(`?${git.untracked}`));
    if (changes.length) branchPart += ' ' + c.yellow(changes.join(' '));
    parts.push(branchPart);
  }

  // 3. model
  parts.push(c.cyan(model));

  // 4. context bar (20 segments with block chars)
  if (usedPct != null) {
    const pct = Math.floor(usedPct);
    const SEGS = 20;
    const filled = Math.round((pct / 100) * SEGS);
    const empty = SEGS - filled;

    let barColor;
    if (pct < 50) barColor = c.green;
    else if (pct < 65) barColor = c.yellow;
    else if (pct < 80) barColor = c.orange;
    else barColor = c.blinkRed;

    parts.push(barColor('\u2588'.repeat(filled) + '\u2591'.repeat(empty) + ` ${pct}%`));
  }

  // Narrow terminal degradation: drop fields progressively
  // >= 60: all fields | < 60: drop version → style → lines → tokens | < 40: dir │ branch │ bar %

  if (cols < 40) {
    // Ultra-narrow: only dir, branch, bar — skip everything else
    return parts.join(SEP_MIN);
  }

  // 5. tokens (drop below 60)
  if (cols >= 60 && (totalIn != null || totalOut != null)) {
    parts.push(c.green(`${formatTokens(totalIn || 0)}↑ ${formatTokens(totalOut || 0)}↓`));
  }

  // 6. cost
  if (costUsd != null) parts.push(c.magenta(formatCost(costUsd)));

  // 7. duration + token speed + rate limits
  if (durationMs != null) parts.push(c.dim(formatDuration(durationMs)));
  if (tokenSpeed) parts.push(c.yellow(String.fromCodePoint(0xF0E7) + tokenSpeed));
  const rateLimitStr = formatRateLimits(data.rate_limits);
  if (rateLimitStr) parts.push(rateLimitStr);

  // 8. lines changed (drop below 60)
  if (cols >= 60 && (linesAdded > 0 || linesRemoved > 0)) {
    const lParts = [];
    if (linesAdded > 0) lParts.push(c.green(`+${linesAdded}`));
    if (linesRemoved > 0) lParts.push(c.red(`-${linesRemoved}`));
    parts.push(lParts.join(''));
  }

  // 9. style (drop below 60)
  if (cols >= 60) parts.push(c.gray(styleName));

  // 10. version (drop below 60)
  if (cols >= 60 && version) parts.push(c.dim(version));

  // 11. GSD + contextual
  if (gsdInfo) {
    if (gsdInfo.updateAvailable) parts.push(c.yellow('^update'));
    if (gsdInfo.taskName) parts.push(c.bold(gsdInfo.taskName));
  }
  if (worktreeName) parts.push(c.dim('wt:' + worktreeName));
  if (agentName) parts.push(c.yellow('@' + agentName));

  const baseOutput = parts.join(SEP_MIN);

  // Tools + todos en una línea extra
  const extraParts = [];
  if (toolsLine) extraParts.push(toolsLine);
  if (todosLine) extraParts.push(todosLine);
  const extraLine = extraParts.join(' │ ');

  return extraLine ? baseOutput + '\n' + extraLine : baseOutput;
}

// ── Main ─────────────────────────────────────────────────────────────

async function run() {
  let input = '';
  const stdinTimeout = setTimeout(() => process.exit(0), 3000);
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', chunk => input += chunk);
  process.stdin.on('end', async () => {
    clearTimeout(stdinTimeout);
    try {
      const data = JSON.parse(input);
      const { minimal, gsd } = parseArgs(process.argv);
      const session = data.session_id || '';

      const gsdInfo = gsd ? getGsdInfo(session) : null;
      const cols = getTermCols();
      const useMinimal = minimal || cols < 70;
      const output = useMinimal
        ? await buildMinimalOutput(data, gsdInfo)
        : await buildCustomOutput(data, gsdInfo);

      process.stdout.write(output);
    } catch (err) {
      // Only suppress JSON parse errors, log other errors to stderr without stack traces
      if (!(err instanceof SyntaxError)) {
        console.error(`Statusline error: ${err.message}`);
      }
    }
  });
}

run();
