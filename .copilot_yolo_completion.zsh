#compdef copilot_yolo
# shellcheck shell=bash disable=SC2034,SC2154

# Zsh completion for copilot_yolo

_copilot_yolo() {
  local -a copilot_yolo_opts copilot_cmds
  
  copilot_yolo_opts=(
    '--pull[Force pull base image when building]'
    'health[Run health check diagnostics]'
    '--health[Run health check diagnostics]'
    'config[Generate sample configuration file]'
    '--generate-config[Generate sample configuration file]'
  )
  
  copilot_cmds=(
    'login[Sign in to GitHub Copilot]'
    'logout[Sign out from GitHub Copilot]'
    'status[Check authentication status]'
    'explain[Explain code or commands]'
    'review[Review code changes]'
    'test[Generate tests]'
    'describe[Describe code or files]'
    '--help[Show help information]'
    '--version[Show version information]'
    '--yolo[Enable YOLO mode]'
  )
  
  _arguments -C \
    '1: :->cmds' \
    '*:: :->args'
  
  case "${state}" in
    cmds)
      _describe 'copilot_yolo commands' copilot_yolo_opts
      _describe 'copilot commands' copilot_cmds
      ;;
    args)
      case "${words[1]}" in
        explain|review|test|describe)
          _files
          ;;
        *)
          _describe 'copilot commands' copilot_cmds
          ;;
      esac
      ;;
  esac
}

_copilot_yolo "$@"
