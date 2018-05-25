" 自動実行用SCPの登録
function! SyncFile(local_dir, remote_dir)
    let upload_settings = { a:local_dir: a:remote_dir }
    let cnt_dir = expand("%:p:h")
    if has_key(upload_settings, cnt_dir)
        exe '!scp % ' .  a:remote_dir
    endif
endfunction
