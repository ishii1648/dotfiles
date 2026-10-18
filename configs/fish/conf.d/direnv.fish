# direnv: ディレクトリごとの .envrc で環境変数を切り替える（ghtkn の App 選択など）
if type -q direnv
    direnv hook fish | source
end
