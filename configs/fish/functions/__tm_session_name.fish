function __tm_session_name --description 'ghqパスからtmux session名を生成'
    # github.com/<org>/<repo> → <org>_<repo>
    string replace -r '^[^/]+/' '' $argv[1] | string replace -a '/' '_' | string replace -a '.' '-'
end
