# =============================================================================
# Northling Arch — Powerlevel10k: стиль «classic», Northling Midnight
# Светлые сегменты с тёмным текстом, лавандовые и голубые акценты, стрелочные разделители.
#
# Хочешь вернуть свой prompt из Windows Terminal ТОЧНО как там: положи свой файл
# ~/.p10k.zsh поверх этого (или пришли его мне — подключу в проект).
# Мастер настройки заново:  p10k configure
# =============================================================================

'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob
  unset -m '(POWERLEVEL9K_*|DEFAULT_USER)~POWERLEVEL9K_GITSTATUS_DIR'
  autoload -Uz is-at-least && is-at-least 5.1 || return

  # палитра
  local lav='#A78BFA' sky='#82BFFF' pink='#D284E5' dark='#0E0A24'
  local soft='#C4B8F5' red='#F27A9C' mint='#7FE0B0' sun='#F2D479'

  typeset -g POWERLEVEL9K_MODE=nerdfont-v3
  typeset -g POWERLEVEL9K_ICON_PADDING=moderate

  # что показываем
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(os_icon dir vcs newline prompt_char)
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time background_jobs node_version time)
  typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=true

  # стрелочные разделители (powerline)
  typeset -g POWERLEVEL9K_BACKGROUND=$soft
  typeset -g POWERLEVEL9K_FOREGROUND=$dark
  typeset -g POWERLEVEL9K_LEFT_SEGMENT_SEPARATOR=''
  typeset -g POWERLEVEL9K_RIGHT_SEGMENT_SEPARATOR=''
  typeset -g POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR=''
  typeset -g POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR=''
  typeset -g POWERLEVEL9K_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=''
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_FIRST_SEGMENT_START_SYMBOL=''
  typeset -g POWERLEVEL9K_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_LAST_SEGMENT_END_SYMBOL=
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX=
  typeset -g POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_PREFIX=
  typeset -g POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX=

  # логотип системы
  typeset -g POWERLEVEL9K_OS_ICON_BACKGROUND=$lav
  typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND=$dark

  # каталог
  typeset -g POWERLEVEL9K_DIR_BACKGROUND=$sky
  typeset -g POWERLEVEL9K_DIR_FOREGROUND=$dark
  typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND=$dark
  typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND=$dark
  typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=true
  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique

  # git
  typeset -g POWERLEVEL9K_VCS_FOREGROUND=$dark
  typeset -g POWERLEVEL9K_VCS_CLEAN_BACKGROUND=$mint
  typeset -g POWERLEVEL9K_VCS_MODIFIED_BACKGROUND=$sun
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND=$pink
  typeset -g POWERLEVEL9K_VCS_CONFLICTED_BACKGROUND=$red
  typeset -g POWERLEVEL9K_VCS_LOADING_BACKGROUND=$soft

  # символ ввода (на второй строке, без фона)
  typeset -g POWERLEVEL9K_PROMPT_CHAR_BACKGROUND=
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=$lav
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=$red
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIINS_CONTENT_EXPANSION='❯'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VICMD_CONTENT_EXPANSION='❮'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIVIS_CONTENT_EXPANSION='V'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIOWR_CONTENT_EXPANSION='▶'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OVERWRITE_STATE=true

  # справа
  typeset -g POWERLEVEL9K_STATUS_OK=false
  typeset -g POWERLEVEL9K_STATUS_ERROR=true
  typeset -g POWERLEVEL9K_STATUS_ERROR_BACKGROUND=$red
  typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND=$dark
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=3
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_PRECISION=0
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_BACKGROUND=$soft
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND=$dark
  typeset -g POWERLEVEL9K_BACKGROUND_JOBS_VERBOSE=false
  typeset -g POWERLEVEL9K_BACKGROUND_JOBS_BACKGROUND=$soft
  typeset -g POWERLEVEL9K_BACKGROUND_JOBS_FOREGROUND=$dark
  typeset -g POWERLEVEL9K_NODE_VERSION_BACKGROUND=$mint
  typeset -g POWERLEVEL9K_NODE_VERSION_FOREGROUND=$dark
  typeset -g POWERLEVEL9K_NODE_VERSION_PROJECT_ONLY=true
  typeset -g POWERLEVEL9K_TIME_BACKGROUND=$lav
  typeset -g POWERLEVEL9K_TIME_FOREGROUND=$dark
  typeset -g POWERLEVEL9K_TIME_FORMAT='%D{%H:%M}'
  typeset -g POWERLEVEL9K_TIME_UPDATE_ON_COMMAND=false

  typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=off
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
  typeset -g POWERLEVEL9K_DISABLE_HOT_RELOAD=true

  (( ! $+functions[p10k] )) || p10k reload
}

(( ${#p10k_config_opts} )) && setopt ${p10k_config_opts[@]}
'builtin' 'unset' 'p10k_config_opts'
