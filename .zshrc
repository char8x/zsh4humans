if (( _z4h_initialized )); then
  print -ru2 -- ${(%):-"%F{3}z4h%f: please use %F{2}%Uexec%u zsh%f instead of %F{2}source%f %U~/.zshrc%u"}
  return 1
fi

emulate zsh

emulate zsh -o posix_argzero -c ': ${Z4H_ZSH:=${${0#-}:-zsh}}' # command to start zsh
: ${Z4H_DIR:=${XDG_CACHE_HOME:-~/.cache}/zsh4humans}           # cache directory
: ${Z4H_UPDATE_DAYS=13}                                        # update dependencies this often

function z4h() {
  emulate -L zsh -o pipe_fail

  case $ARGC-$1 in
    1-init)   local -i update=0;;
    1-update) local -i update=1;;
    2-source)
      [[ -r $2 ]] || return
      if [[ ! $2.zwc -nt $2 && -w ${2:h} ]]; then
        zmodload -F zsh/files b:zf_mv b:zf_rm || return
        local tmp=$2.tmp.$$.zwc
        {
          zcompile -R -- $tmp $2 && zf_mv -f -- $tmp $2.zwc || return
        } always {
          (( $? )) && zf_rm -f -- $tmp
        }
      fi
      source -- $2
      return
    ;;
    *)
      print -ru2 -- ${(%):-"usage: %F{2}z4h%f [%Binit%b]|[%Bupdate%b]|[%Bsource%b %Ufile%u]"}
      return 1
    ;;
  esac

  (( _z4h_initialized && ! update )) && exec -- $Z4H_ZSH

  # GitHub projects to clone.
  local github_repos=(
    zsh-users/zsh-syntax-highlighting  # https://github.com/zsh-users/zsh-syntax-highlighting
    zsh-users/zsh-autosuggestions      # https://github.com/zsh-users/zsh-autosuggestions
    zsh-users/zsh-completions          # https://github.com/zsh-users/zsh-completions
    romkatv/powerlevel10k              # https://github.com/romkatv/powerlevel10k
    Aloxaf/fzf-tab                     # https://github.com/Aloxaf/fzf-tab
    junegunn/fzf                       # https://github.com/junegunn/fzf
  )

  {
    if [[ ! -e $Z4H_DIR/.last-update-ts ]]; then
      zmodload -F zsh/files b:zf_mkdir || return
      zf_mkdir -p -- $Z4H_DIR || return
      print -n >$Z4H_DIR/.last-update-ts || return
    elif [[ $update == 0 && $Z4H_UPDATE_DAYS == <-> ]]; then
      # Check if update is required.
      zmodload zsh/stat zsh/datetime || return
      local -a last_update_ts
      if zstat -A last_update_ts +mtime -- $Z4H_DIR/.last-update-ts 2>/dev/null &&
         (( EPOCHSECONDS - last_update_ts[1] >= 86400 * Z4H_UPDATE_DAYS )); then
        local REPLY
        read -q ${(%):-"?%F{3}z4h%f: update dependencies? [y/N]: "} && update=1
        print -u2
        (( update )) || print -ru2 -- ${(%):-"%F{3}z4h%f: type %F{2}z4h%f %Bupdate%b to update"}
        print -n >$Z4H_DIR/.last-update-ts || return
      fi
    fi

    # Clone or update all repositories.
    local repo
    for repo in $github_repos; do
      [[ -d $Z4H_DIR/$repo && $update == 0 ]] && continue
      if [[ -d $Z4H_DIR/$repo/.git && $+commands[git] == 1 ]]; then
        print -ru2 -- ${(%):-"%F{3}z4h%f: updating %B${repo//\%/%%}%b"}
        >&2 git -C $Z4H_DIR/$repo pull || return
      elif (( $+commands[git] )); then
        print -ru2 -- ${(%):-"%F{3}z4h%f: cloning %B${repo//\%/%%}%b"}
        zmodload -F zsh/files b:zf_rm || return
        zf_rm -rf -- $Z4H_DIR/$repo || return
        >&2 git clone --depth=1 -- https://github.com/$repo.git $Z4H_DIR/$repo || return
      else
        print -ru2 -- ${(%):-"%F{3}z4h%f: downloading %B${repo//\%/%%}%b"}
        zmodload -F zsh/files b:zf_mkdir b:zf_rm b:zf_mv || return
        zf_mkdir -p -- $Z4H_DIR/${repo:h}
        if (( $+commands[curl] )); then
          curl -fsSL -- https://github.com/$repo/archive/master.tar.gz || return
        elif (( $+commands[wget] )); then
          wget -O- -- https://github.com/$repo/archive/master.tar.gz || return
        else
          print -ru2 -- "%F{3}z4h%f: please install %F{2}git%f, %F{2}curl%f or %F{2}wget%f"
          return 1
        fi | tar -C $Z4H_DIR/${repo:h} -xz || return
        zf_rm -rf -- $Z4H_DIR/$repo || return
        zf_mv -- $Z4H_DIR/$repo-master $Z4H_DIR/$repo || return
      fi
    done

    # Download fzf binary.
    if [[ ! -e $Z4H_DIR/junegunn/fzf/bin/fzf || $update == 1 ]]; then
      print -ru2 -- ${(%):-"%F{3}z4h%f: fetching %F{2}fzf%f binary"}
      ( cd $Z4H_DIR/junegunn/fzf && >&2 BASH_SOURCE=. exec -a sh $Z4H_ZSH install --bin ) || return
    fi

    if (( _z4h_initialized )); then
      print -ru2 -- ${(%):-"%F{3}z4h%f: restarting zsh"}
      exec -- $Z4H_ZSH
    else
      typeset -gri _z4h_initialized=1
    fi
  } always {
    (( $? )) || return
    local retry
    (( _z4h_initialized )) || retry="; type %F{2}%Uexec%u zsh%f to retry"
    print -rlu2 -- '' ${(%):-"%F{3}z4h%f: %F{1}failed to pull dependencies%f$retry"}
  }
}

z4h init || return

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# When a command is running, display it in the terminal title.
function _z4h-set-term-title-preexec() {
  emulate -L zsh
  print -rn -- $'\e]0;'${(V)1}$'\a' >$TTY
}
# When no command is running, display the current directory in the terminal title.
function _z4h-set-term-title-precmd() {
  emulate -L zsh
  print -rn -- $'\e]0;'${(V%):-"%~"}$'\a' >$TTY
}
autoload -Uz add-zsh-hook
add-zsh-hook preexec _z4h-set-term-title-preexec
add-zsh-hook precmd _z4h-set-term-title-precmd
_z4h-set-term-title-precmd

# If the current locale isn't UTF-8, change it to an UTF-8 one.
# Try in order: C.UTF-8, en_US.UTF-8, the first UTF-8 locale in lexicographical order.
() {
  emulate -L zsh -o extended_glob
  zmodload zsh/langinfo
  [[ $langinfo[CODESET] == (utf|UTF)(-|)8 ]] && return
  (( $+commands[locale] )) || return
  local loc=(${(@M)$(locale -a):#*.(utf|UTF)(-|)8})
  (( $#loc )) || return
  export LC_ALL=${loc[(r)(#i)C.UTF(-|)8]:-${loc[(r)(#i)en_US.UTF(-|)8]:-$loc[1]}}
}

# Enable command_not_found_handler if possible.
if (( $+functions[command_not_found_handler] )); then
  # already installed
elif [[ -e /etc/zsh_command_not_found ]]; then
  source /etc/zsh_command_not_found
elif [[ -e /usr/share/doc/pkgfile/command-not-found.zsh ]]; then
  source /usr/share/doc/pkgfile/command-not-found.zsh
elif [[ -x /usr/libexec/pk-command-not-found && -S /var/run/dbus/system_bus_socket ]]; then
  command_not_found_handler() { /usr/libexec/pk-command-not-found "$@" }
elif [[ -x /data/data/com.termux/files/usr/libexec/termux/command-not-found ]]; then
  command_not_found_handler() { /data/data/com.termux/files/usr/libexec/termux/command-not-found "$@" }
elif [[ -x /run/current-system/sw/bin/command-not-found ]]; then
  command_not_found_handler() { /run/current-system/sw/bin/command-not-found "$@" }
elif (( $+commands[brew] )); then
  () {
    emulate -L zsh -o extended_glob
    [[ -n $TTY && ( -n $CONTINUOUS_INTEGRATION || -z $MC_SID ) ]] || return
    local repo
    repo="$(brew --repository 2>/dev/null)" || return
    [[ -n $repo/Library/Taps/*/*/cmd/brew-command-not-found-init(|.rb)(#q.N) ]] || return
    autoload -Uz is-at-least
    function command_not_found_handler() {
      emulate -L zsh
      local msg
      if msg="$(brew which-formula --explain $1 2>/dev/null)" && [[ -n $msg ]]; then
        print -ru2 -- $msg
      elif is-at-least 5.3; then
        print -ru2 -- "zsh: command not found: $1"
      fi
      return 127
    }
  }
fi

# Usage: zssh [ssh-options] [user@]hostname
#
# This is a replacement for interactive `ssh [ssh-options] [user@]hostname`
# that fires up Zsh on the remote machine with your local configs. The remote
# machine must have login shell compatible with the Bourne shell (sh, bash,
# zsh, ash, dash, etc.) and internet connection. Nothing else is required.
#
# Here's what zssh does:
#
#   1. Archives Zsh config files (.zshrc and .p10k.zsh) on the local machine
#      and sends them to the remote machine. Local zsh history does NOT get
#      sent over.
#   2. Extracts these files to ~/.cache/zsh4humans.ssh/.dotfiles on the remote
#      machine and points ZDOTDIR to this directory to instruct Zsh to read
#      configuration files from it.
#   3. If there is no Zsh on the remote machine, zssh installs the latest
#      version to `~/.zsh-bin`.
#   4. Sets Z4H_SSH environment variable to '1'. You can use it throughout
#      zshrc to perform various initialization steps conditionally, depending
#      on whether zshrc is being sourced on your local or remote machine.
#
# The first login to a remote machine may take some time. After that it's as
# fast as normal ssh.
#
# Command history persists on the remote machine but Zsh config files (.zshrc
# and .p10k.zsh) get deleted when SSH connection terminates.
function zssh() {
  emulate -L zsh -o pipefail -o extended_glob

  # Copy these files and directories (relative to $ZDOTDIR, which defaults to
  # $HOME) from local machine to remote. Silently skip files that don't exist.
  local local_files=(.zshrc .p10k.zsh)

  # If there is no zsh on the remote machine, install this.
  local zsh_url='https://raw.githubusercontent.com/romkatv/zsh-bin/master/install'

  if (( ARGC == 0 )); then
    print -ru2 -- 'usage: ssh.zsh [ssh-options] [user@]hostname'
    return 1
  fi

  # Tar, compress and base64-encode the subset of $local_files that actually exist.
  local dump
  dump=$(cd -- ${ZDOTDIR:-~} && tar -czhT <(print -rl -- $^local_files(N)) | base64) || return

  ssh -t "$@" '
    set -ue

    export Z4H_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"/zsh4humans.ssh
    export ZDOTDIR="$Z4H_DIR"/.dotfiles
    export HISTFILE="$Z4H_DIR"/.zsh_history
    export Z4H_SSH=1

    rm -rf -- "$ZDOTDIR"
    mkdir -p -- "$Z4H_DIR" "$ZDOTDIR"
    touch -- "$HISTFILE"
    chmod 700 -- "$Z4H_DIR" "$ZDOTDIR"
    chmod 600 -- "$HISTFILE"

    # Delete dotfiles when SSH connetion terminates. Keep Zsh plugins and history.
    trap '\''rm -rf -- "$ZDOTDIR"'\'' INT QUIT TERM EXIT ILL PIPE HUP

    ( cd -- "$ZDOTDIR" && printf "%s" '${(q)dump//$'\n'}' | base64 -d | tar -xz )

    # If there is no local Zsh, install the latest version to ~/.zsh-bin.
    if ! command -v zsh >/dev/null 2>&1; then
      if [ ! -d ~/.zsh-bin ]; then
        if command -v curl >/dev/null 2>&1; then
          curl -fsSL -- '${(q)zsh_url}' | sh
        else
          wget -O- -- '${(q)zsh_url}' | sh
        fi
        [ -d ~/.zsh-bin ]
      fi
      export PATH="$PATH:$HOME/.zsh-bin/bin"
    fi

    # Ignore LANG and LC_* variables that may have been sent over. The remote machine
    # may not have the requested locale installed. Let zshrc figure out which locale to use.
    LC_ALL=C zsh -il'
}

function md() {
  [[ $# == 1 ]] && mkdir -p -- "$1" && cd -- "$1"
}

# The same as up-line-or-beginning-search but for local history.
function z4h-up-line-or-beginning-search-local() {
  emulate -L zsh
  local last=$LASTWIDGET
  zle .set-local-history 1
  () { local -h LASTWIDGET=$last; up-line-or-beginning-search "$@" } "$@"
  zle .set-local-history 0
}

# The same as down-line-or-beginning-search but for local history.
function z4h-down-line-or-beginning-search-local() {
  emulate -L zsh
  local last=$LASTWIDGET
  zle .set-local-history 1
  () { local -h LASTWIDGET=$last; down-line-or-beginning-search "$@" } "$@"
  zle .set-local-history 0
}

function z4h-beginning-of-buffer() { CURSOR=0 }
function z4h-end-of-buffer() { CURSOR=$(($#BUFFER  + 1)) }
function z4h-expand() { zle _expand_alias || zle .expand-word || true }
function z4h-run-help() { zle run-help || true }

zmodload zsh/terminfo
if (( $+terminfo[rmam] && $+terminfo[smam] )); then
  function z4h-expand-or-complete-with-dots() {
    # Show '...' while completing. No `emulate -L zsh` to pick up dotglob if it's set.
    print -rn -- ${terminfo[rmam]}${(%):-"%F{red}...%f"}${terminfo[smam]}
    zle fzf-tab-complete
  }
else
  function z4h-expand-or-complete-with-dots() { zle fzf-tab-complete }
fi

# fzf-history-widget with duplicate removal, preview and syntax highlighting (requires `bat`).
function z4h-fzf-history-widget() {
  emulate -L zsh -o pipefail
  local preview='printf "%s" {}'
  (( $+commands[bat] )) && preview+=' | bat -l bash --color always -pp'
  local cmd
  cmd="$(print -rNC1 -- "${(@u)history}" |
    fzf --read0 --no-multi --tiebreak=index --cycle --height=80% \
      --preview-window=down:40%:wrap --preview=$preview          \
      --bind '?:toggle-preview,ctrl-h:backward-kill-word' --query=$LBUFFER)"
  local -i ret=$?
  if [[ $ret == 0 && -n "$cmd" ]]; then
    zle .vi-fetch-history -n $(($#history - ${${history[@]}[(ie)$cmd]} + 1))
  fi
  zle .reset-prompt
  return ret
}

# Widgets for changing current working directory.
function z4h-redraw-prompt() {
  emulate -L zsh
  local f
  for f in chpwd $chpwd_functions precmd $precmd_functions; do
    (( $+functions[$f] )) && $f &>/dev/null
  done
  zle .reset-prompt
  zle -R
}
function z4h-cd-rotate() {
  emulate -L zsh
  while (( $#dirstack )) && ! pushd -q $1 &>/dev/null; do
    popd -q $1
  done
  if (( $#dirstack )); then
    z4h-redraw-prompt
  fi
}
function z4h-cd-back() { z4h-cd-rotate +1 }
function z4h-cd-forward() { z4h-cd-rotate -0 }
function z4h-cd-up() { cd .. && z4h-redraw-prompt }

autoload -Uz up-line-or-beginning-search down-line-or-beginning-search run-help
(( $+aliases[run-help] )) && unalias run-help  # make alt-h binding more useful

zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
zle -N z4h-expand
zle -N z4h-beginning-of-buffer
zle -N z4h-end-of-buffer
zle -N z4h-expand-or-complete-with-dots
zle -N z4h-up-line-or-beginning-search-local
zle -N z4h-down-line-or-beginning-search-local
zle -N z4h-cd-back
zle -N z4h-cd-forward
zle -N z4h-cd-up
zle -N z4h-fzf-history-widget
zle -N z4h-run-help

zmodload zsh/terminfo
if (( terminfo[colors] >= 256 )); then
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244'         # the default is hard to see
  typeset -A ZSH_HIGHLIGHT_STYLES=(comment fg=96)  # different colors for comments and suggestions
else
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=black,bold'  # the default is outside of 8 color range
fi

ZSH_HIGHLIGHT_MAXLENGTH=1024                       # don't colorize long command lines (slow)
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)         # main syntax highlighting plus matching brackets
ZSH_AUTOSUGGEST_MANUAL_REBIND=1                    # disable a very slow obscure feature

PROMPT_EOL_MARK='%K{red} %k'   # mark the missing \n at the end of a comand output with a red block
READNULLCMD=less               # use `less` instead of the default `more`
WORDCHARS=''                   # only alphanums make up words in word-based zle widgets
ZLE_REMOVE_SUFFIX_CHARS=''     # don't eat space when typing '|' after a tab completion
zle_highlight=('paste:none')   # disable highlighting of text pasted into the command line

: ${HISTFILE:=${ZDOTDIR:-~}/.zsh_history}  # save command history in this file
HISTSIZE=1000000000                        # infinite command history
SAVEHIST=1000000000                        # infinite command history

bindkey -e  # enable emacs keymap (sorry, vi users)

FZF_COMPLETION_TRIGGER=''                                # ctrl-t goes to fzf whenever possible
fzf_default_completion=z4h-expand-or-complete-with-dots  # ctrl-t falls back to tab
z4h source $Z4H_DIR/junegunn/fzf/shell/completion.zsh    # load fzf-completion
z4h source $Z4H_DIR/junegunn/fzf/shell/key-bindings.zsh  # load fzf-cd-widget
bindkey -r '^[c'                                         # remove unwanted binding

zstyle ':fzf-tab:*' prefix ''                    # remove '·'
zstyle ':fzf-tab:*' continuous-trigger alt-enter # alt-enter to accept and trigger next completion
bindkey '\t' expand-or-complete                  # fzf-tab reads it during initialization
z4h source $Z4H_DIR/Aloxaf/fzf-tab/fzf-tab.zsh   # load fzf-tab-complete

# If NumLock is off, translate keys to make them appear the same as with NumLock on.
bindkey -s '^[OM' '^M'  # enter
bindkey -s '^[Ok' '+'
bindkey -s '^[Om' '-'
bindkey -s '^[Oj' '*'
bindkey -s '^[Oo' '/'
bindkey -s '^[OX' '='

# If someone switches our terminal to application mode (smkx), translate keys to make
# them appear the same as in raw mode (rmkx).
bindkey -s '^[OH' '^[[H'  # home
bindkey -s '^[OF' '^[[F'  # end
bindkey -s '^[OA' '^[[A'  # up
bindkey -s '^[OB' '^[[B'  # down
bindkey -s '^[OD' '^[[D'  # left
bindkey -s '^[OC' '^[[C'  # right

# TTY sends different key codes. Translate them to regular.
bindkey -s '^[[1~' '^[[H'  # home
bindkey -s '^[[4~' '^[[F'  # end

# Do nothing on pageup and pagedown. Better than printing '~'.
bindkey -s '^[[5~' ''
bindkey -s '^[[6~' ''

bindkey '^[[D'    backward-char                           # left       move cursor one char backward
bindkey '^[[C'    forward-char                            # right      move cursor one char forward
bindkey '^[[A'    z4h-up-line-or-beginning-search-local   # up         prev command in local history
bindkey '^[[B'    z4h-down-line-or-beginning-search-local # down       next command in local history
bindkey '^[[H'    beginning-of-line                       # home       go to the beginning of line
bindkey '^[[F'    end-of-line                             # end        go to the end of line
bindkey '^?'      backward-delete-char                    # bs         delete one char backward
bindkey '^[[3~'   delete-char                             # delete     delete one char forward
bindkey '^[[1;5C' forward-word                            # ctrl+right go forward one word
bindkey '^[[1;5D' backward-word                           # ctrl+left  go backward one word
bindkey '^H'      backward-kill-word                      # ctrl+bs    delete previous word
bindkey '^[[3;5~' kill-word                               # ctrl+del   delete next word
bindkey '^K'      kill-line                               # ctrl+k     delete line after cursor
bindkey '^J'      backward-kill-line                      # ctrl+j     delete line before cursor
bindkey '^N'      kill-buffer                             # ctrl+n     delete all lines
bindkey '^_'      undo                                    # ctrl+/     undo
bindkey '^\'      redo                                    # ctrl+\     redo
bindkey '^[[1;5A' up-line-or-beginning-search             # ctrl+up    prev cmd in global history
bindkey '^[[1;5B' down-line-or-beginning-search           # ctrl+down  next cmd in global history
bindkey '^ '      z4h-expand                              # ctrl+space expand alias/glob/parameter
bindkey '^[[1;3D' z4h-cd-back                             # alt+left   cd into the prev directory
bindkey '^[[1;3C' z4h-cd-forward                          # alt+right  cd into the next directory
bindkey '^[[1;3A' z4h-cd-up                               # alt+up     cd ..
bindkey '\t'      z4h-expand-or-complete-with-dots        # tab        fzf-tab completion
bindkey '^[[1;3B' fzf-cd-widget                           # alt+down   fzf cd
bindkey '^T'      fzf-completion                          # ctrl+t     fzf file completion
bindkey '^R'      z4h-fzf-history-widget                  # ctrl+r     fzf history
bindkey '^[h'     z4h-run-help                            # alt+h      help for the cmd at cursor
bindkey '^[H'     z4h-run-help                            # alt+H      help for the cmd at cursor
bindkey '^[[1;5H' z4h-beginning-of-buffer                 # ctrl-home  go to the beginning of buffer
bindkey '^[[1;5F' z4h-end-of-buffer                       # ctrl-end   go to the end of buffer

# Tell zsh-autosuggestions how to handle different widgets.
typeset -g ZSH_AUTOSUGGEST_EXECUTE_WIDGETS=()
typeset -g ZSH_AUTOSUGGEST_ACCEPT_WIDGETS=(
  end-of-line
  vi-end-of-line
  vi-add-eol
  z4h-end-of-buffer
  # Uncomment these two lines if you want right arrow to accept the whole autosuggestion.
  # forward-char
  # vi-forward-char
)
typeset -g ZSH_AUTOSUGGEST_CLEAR_WIDGETS=(
  accept-line
  up-line-or-beginning-search
  down-line-or-beginning-search
  up-line-or-beginning-search-local
  down-line-or-beginning-search-local
  z4h-fzf-history-widget
)
typeset -g ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS=(
  forward-word
  emacs-forward-word
  vi-forward-word
  vi-forward-word-end
  vi-forward-blank-word
  vi-forward-blank-word-end
  vi-find-next-char
  vi-find-next-char-skip
  forward-char
  vi-forward-char
)
typeset -g ZSH_AUTOSUGGEST_IGNORE_WIDGETS=(
  orig-\*
  beep
  run-help
  set-local-history
  which-command
  yank
  yank-pop
  zle-\*
  redisplay
  fzf-tab-complete
)

# Use lesspipe if available. It allows you to use less on binary files (zip archives, etc.).
if (( $#commands[(i)lesspipe(|.sh)] )); then
  export LESSOPEN="| /usr/bin/env $commands[(i)lesspipe(|.sh)] %s 2>&-"
fi

# This affects every invocation of `less`.
#
#   -i   case-insensitive search unless search string contains uppercase letters
#   -R   color
#   -F   exit if there is less than one page of content
#   -X   keep content on screen after exit
#   -M   show more info at the bottom prompt line
#   -x4  tabs are 4 instead of 8
export LESS=-iRFXMx4

# Export variables.
export PAGER=less

# LS_COLORS is used by GNU ls and Zsh completions. LSCOLORS is used by BSD ls.
export LS_COLORS="rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:\
or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:"
export LSCOLORS="ExGxFxdaCxDaDahbadacec"

typeset -gaU cdpath fpath mailpath path
fpath+=($Z4H_DIR/zsh-users/zsh-completions/src)

# Extend PATH.
path+=($Z4H_DIR/junegunn/fzf/bin ${Z4H_ZSH:h})

# Initialize completions.
autoload -Uz compinit
compinit -d ${XDG_CACHE_HOME:-~/.cache}/.zcompdump-$ZSH_VERSION

compdef _directories md
(( $+_comps[ssh] )) && compdef $_comps[ssh] zssh=ssh

# Configure completions.
zstyle ':completion:*'                  matcher-list    'm:{a-zA-Z}={A-Za-z}' 'l:|=* r:|=*'
zstyle ':completion:*'                  completer       _complete
zstyle ':completion:*:*:-subscript-:*'  tag-order       indexes parameters
zstyle ':completion:*'                  squeeze-slashes true
zstyle '*'                              single-ignored  show
zstyle ':completion:*:(rm|kill|diff):*' ignore-line     other
zstyle ':completion:*:rm:*'             file-patterns   '*:all-files'
zstyle ':completion::complete:*'        use-cache       on
zstyle ':completion::complete:*'        cache-path      ${XDG_CACHE_HOME:-$HOME/.cache}/zcompcache-$ZSH_VERSION
zstyle ':completion:*'                  list-colors     ${(s.:.)LS_COLORS}

# Make it possible to use completion specifications and functions written for bash.
autoload -Uz bashcompinit
bashcompinit

# Enable iTerm2 shell integration if available.
if [[ $TERM_PROGRAM == iTerm.app && -e ~/.iterm2_shell_integration.zsh ]]; then
  z4h source ~/.iterm2_shell_integration.zsh
fi

# Initialize prompt. Type `p10k configure` or edit .p10k.zsh to customize it.
[[ -e ${ZDOTDIR:-~}/.p10k.zsh ]] && z4h source ${ZDOTDIR:-~}/.p10k.zsh
z4h source $Z4H_DIR/romkatv/powerlevel10k/powerlevel10k.zsh-theme

z4h source $Z4H_DIR/zsh-users/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh
# zsh-syntax-highlighting must be loaded after all widgets have been defined.
z4h source $Z4H_DIR/zsh-users/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh

autoload -Uz zmv # enable zmv command (type `zmv` for usage)

# Aliases.
if (( $+commands[dircolors] )); then  # proxy for GNU coreutils vs BSD
  # Don't define aliases for commands that point to busybox.
  [[ ${${:-diff}:c:A:t} == busybox* ]] || alias diff='diff --color=auto'
  [[ ${${:-ls}:c:A:t}   == busybox* ]] || alias ls='ls --color=auto'
else
  [[ ${${:-ls}:c:A:t}   == busybox* ]] || alias ls='ls -G'
fi
[[ ${${:-grep}:c:A:t}   == busybox* ]] || alias grep='grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn}'
[[ ${${:-tree}:c:A:t}   == busybox* ]] || alias tree='tree -aC -I .git'

# Enable decent options. See http://zsh.sourceforge.net/Doc/Release/Options.html.
emulate zsh                    # restore default options just in case something messed them up
setopt ALWAYS_TO_END           # full completions move cursor to the end
setopt AUTO_CD                 # `dirname` is equivalent to `cd dirname`
setopt AUTO_PARAM_SLASH        # if completed parameter is a directory, add a trailing slash
setopt AUTO_PUSHD              # `cd` pushes directories to the directory stack
setopt COMPLETE_IN_WORD        # complete from the cursor rather than from the end of the word
setopt EXTENDED_GLOB           # more powerful globbing
setopt EXTENDED_HISTORY        # write timestamps to history
setopt HIST_EXPIRE_DUPS_FIRST  # if history needs to be trimmed, evict dups first
setopt HIST_FIND_NO_DUPS       # don't show dups when searching history
setopt HIST_IGNORE_DUPS        # don't add consecutive dups to history
setopt HIST_IGNORE_SPACE       # don't add commands starting with space to history
setopt HIST_VERIFY             # if a command triggers history expansion, show it instead of running
setopt INTERACTIVE_COMMENTS    # allow comments in command line
setopt MULTIOS                 # allow multiple redirections for the same fd
setopt NO_BG_NICE              # don't nice background jobs
setopt NO_FLOW_CONTROL         # disable start/stop characters in shell editor
setopt PATH_DIRS               # perform path search even on command names with slashes
setopt SHARE_HISTORY           # write and import history on every command
setopt C_BASES                 # print hex/oct numbers as 0xFF/077 instead of 16#FF/8#77
