# ==========================================
# NORTHLING SHELL
# Northling Midnight Edition
# ==========================================

# Instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export PATH="$HOME/.local/bin:$PATH"
export EDITOR="${EDITOR:-nano}"
export VISUAL="$EDITOR"

# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
    git
    sudo
    extract
    fzf
    zoxide
)

source "$ZSH/oh-my-zsh.sh"

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt SHARE_HISTORY
setopt AUTO_CD
setopt INTERACTIVE_COMMENTS

# Aliases: eza
if (( $+commands[eza] )); then
    alias ls='eza --icons=always --group-directories-first'
    alias ll='eza -lah --icons=always --group-directories-first --git'
    alias la='eza -a --icons=always --group-directories-first'
    alias lt='eza --tree --level=3 --icons=always'
    alias tree='eza --tree --icons=always'
fi

# Aliases: bat
if (( $+commands[bat] )); then
    alias cat='bat --paging=never'
    alias catp='bat'
fi

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Git
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate -15'
alias gd='git diff'

# Docker
alias dps='docker ps'
alias dpa='docker ps -a'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs -f'

# System
alias ff='fastfetch'
alias top='btop'
alias ports='ss -tulpn'
alias reload='source ~/.zshrc'

# Northling commands
alias update='northling update'
alias doctor='northling doctor'

# Functions
mkcd() {
    mkdir -p -- "$1" && cd -- "$1"
}

# Northling Powerlevel10k
[[ -r "$HOME/.p10k.northling.zsh" ]] && source "$HOME/.p10k.northling.zsh"

# Personal additions
[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# Autosuggestions
if [[ -r /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# Syntax highlighting MUST be last
if [[ -r /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Fastfetch on interactive startup


# >>> NORTHLING WORKSPACE GREETING >>>
typeset -g _NORTHLING_GREETING_SHOWN=0

function northling_workspace_greeting() {
    if (( _NORTHLING_GREETING_SHOWN )); then
        return
    fi

    _NORTHLING_GREETING_SHOWN=1

    local -a phrases
    phrases=(
        'Повайбкодим?'
        'Убери руки от терминала, криворукий!'
        "Today is gonna be the day that they're gonna throw it back to you..."
        "What's the story, northling glory?"
        "Don't look back in anger, I heard you say..."
        'Вот такая хуйня-собачка...'
        'Розетки, кабеля, блять нахуй, блять нахуй.'
        'Ебаный арч, блядь!'
        'Я тебя могну.'
        'Madferit.'
        'Who the fuck is northling?'
        'Японский бог, он снова здесь...'
        'Пшел отсюда! Челядь.'
        'biblical.'
        'Is would you maybe come coding with me?'
        'Sponsored by Claude by Anthropic. And stupidity of the user.'
        'Э, я тоже помогал! - ChatGPT.'
        'нортлинг-хуертлинг'
        'Definitely (not) Maybe.'
        'Sponsored by Oasis.'
        'Copyright Liam Gallagher.'
        'Все ниженаписанное нарушает УК РФ. Как тут ФСБ вызвать?'
    )

    local phrase
    phrase="${phrases[$((RANDOM % ${#phrases[@]} + 1))]}"

    print -P "\n%F{183}n. workspace session. ($phrase)%f\n"
}

# Показываем приветствие один раз перед первым prompt.
precmd_functions=(northling_workspace_greeting $precmd_functions)
# <<< NORTHLING WORKSPACE GREETING <<<
