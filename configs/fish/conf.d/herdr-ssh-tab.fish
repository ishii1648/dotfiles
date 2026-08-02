# ADR-078: ssh ラッパ（functions/ssh.fish）が変えた herdr のタブラベルを元に戻す。
# fish は前景ジョブが SIGINT で終了すると関数の残りを実行しないため、書き戻しを
# ssh 関数の末尾に置くと接続待ちの Ctrl-C でラベルが残る。正常終了でも中断でも
# 必ず出るプロンプトのイベントに一本化する。

status is-interactive; or return

function __herdr_ssh_tab_restore --on-event fish_prompt --description 'ssh 後に herdr のタブラベルを戻す（ADR-078）'
    set -q __herdr_ssh_prev_tab_label; or return
    if set -q HERDR_TAB_ID
        herdr tab rename $HERDR_TAB_ID "$__herdr_ssh_prev_tab_label" >/dev/null 2>&1
    end
    set -e __herdr_ssh_prev_tab_label
end
