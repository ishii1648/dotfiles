# direnv: ディレクトリごとの .envrc で環境変数を切り替える（ghtkn の App 選択など）
# conf.d は名前順に読まれる。aqua の direnv は env.fish の AQUA_GLOBAL_CONFIG と
# path.fish の PATH が無いと起動できないので、それより後に読ませる名前にしている
if type -q direnv
    direnv hook fish | source
end
