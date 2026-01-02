function g_co_command_push_f
  git commit -a --amend
  set current_branch (git rev-parse --abbrev-ref HEAD)
  git push-f origin $current_branch
end
