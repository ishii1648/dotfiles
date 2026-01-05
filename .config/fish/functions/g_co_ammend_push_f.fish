function g_co_ammend_push_f -d "git commit -a --amend & push force"
  git commit -a --amend
  set current_branch (git rev-parse --abbrev-ref HEAD)
  git push-f origin $current_branch
end
