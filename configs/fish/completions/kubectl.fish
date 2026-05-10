# kubectl 補完ハング対策。
# Why: cobra 生成の補完は内部で `kubectl __complete ...` を呼び、API server へ
#   discovery リクエストを投げる。接続不能時は client-go のメモリキャッシュ層が
#   複数回リトライするので --request-timeout だけでは抑え切れず、TAB のたびに
#   数十秒固まる (主に SSH トンネル切断時の k3s クラスタ等で発生)。
# How: 既定の補完を読み込んだ後、__kubectl_perform_completion を再定義し、
#   eval 全体を `timeout 1` で包んで上限 1 秒で打ち切る。

if not type -q kubectl
    exit
end

# cobra 生成スクリプトを読み込み、補完登録を済ませる
kubectl completion fish 2>/dev/null | source

# eval を timeout 付きに差し替えた版で再定義
function __kubectl_perform_completion
    set -l args (commandline -opc)
    set -l lastArg (string escape -- (commandline -ct))

    set -l timeout_cmd
    if type -q timeout
        set timeout_cmd timeout 1
    else if type -q gtimeout
        set timeout_cmd gtimeout 1
    end

    set -l requestComp "KUBECTL_ACTIVE_HELP=0 $timeout_cmd $args[1] --request-timeout=500ms __complete $args[2..-1] $lastArg"

    set -l results (eval $requestComp 2>/dev/null)

    for line in $results[-1..1]
        if test (string trim -- $line) = ""
            set results $results[1..-2]
        else
            break
        end
    end

    set -l comps $results[1..-2]
    set -l directiveLine $results[-1]

    set -l flagPrefix (string match -r -- '-.*=' "$lastArg")

    for comp in $comps
        printf "%s%s\n" "$flagPrefix" "$comp"
    end

    printf "%s\n" "$directiveLine"
end
