#!/usr/bin/env node

const fs = require('fs');
const https = require('https');
const path = require('path');
const readline = require('readline');
const { execSync, spawn } = require('child_process');
const crypto = require('crypto');

// Constants
// フォールバック用（stdin に context_window が来ない/未完成の旧バージョン向け）。
const COMPACTION_THRESHOLD_DEFAULT = 150000;
const COMPACTION_THRESHOLD_1M = 950000;

// 1M context モデル判定のパターン。stdin の context_window.context_window_size
// を最優先とし、来ない旧バージョン CC 向けの最終フォールバックとして使う。
// - "[1m]" サフィックス: Opus 4.7/4.8 (1M) 系
// 注: Fable 5 は Anthropic 公式仕様上 1M モデルだが、CC v2.1.191 は stdin で
// context_window_size=200000 を申告してくる。CC 側の申告を尊重し、ここでは
// あえて fable パターンを加えない（CC が 200k と言うなら 200k で表示する）。
const ONE_M_MODEL_PATTERNS = [/\[1m\]/];
function isOneMContextModel(modelId) {
  return ONE_M_MODEL_PATTERNS.some(re => re.test(modelId));
}

// Read JSON from stdin
let input = '';
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', async () => {
  try {
    const data = JSON.parse(input);

    // Extract values
    const model = data.model?.display_name || 'Unknown';
    const modelId = data.model?.id || '';
    // Claude Code 本体が渡す context_window（新しめのバージョンのみ）を優先する。
    // model.id の "[1m]" サフィックスは 1M モデルでも付かない場合があり、それだけでは判定できない。
    const cw = data.context_window;
    const maxContext = cw?.context_window_size || (isOneMContextModel(modelId) ? 1000000 : 200000);
    const autocompactPct = parseInt(process.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE || '0');
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
    // Fable の週間利用率は stdin の rate_limits に含まれず oauth/usage API の
    // limits[] からしか取れないため、stdin が来ていても API 呼び出しは常時行う
    // （getRateLimitUsage 内で 6 分キャッシュ済みなのでコストは小さい）。
    const apiRateLimitUsage = await getRateLimitUsage();
    const rateLimitUsage = stdinRateLimits || apiRateLimitUsage;
    const fableUsage = apiRateLimitUsage?.fable || null;
    const sessionId = data.session_id;

    // Calculate token usage for current session
    let totalTokens = 0;

    if (cw?.current_usage) {
      const u = cw.current_usage;
      totalTokens = (u.input_tokens || 0) + (u.output_tokens || 0) +
        (u.cache_creation_input_tokens || 0) + (u.cache_read_input_tokens || 0);
    } else if (sessionId) {
      // フォールバック: transcript ファイルから集計（旧バージョン向け）
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

    // Calculate percentage / display threshold（自動圧縮が発動する実際の分母）
    let percentage, displayThreshold;
    if (autocompactPct > 0) {
      displayThreshold = Math.round(maxContext * autocompactPct / 100);
      percentage = Math.min(100, Math.round((totalTokens / displayThreshold) * 100));
    } else if (cw?.used_percentage != null) {
      // Claude Code 本体が計算済みの使用率をそのまま使い、閾値はそこから逆算する
      percentage = Math.min(100, cw.used_percentage);
      displayThreshold = percentage > 0 ? Math.round(totalTokens / (percentage / 100)) : maxContext;
    } else {
      // used_percentage 未着（起動直後や旧バージョン CC）。maxContext から閾値を導出する。
      // 200k → 150k, 1M → 950k, その他は 95% を目安。
      displayThreshold = maxContext >= 1000000 ? COMPACTION_THRESHOLD_1M
        : maxContext <= 200000 ? COMPACTION_THRESHOLD_DEFAULT
        : Math.round(maxContext * 0.95);
      percentage = Math.min(100, Math.round((totalTokens / displayThreshold) * 100));
    }

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

    // tier 情報（claude auth status のキャッシュ）
    const { tier } = getTierAndOrg();
    let tierOrgInfo = '';
    if (tier) tierOrgInfo += `[\x1b[36m${tier}\x1b[0m]`;

    // Line 1: 基本情報 + プログレスバー
    let statusLine = `${tierOrgInfo}[${modelDisplay}] 📁 ${repoName}${gitInfo}${dirtyInfo}${prLinkInfo} | ctx ${coloredBar(percentage, 10)} ${percentage}% (${tokenDisplay}/${thresholdDisplay})`;
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
    if (fableUsage?.percent != null) {
      const pct = Math.round(fableUsage.percent);
      const resetInfo = fableUsage.resetsAt ? ` ${formatTimeRemaining(fableUsage.resetsAt)}` : '';
      statusLine += ` | fable ${coloredBar(pct, 8)} ${pct}%${resetInfo}`;
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

function getTierAndOrg() {
  const configDir = process.env.CLAUDE_CONFIG_DIR || path.join(process.env.HOME, '.claude');
  const tierCache = path.join(configDir, '.tier_cache');
  const orgCache = path.join(configDir, '.org_cache');

  try {
    if (fs.existsSync(tierCache) && fs.existsSync(orgCache)) {
      return {
        tier: fs.readFileSync(tierCache, 'utf8').trim(),
        org: fs.readFileSync(orgCache, 'utf8').trim(),
      };
    }
  } catch (e) {}

  try {
    fs.mkdirSync(configDir, { recursive: true });
    const script = `out=$(claude auth status 2>/dev/null) || exit 0; ` +
                   `printf '%s' "$out" | jq -r '.subscriptionType // ""' > "${tierCache}" && ` +
                   `printf '%s' "$out" | jq -r '.orgName // ""' > "${orgCache}"`;
    const child = spawn('/bin/sh', ['-c', script], {
      detached: true,
      stdio: 'ignore',
      env: process.env,
    });
    child.unref();
  } catch (e) {}

  return { tier: 'Loading...', org: '' };
}

function getPrInfo(cwd) {
  const cacheTTL = 600000; // 10 min
  let cacheFile = null;
  try {
    const branch = getCurrentBranch(cwd) || '';
    const key = crypto.createHash('md5').update(`${cwd}\0${branch}`).digest('hex');
    cacheFile = `/tmp/claude-gh-pr-cache-${key}.json`;
    if (fs.existsSync(cacheFile)) {
      const cache = JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
      if (Date.now() - cache.timestamp < cacheTTL) {
        return cache.data;
      }
    }
  } catch (e) {
    // cache miss
  }

  let result = null;
  try {
    const output = execSync('gh pr view --json url,number,isDraft -q ".number,.url,.isDraft"', {
      cwd: cwd,
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
      timeout: 5000
    });
    const lines = output.trim().split('\n');
    if (lines.length >= 3) {
      result = { number: lines[0], url: lines[1], isDraft: lines[2] === 'true' };
    }
  } catch (e) {
    result = null;
  }

  if (cacheFile) {
    try {
      fs.writeFileSync(cacheFile, JSON.stringify({ timestamp: Date.now(), data: result }));
    } catch (e) {}
  }
  return result;
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

  // Keychain/credentials から全トークン候補を収集
  const tokens = [];
  try {
    if (process.platform === 'darwin') {
      const dump = execSync('security dump-keychain 2>&1', {
        encoding: 'utf8',
        stdio: ['pipe', 'pipe', 'pipe'],
        timeout: 3000
      });
      const svcMatches = [...dump.matchAll(/"(Claude Code-credentials[^"]*)"/g)].map(m => m[1]);
      for (const svc of svcMatches) {
        try {
          const raw = execSync(`security find-generic-password -s "${svc}" -w`, {
            encoding: 'utf8',
            stdio: ['pipe', 'pipe', 'pipe'],
            timeout: 3000
          }).trim();
          const parsed = JSON.parse(raw);
          const t = parsed.claudeAiOauth?.accessToken;
          if (t) tokens.push(t);
        } catch (_) {}
      }
    } else {
      const credPath = path.join(process.env.HOME, '.claude', '.credentials.json');
      const cred = JSON.parse(fs.readFileSync(credPath, 'utf8'));
      const t = cred.claudeAiOauth?.accessToken;
      if (t) tokens.push(t);
    }
  } catch (e) {
    return null;
  }

  // 各トークンで API を試し、成功したものを返す
  for (const token of tokens) {
    try {
      const responseStr = await httpsGet('https://api.anthropic.com/api/oauth/usage', {
        'Authorization': `Bearer ${token}`,
        'anthropic-beta': 'oauth-2025-04-20',
      });
      const data = JSON.parse(responseStr);
      if (data.error) continue;
      const fableLimit = Array.isArray(data.limits)
        ? data.limits.find(l => l?.scope?.model?.display_name?.toLowerCase() === 'fable')
        : null;
      const result = {
        fiveHour: data.five_hour?.utilization ?? null,
        sevenDay: data.seven_day?.utilization ?? null,
        monthly: data.extra_usage?.is_enabled ? (data.extra_usage?.utilization ?? null) : null,
        fable: fableLimit ? { percent: fableLimit.percent, resetsAt: fableLimit.resets_at } : null,
      };
      fs.writeFileSync(cacheFile, JSON.stringify({ timestamp: Date.now(), data: result }));
      return result;
    } catch (_) {}
  }

  // 全トークン失敗
  fs.writeFileSync(cacheFile, JSON.stringify({ timestamp: Date.now(), error: true }));
  return null;
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
