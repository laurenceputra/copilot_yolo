#!/usr/bin/env bash
# Bash completion for copilot_yolo

_copilot_yolo_completions() {
  local cur prev opts
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  
  # copilot_yolo specific options
  local yolo_opts="--pull health --health config --generate-config"
  
  # Common copilot CLI commands
  local copilot_cmds="login logout status explain review test describe"
  
  # Combine all options
  opts="${yolo_opts} ${copilot_cmds} --help --version --yolo"
  
  # Provide completions
  COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
  
  # Also complete filenames for some commands
  if [[ "${prev}" =~ ^(explain|review|test|describe)$ ]]; then
    COMPREPLY+=( $(compgen -f -- "${cur}") )
  fi
  
  return 0
}

complete -F _copilot_yolo_completions copilot_yolo
