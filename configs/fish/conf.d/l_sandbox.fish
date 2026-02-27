# sandbox-ishii1648 のPC固有設定を読み込む（存在しない場合はスキップ）
set -l _sandbox_conf (ghq root)/github.com/C-FO/sandbox-ishii1648/configs/fish/conf.d/local.fish
if test -f $_sandbox_conf
    source $_sandbox_conf
end
