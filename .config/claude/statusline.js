#!/usr/bin/env node

const fs = require('fs');
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
    const cwd = data.workspace?.current_dir || data.cwd || '.';

    // リポジトリ名を取得（gitリポジトリ外の場合はディレクトリ名）
    const repoName = getRepoName(cwd) || path.basename(cwd);

    const branch = getCurrentBranch(cwd);
    const isWorktree = isGitWorktree(cwd);
    const dirtyCount = getDirtyFileCount(cwd);
    const prInfo = getPrInfo(cwd);
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
      dirtyInfo = ` | \x1b[33m✎ ${dirtyCount}\x1b[0m`;
    }

    // Build PR link info
    let prLinkInfo = '';
    if (prInfo) {
      prLinkInfo = ` | \x1b[36m#${prInfo.number}\x1b[0m`;
    }

    // Build status line
    const statusLine = `[${model}] 📁 ${repoName}${gitInfo}${dirtyInfo}${prLinkInfo} | 🪙 ${tokenDisplay} | ${percentageColor}${percentage}%\x1b[0m`;

    console.log(statusLine);
  } catch (error) {
    // Fallback status line on error
    console.log('[Error] 📁 . | 🪙 0 | 0%');
  }
});

async function calculateTokensFromTranscript(filePath) {
  return new Promise((resolve, reject) => {
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
        // The last usage entry contains cumulative tokens
        const totalTokens = (lastUsage.input_tokens || 0) +
          (lastUsage.output_tokens || 0) +
          (lastUsage.cache_creation_input_tokens || 0) +
          (lastUsage.cache_read_input_tokens || 0);
        resolve(totalTokens);
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
      stdio: ['pipe', 'pipe', 'pipe']
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

function getRepoName(cwd) {
  try {
    const repoRoot = execSync('git rev-parse --show-toplevel', {
      cwd: cwd,
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe']
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
      stdio: ['pipe', 'pipe', 'pipe']
    });
    const lines = output.trim().split('\n').filter(l => l.length > 0);
    return lines.length;
  } catch (e) {
    return 0;
  }
}

function getPrInfo(cwd) {
  try {
    const output = execSync('gh pr view --json url,number -q ".number,.url"', {
      cwd: cwd,
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
      timeout: 5000
    });
    const lines = output.trim().split('\n');
    if (lines.length >= 2) {
      return { number: lines[0], url: lines[1] };
    }
    return null;
  } catch (e) {
    return null;
  }
}
