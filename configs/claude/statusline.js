#!/usr/bin/env node

const fs = require('fs');
const https = require('https');
const path = require('path');
const readline = require('readline');
const { execSync } = require('child_process');
const crypto = require('crypto');

// Constants
// モデルIDに "[1m]" が含まれる場合は 1M context モデル
const COMPACTION_THRESHOLD_DEFAULT = 150000;
const COMPACTION_THRESHOLD_1M = 950000;

// Read JSON from stdin
let input = '';
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', async () => {
  try {
    const data = JSON.parse(input);

    // Extract values
    const model = data.model?.display_name || 'Unknown';
    const modelId = data.model?.id || '';
    const maxContext = modelId.includes('[1m]') ? 1000000 : 200000;
    const autocompactPct = parseInt(process.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE || '0');
    const compactionThreshold = modelId.includes('[1m]') ? COMPACTION_THRESHOLD_1M : COMPACTION_THRESHOLD_DEFAULT;
    const displayThreshold = autocompactPct > 0 ? Math.round(maxContext * autocompactPct / 100) : compactionThreshold;
    const effortLevel = getEffortLevel();
    const cwd = data.workspace?.current_dir || data.cwd || '.';

    // リポジトリ名を取得（gitリポジトリ外の場合はディレクトリ名）
    const repoName = getRepoName(cwd) || path.basename(cwd);

    const branch = getCurrentBranch(cwd);
    const isWorktree = isGitWorktree(cwd);
    const dirtyCount = getDirtyFileCount(cwd);
    const prInfo = getPrInfo(cwd);
    // tmux-fzf-url フィルター用キャッシュ（gh pr view のネットワーク遅延を回避）
    try {
      const hash = crypto.createHash('md5').update(cwd).digest('hex');
      const prCacheFile = `/tmp/gh-pr-${hash}`;
      if (prInfo) {
        fs.writeFileSync(prCacheFile, `${prInfo.number} ${prInfo.url}`);
      } else if (fs.existsSync(prCacheFile)) {
        fs.unlinkSync(prCacheFile);
      }
    } catch (e) {}
    const stdinRateLimits = parseStdinRateLimits(data.rate_limits);
    const rateLimitUsage = stdinRateLimits || await getRateLimitUsage();
    const sessionId = data.session_id;

    // Calculate token usage for current session
    let totalTokens = 0;

    if (sessionId) {
      // Find all transcript files
      const projectsDir = path.join(process.env.HOME, '.claude', 'projects');

      if (fs.existsSync(projectsDir)) {
        // Get all project directories
        const projectDirs = fs.readdirSync(projectsDir)
          .map(dir => path.join(projectsDir, dir))
          .filter(dir => fs.statSync(dir).isDirectory());

        // Search for the current session's transcript file
        for (const projectDir of projectDirs) {
          const transcriptFile = path.join(projectDir, `${sessionId}.jsonl`);

          if (fs.existsSync(transcriptFile)) {
            totalTokens = await calculateTokensFromTranscript(transcriptFile);
            break;
          }
        }
      }
    }

    // Calculate percentage
    const percentage = Math.min(100, Math.round((totalTokens / displayThreshold) * 100));

    // Format token display
    const tokenDisplay = formatTokenCount(totalTokens);
    const thresholdDisplay = formatTokenCount(displayThreshold);

    // Build git info
    let gitInfo = '';
    if (branch) {
      const worktreeIcon = isWorktree ? '🌳' : '🌿';
      const branchDisplay = isWorktree ? `\x1b[32m${branch}\x1b[0m` : branch;
      gitInfo = ` | ${worktreeIcon} ${branchDisplay}`;
    }

    // Build dirty files info
    let dirtyInfo = '';
    if (dirtyCount > 0) {
      dirtyInfo = ` | \x1b[33m📝 ${dirtyCount}\x1b[0m`;
    }

    // Build PR link info (compact #NNN — tmux-fzf-url extra filter で PR URL を解決)
    let prLinkInfo = '';
    if (prInfo) {
      // draft: gray (\x1b[90m), open: green (\x1b[32m)
      const prColor = prInfo.isDraft ? '\x1b[90m' : '\x1b[32m';
      prLinkInfo = ` | ${prColor}#${prInfo.number}\x1b[0m`;
    }

    // Build model display with optional effort level
    const modelDisplay = effortLevel ? `${model}|${effortLevel}` : model;

    // Line 1: 基本情報 + プログレスバー
    let statusLine = `[${modelDisplay}] 📁 ${repoName}${gitInfo}${dirtyInfo}${prLinkInfo} | ctx ${coloredBar(percentage, 10)} ${percentage}% (${tokenDisplay}/${thresholdDisplay})`;
    if (rateLimitUsage) {
      const fiveH = rateLimitUsage.fiveHour;
      const sevenD = rateLimitUsage.sevenDay;
      const monthly = rateLimitUsage.monthly;
      if (fiveH != null) {
        const pct = Math.round(fiveH);
        const resetInfo = rateLimitUsage.fiveHourResetsAt ? ` ${formatTimeRemaining(rateLimitUsage.fiveHourResetsAt)}` : '';
        statusLine += ` | 5h ${coloredBar(pct, 8)} ${pct}%${resetInfo}`;
      }
      if (sevenD != null) {
        const pct = Math.round(sevenD);
        const resetInfo = rateLimitUsage.sevenDayResetsAt ? ` ${formatTimeRemaining(rateLimitUsage.sevenDayResetsAt)}` : '';
        statusLine += ` | 7d ${coloredBar(pct, 8)} ${pct}%${resetInfo}`;
      }
      if (monthly != null) {
        const pct = Math.round(monthly);
        statusLine += ` | mo ${coloredBar(pct, 8)} ${pct}%`;
      }
    }
    console.log(statusLine);
  } catch (error) {
    // Fallback status line on error
    console.log('[Error] 📁 . | ctx 0 | 0%');
  }
});

async function calculateTokensFromTranscript(filePath) {
  return new Promise((resolve, reject) => {
    // コンテキスト使用量を計算するため、最後のリクエストのusage情報を使用
    let lastUsage = null;

    const fileStream = fs.createReadStream(filePath);
    const rl = readline.createInterface({
      input: fileStream,
      crlfDelay: Infinity
    });

    rl.on('line', (line) => {
      try {
        const entry = JSON.parse(line);

        // Check if this is an assistant message with usage data
        if (entry.type === 'assistant' && entry.message?.usage) {
          lastUsage = entry.message.usage;
        }
      } catch (e) {
        // Skip invalid JSON lines
      }
    });

    rl.on('close', () => {
      if (lastUsage) {
        // 最後のリクエスト時点でのコンテキストサイズ
        // = 入力トークン（キャッシュ含む）+ 出力トークン
        const contextSize = (lastUsage.input_tokens || 0) +
          (lastUsage.output_tokens || 0) +
          (lastUsage.cache_creation_input_tokens || 0) +
          (lastUsage.cache_read_input_tokens || 0);
        resolve(contextSize);
      } else {
        resolve(0);
      }
    });

    rl.on('error', (err) => {
      reject(err);
    });
  });
}

function formatTokenCount(tokens) {
  if (tokens >= 1000000) {
    return `${Math.floor(tokens / 1000000)}M`;
  } else if (tokens >= 1000) {
    return `${Math.floor(tokens / 1000)}k`;
  }
  return tokens.toString();
}

function getCurrentBranch(cwd) {
  try {
    const branch = execSync('git rev-parse --abbrev-ref HEAD', {
      cwd: cwd,
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
      env: { ...process.env, GIT_OPTIONAL_LOCKS: '0' }
    }).trim();
    return branch;
  } catch (e) {
    return null;
  }
}

function isGitWorktree(cwd) {
  try {
    const gitPath = path.join(cwd, '.git');
    // worktree の場合、.git はファイル（gitdir: ... を含む）
    // 通常のリポジトリの場合、.git はディレクトリ
    const stat = fs.statSync(gitPath);
    return stat.isFile();
  } catch (e) {
    return false;
  }
}

function getParentRepoRoot(cwd) {
  try {
    const gitPath = path.join(cwd, '.git');
    const gitContent = fs.readFileSync(gitPath, 'utf8');
    // gitdir: /path/to/parent/.git/worktrees/<name>
    const match = gitContent.match(/gitdir:\s*(.+)/);
    if (match) {
      const gitdir = match[1].trim();
      // .git/worktrees/<name> を削除して親リポジトリのルートを取得
      const parentGitDir = gitdir.replace(/\/worktrees\/[^/]+$/, '');
      // .git を削除してリポジトリルートを取得
      return parentGitDir.replace(/\/.git$/, '');
    }
    return null;
  } catch (e) {
    return null;
  }
}

function getRepoName(cwd) {
  try {
    // worktreeの場合、親リポジトリ名を取得
    if (isGitWorktree(cwd)) {
      const parentRepoRoot = getParentRepoRoot(cwd);
      if (parentRepoRoot) {
        return path.basename(parentRepoRoot);
      }
    }
    // 通常のリポジトリの場合
    const repoRoot = execSync('git rev-parse --show-toplevel', {
      cwd: cwd,
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
      env: { ...process.env, GIT_OPTIONAL_LOCKS: '0' }
    }).trim();
    return path.basename(repoRoot);
  } catch (e) {
    return null;
  }
}

function getDirtyFileCount(cwd) {
  try {
    const output = execSync('git status --porcelain', {
      cwd: cwd,
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
      env: { ...process.env, GIT_OPTIONAL_LOCKS: '0' }
    });
    const lines = output.trim().split('\n').filter(l => l.length > 0);
    return lines.length;
  } catch (e) {
    return 0;
  }
}

function getEffortLevel() {
  try {
    const settingsPath = path.join(process.env.HOME, '.claude', 'settings.json');
    const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
    // Claude Code はデフォルト値 "high" の場合、settings.json にキーを書き込まない
    return settings.effortLevel || 'high';
  } catch (e) {
    return 'high';
  }
}

function getPrInfo(cwd) {
  try {
    const output = execSync('gh pr view --json url,number,isDraft -q ".number,.url,.isDraft"', {
      cwd: cwd,
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
      timeout: 5000
    });
    const lines = output.trim().split('\n');
    if (lines.length >= 3) {
      return { number: lines[0], url: lines[1], isDraft: lines[2] === 'true' };
    }
    return null;
  } catch (e) {
    return null;
  }
}

function parseStdinRateLimits(rateLimits) {
  if (!rateLimits) return null;
  const fiveHour = rateLimits.five_hour;
  const sevenDay = rateLimits.seven_day;
  if (fiveHour == null && sevenDay == null) return null;
  return {
    fiveHour: fiveHour?.used_percentage ?? null,
    fiveHourResetsAt: fiveHour?.resets_at ?? null,
    sevenDay: sevenDay?.used_percentage ?? null,
    sevenDayResetsAt: sevenDay?.resets_at ?? null,
    monthly: null,
  };
}

function formatTimeRemaining(resetsAt) {
  if (!resetsAt) return '';
  const diffMs = new Date(resetsAt) - new Date();
  if (diffMs <= 0) return '';
  const hours = Math.floor(diffMs / (1000 * 60 * 60));
  const minutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
  if (hours > 0) return `${hours}h${minutes}m`;
  return `${minutes}m`;
}

async function getRateLimitUsage() {
  const cacheFile = '/tmp/claude-usage-cache.json';
  const cacheTTL = 360000;     // 成功時: 6分
  const errorCacheTTL = 360000; // エラー時: 6分（usage API 自体のレートリミット対策）

  try {
    if (fs.existsSync(cacheFile)) {
      const cache = JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
      const ttl = cache.error ? errorCacheTTL : cacheTTL;
      if (Date.now() - cache.timestamp < ttl) {
        return cache.error ? null : cache.data;
      }
    }
  } catch (e) {
    // cache miss
  }

  let token;
  try {
    let cred;
    if (process.platform === 'darwin') {
      // macOS: Keychain から読み出し
      const raw = execSync('security find-generic-password -s "Claude Code-credentials" -w', {
        encoding: 'utf8',
        stdio: ['pipe', 'pipe', 'pipe'],
        timeout: 3000
      }).trim();
      cred = JSON.parse(raw);
    } else {
      // Linux: credentials.json から読む
      const credPath = path.join(process.env.HOME, '.claude', '.credentials.json');
      cred = JSON.parse(fs.readFileSync(credPath, 'utf8'));
    }
    token = cred.claudeAiOauth?.accessToken;
  } catch (e) {
    return null;
  }

  if (!token) return null;

  try {
    const responseStr = await httpsGet('https://api.anthropic.com/api/oauth/usage', {
      'Authorization': `Bearer ${token}`,
      'anthropic-beta': 'oauth-2025-04-20',
    });
    const data = JSON.parse(responseStr);
    if (data.error) {
      fs.writeFileSync(cacheFile, JSON.stringify({ timestamp: Date.now(), error: true }));
      return null;
    }
    const result = {
      fiveHour: data.five_hour?.utilization ?? null,
      sevenDay: data.seven_day?.utilization ?? null,
      monthly: data.extra_usage?.is_enabled ? (data.extra_usage?.utilization ?? null) : null,
    };
    fs.writeFileSync(cacheFile, JSON.stringify({ timestamp: Date.now(), data: result }));
    return result;
  } catch (e) {
    return null;
  }
}

function coloredBar(pct, width) {
  const filled = Math.round(Math.min(100, pct) / 100 * width);
  const bar = '█'.repeat(filled) + '░'.repeat(width - filled);
  let color = '\x1b[32m'; // green
  if (pct >= 50) color = '\x1b[33m'; // yellow
  if (pct >= 80) color = '\x1b[31m'; // red
  return `${color}${bar}\x1b[0m`;
}

function httpsGet(url, headers) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const req = https.request({
      hostname: urlObj.hostname,
      path: urlObj.pathname,
      method: 'GET',
      headers,
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve(data));
    });
    req.setTimeout(5000, () => req.destroy());
    req.on('error', reject);
    req.end();
  });
}
