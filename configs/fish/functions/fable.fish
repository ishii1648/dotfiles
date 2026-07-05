function fable --wraps claude --description 'Fable 5をメインループ、subagentsをSonnetに固定してclaudeを起動'
    env CLAUDE_CODE_SUBAGENT_MODEL=sonnet \
        claude --model fable \
        --permission-mode plan \
        --effort medium \
        --append-system-prompt "基本的にタスクや作業の実行は、適切な粒度で subagents に実行手順が明確な指示を与えて委譲すること。あなたは全体進行の俯瞰と計画立案に専念する。委譲する方が非効率な軽微な確認・単純な1手の変更は自己判断で自分で行ってよい。" \
        $argv
end
