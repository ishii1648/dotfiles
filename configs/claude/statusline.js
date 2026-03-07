#!/usr/bin/env node

const fs = require('fs');
const https = require('https');
const path = require('path');
const readline = require('readline');
const { execSync } = require('child_process');

// Constants
const COMPACTION_THRESHOLD = 200000 * 0.8

// Read JSON from stdin
let input = '';
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', async () => {
  try {
    const data = JSON.parse(input);

    // Extract values
    const model = data.model?.display_name || 'Unknown';
    const effortLevel = getEffortLevel();
    const cwd = data.workspace?.current_dir || data.cwd || '.';

    // リポジトリ名を取得（gitリポジトリ外の場合はディレクトリ名）
    const repoName = getRepoName(cwd) || path.basename(cwd);

    const branch = getCurrentBranch(cwd);
    const isWorktree = isGitWorktree(cwd);
    const dirtyCount = getDirtyFileCount(cwd);
    const prInfo = getPrInfo(cwd);
    const rateLimitUsage = await getRateLimitUsage();
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
    const percentage = Math.min(100, Math.round((totalTokens / COMPACTION_THRESHOLD) * 100));

    // Format token display
    const tokenDisplay = formatTokenCount(totalTokens);

    // Color coding for percentage
    let percentageColor = '\x1b[32m'; // Green
    if (percentage >= 70) percentageColor = '\x1b[33m'; // Yellow
    if (percentage >= 90) percentageColor = '\x1b[31m'; // Red

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

    // Build rate limit info
    let rateLimitInfo = '';
    if (rateLimitUsage) {
      const colorizeRate = (pct) => {
        if (pct == null) return null;
        const pctNum = Math.round(pct * 100);
        let color = '\x1b[32m'; // green
        if (pctNum >= 50) color = '\x1b[33m'; // yellow
        if (pctNum >= 80) color = '\x1b[31m'; // red
        return `${color}${pctNum}%\x1b[0m`;
      };
      const fiveH = colorizeRate(rateLimitUsage.fiveHour);
      const sevenD = colorizeRate(rateLimitUsage.sevenDay);
      if (fiveH != null || sevenD != null) {
        rateLimitInfo = ` | 5h:${fiveH ?? 'N/A'} 7d:${sevenD ?? 'N/A'}`;
      }
    }

    // Build status line
    const statusLine = `[${modelDisplay}] 📁 ${repoName}${gitInfo}${dirtyInfo}${prLinkInfo} | 🪙 ${tokenDisplay} | ${percentageColor}${percentage}%\x1b[0m${rateLimitInfo}`;

    console.log(statusLine);
  } catch (error) {
    // Fallback status line on error
    console.log('[Error] 📁 . | 🪙 0 | 0%');
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
    return `${(tokens / 1000000).toFixed(1)}M`;
  } else if (tokens >= 1000) {
    return `${(tokens / 1000).toFixed(1)}K`;
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

async function getRateLimitUsage() {
  const cacheFile = '/tmp/claude-usage-cache.json';
  const cacheTTL = 360000; // 360 seconds

  try {
    if (fs.existsSync(cacheFile)) {
      const cache = JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
      if (Date.now() - cache.timestamp < cacheTTL) {
        return cache.data;
      }
    }
  } catch (e) {
    // cache miss
  }

  let token;
  try {
    const credPath = path.join(process.env.HOME, '.claude', '.credentials.json');
    const cred = JSON.parse(fs.readFileSync(credPath, 'utf8'));
    token = cred.claudeAiOauth?.accessToken;
  } catch (e) {
    return null;
  }

  if (!token) return null;

  try {
    const responseStr = await httpsGet('https://api.anthropic.com/api/oauth/usage', {
      'Authorization': `Bearer ${token}`
    });
    const data = JSON.parse(responseStr);
    if (data.error) return null;
    const result = {
      fiveHour: data.five_hour?.utilization ?? null,
      sevenDay: data.seven_day?.utilization ?? null,
    };
    if (result.fiveHour != null || result.sevenDay != null) {
      fs.writeFileSync(cacheFile, JSON.stringify({ timestamp: Date.now(), data: result }));
    }
    return result;
  } catch (e) {
    return null;
  }
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
