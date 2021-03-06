# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# If not running interactively, don't do anything
case $- in
*i*) ;;
*) return ;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
xterm-color | *-256color) color_prompt=yes ;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
  if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    # We have color support; assume it's compliant with Ecma-48
    # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
    # a case would tend to support setf rather than setaf.)
    color_prompt=yes
  else
    color_prompt=
  fi
fi

if [ "$color_prompt" = yes ]; then
  PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "
else
  PS1='\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm* | rxvt*)
  PS1="\[\e]0;\u@\h: \w\a\]$PS1"
  ;;
*) ;;

esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
  test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
  alias ls='ls --color=auto'
  #alias dir='dir --color=auto'
  #alias vdir='vdir --color=auto'

  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# Alias's for multiple directory listing commands
alias la='ls -Alh'                # show hidden files
alias ls='ls -aFh --color=always' # add colors and file type extensions
alias lx='ls -lXBh'               # sort by extension
alias lk='ls -lSrh'               # sort by size
alias lc='ls -lcrh'               # sort by change time
alias lu='ls -lurh'               # sort by access time
alias lr='ls -lRh'                # recursive ls
alias lt='ls -ltrh'               # sort by date
alias lm='ls -alh |more'          # pipe through 'more'
alias lw='ls -xAh'                # wide listing format
alias ll='ls -Fls'                # long listing format
alias labc='ls -lap'              #alphabetical sort
alias lf="ls -l | egrep -v '^d'"  # files only
alias ldir="ls -l | egrep '^d'"   # directories only

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
  . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  elif [ -f ~/.bash_completion ]; then
    . ~/.bash_completion
  fi
fi

if [ -e /usr/bin/aws_completer ]; then
  complete -C '/usr/bin/aws_completer' aws
fi

# if the command-not-found package is installed, use it
if [ -x /usr/lib/command-not-found -o -x /usr/share/command-not-found/command-not-found ]; then
  function command_not_found_handle() {
    # check because c-n-f could've been removed in the meantime
    if [ -x /usr/lib/command-not-found ]; then
      /usr/lib/command-not-found -- "$1"
      return $?
    elif [ -x /usr/share/command-not-found/command-not-found ]; then
      /usr/share/command-not-found/command-not-found -- "$1"
      return $?
    else
      printf "%s: command not found\n" "$1" >&2
      return 127
    fi
  }
fi

if [ -e "/apollo/env/SDETools/bin" ]; then
  export PATH="/apollo/env/SDETools/bin:$PATH"
fi

# Alias to show the date
alias da='date "+%Y-%m-%d %A %T %Z"'

# Alias's to modified commands
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -iv'
alias mkdir='mkdir -p'
alias ps='ps auxf'
alias ping='ping -c 10'
alias less='less -R'
alias cls='clear'
alias apt-get='sudo apt-get'
alias multitail='multitail --no-repeat -c'
alias freshclam='sudo freshclam'
alias vi='vim'
alias svi='sudo vi'
alias vis='vim "+set si"'

# Change directory aliases
alias home='cd ~'
alias cd..='cd ..'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias mark='pwd > ~/.sd'
alias port='cd $(cat ~/.sd)'

# Remove a directory and all files
alias rmd='/bin/rm  --recursive --force --verbose '

# Alias chmod commands
alias mx='chmod a+x'
alias 000='chmod -R 000'
alias 644='chmod -R 644'
alias 666='chmod -R 666'
alias 755='chmod -R 755'
alias 777='chmod -R 777'

# Search command line history
alias h="history | grep "

# Search running processes
alias p="ps aux | grep "
alias topcpu="/bin/ps -eo pcpu,pid,user,args | sort -k 1 -r | head -10"

# Search files in the current folder
alias f="find . | grep "

# Count all files (recursively) in the current folder
alias countfiles="for t in files links directories; do echo \`find . -type \${t:0:1} | wc -l\` \$t; done 2> /dev/null"

# To see if a command is aliased, a file, or a built-in command
alias checkcommand="type -t"

# Show current network connections to the server
alias ipview="netstat -anpl | grep :80 | awk {'print \$5'} | cut -d\":\" -f1 | sort | uniq -c | sort -n | sed -e 's/^ *//' -e 's/ *\$//'"

# Show open ports
alias openports='netstat -nape --inet'

# Alias's for safe and forced reboots
alias rebootsafe='sudo shutdown -r now'
alias rebootforce='sudo shutdown -r -n now'

# Alias's to show disk space and space used in a folder
alias diskspace="du -S | sort -n -r |more"
alias folders='du -h --max-depth=1'
alias folderssort='find . -maxdepth 1 -type d -print0 | xargs -0 du -sk | sort -rn'
alias tree='tree -CAhF --dirsfirst'
alias treed='tree -CAFd'
alias mountedinfo='df -hT'

# Alias's for archives
alias mktar='tar -cvf'
alias mkbz2='tar -cvjf'
alias mkgz='tar -cvzf'
alias untar='tar -xvf'
alias unbz2='tar -xvjf'
alias ungz='tar -xvzf'

# Show all logs in /var/log
alias logs="sudo find /var/log -type f -exec file {} \; | grep 'text' | cut -d' ' -f1 | sed -e's/:$//g' | grep -v '[0-9]$' | xargs tail -f"

# SHA1
alias sha1='openssl sha1'

# Brazil CLI
alias bb='brazil-build'
alias bbr='brazil-build release'
alias bbenv='brazil-build release && brazil-bootstrap --environmentType test-runtime'
alias bre='brazil-runtime-exec'
alias bbra='brazil-recursive-cmd-parallel --allPackages brazil-build release'

# RDE
alias rdeb='rde wflow run -s build'

# Vim
alias vim='/apollo/env/envImprovement/bin/vim'

#######################################################
# SPECIAL FUNCTIONS
#######################################################

# Use the best version of pico installed
edit() {
  if [ "$(type -t jpico)" = "file" ]; then
    # Use JOE text editor http://joe-editor.sourceforge.net/
    jpico -nonotice -linums -nobackups "$@"
  elif [ "$(type -t nano)" = "file" ]; then
    nano -c "$@"
  elif [ "$(type -t pico)" = "file" ]; then
    pico "$@"
  else
    vim "$@"
  fi
}
sedit() {
  if [ "$(type -t jpico)" = "file" ]; then
    # Use JOE text editor http://joe-editor.sourceforge.net/
    sudo jpico -nonotice -linums -nobackups "$@"
  elif [ "$(type -t nano)" = "file" ]; then
    sudo nano -c "$@"
  elif [ "$(type -t pico)" = "file" ]; then
    sudo pico "$@"
  else
    sudo vim "$@"
  fi
}

# Extracts any archive(s) (if unp isn't installed)
extract() {
  for archive in $*; do
    if [ -f $archive ]; then
      case $archive in
      *.tar.bz2) tar xvjf $archive ;;
      *.tar.gz) tar xvzf $archive ;;
      *.bz2) bunzip2 $archive ;;
      *.rar) rar x $archive ;;
      *.gz) gunzip $archive ;;
      *.tar) tar xvf $archive ;;
      *.tbz2) tar xvjf $archive ;;
      *.tgz) tar xvzf $archive ;;
      *.zip) unzip $archive ;;
      *.Z) uncompress $archive ;;
      *.7z) 7z x $archive ;;
      *) echo "don't know how to extract '$archive'..." ;;
      esac
    else
      echo "'$archive' is not a valid file!"
    fi
  done
}

# Searches for text in all files in the current folder
ftext() {
  # -i case-insensitive
  # -I ignore binary files
  # -H causes filename to be printed
  # -r recursive search
  # -n causes line number to be printed
  # optional: -F treat search term as a literal, not a regular expression
  # optional: -l only print filenames and not the matching lines ex. grep -irl "$1" *
  grep -iIHrn --color=always "$1" . | less -r
}

# Copy file with a progress bar
cpp() {
  set -e
  strace -q -ewrite cp -- "${1}" "${2}" 2>&1 |
    awk '{
    count += $NF
    if (count % 10 == 0) {
        percent = count / total_size * 100
        printf "%3d%% [", percent
        for (i=0;i<=percent;i++)
            printf "="
            printf ">"
            for (i=percent;i<100;i++)
                printf " "
                printf "]\r"
            }
        }
    END { print "" }' total_size=$(stat -c '%s' "${1}") count=0
}

# Copy and go to the directory
cpg() {
  if [ -d "$2" ]; then
    cp $1 $2 && cd $2
  else
    cp $1 $2
  fi
}

# Move and go to the directory
mvg() {
  if [ -d "$2" ]; then
    mv $1 $2 && cd $2
  else
    mv $1 $2
  fi
}

# Create and go to the directory
mkdirg() {
  mkdir -p $1
  cd $1
}

# Goes up a specified number of directories  (i.e. up 4)
up() {
  local d=""
  limit=$1
  for ((i = 1; i <= limit; i++)); do
    d=$d/..
  done
  d=$(echo $d | sed 's/^\///')
  if [ -z "$d" ]; then
    d=..
  fi
  cd $d
}

# Automatically do an ls after each cd
cd() {
  if [ -n "$1" ]; then
    builtin cd "$@" && ls
  else
    builtin cd ~ && ls
  fi
}

# Returns the last 2 fields of the working directory
pwdtail() {
  pwd | awk -F/ '{nlast = NF -1;print $nlast"/"$NF}'
}

# Show the current distribution
distribution() {
  local dtype
  # Assume unknown
  dtype="unknown"

  # First test against Fedora / RHEL / CentOS / generic Redhat derivative
  if [ -r /etc/rc.d/init.d/functions ]; then
    source /etc/rc.d/init.d/functions
    [ zz$(type -t passed 2>/dev/null) == "zzfunction" ] && dtype="redhat"

  # Then test against SUSE (must be after Redhat,
  # I've seen rc.status on Ubuntu I think? TODO: Recheck that)
  elif [ -r /etc/rc.status ]; then
    source /etc/rc.status
    [ zz$(type -t rc_reset 2>/dev/null) == "zzfunction" ] && dtype="suse"

  # Then test against Debian, Ubuntu and friends
  elif [ -r /lib/lsb/init-functions ]; then
    source /lib/lsb/init-functions
    [ zz$(type -t log_begin_msg 2>/dev/null) == "zzfunction" ] && dtype="debian"

  # Then test against Gentoo
  elif [ -r /etc/init.d/functions.sh ]; then
    source /etc/init.d/functions.sh
    [ zz$(type -t ebegin 2>/dev/null) == "zzfunction" ] && dtype="gentoo"

  # For Mandriva we currently just test if /etc/mandriva-release exists
  # and isn't empty (TODO: Find a better way :)
  elif [ -s /etc/mandriva-release ]; then
    dtype="mandriva"

  # For Slackware we currently just test if /etc/slackware-version exists
  elif [ -s /etc/slackware-version ]; then
    dtype="slackware"

  fi
  echo $dtype
}

# Show the current version of the operating system
ver() {
  local dtype
  dtype=$(distribution)

  if [ $dtype == "redhat" ]; then
    if [ -s /etc/redhat-release ]; then
      cat /etc/redhat-release && uname -a
    else
      cat /etc/issue && uname -a
    fi
  elif [ $dtype == "suse" ]; then
    cat /etc/SuSE-release
  elif [ $dtype == "debian" ]; then
    lsb_release -a
    # sudo cat /etc/issue && sudo cat /etc/issue.net && sudo cat /etc/lsb_release && sudo cat /etc/os-release # Linux Mint option 2
  elif [ $dtype == "gentoo" ]; then
    cat /etc/gentoo-release
  elif [ $dtype == "mandriva" ]; then
    cat /etc/mandriva-release
  elif [ $dtype == "slackware" ]; then
    cat /etc/slackware-version
  else
    if [ -s /etc/issue ]; then
      cat /etc/issue
    else
      echo "Error: Unknown distribution"
      exit 1
    fi
  fi
}

# Automatically install the needed support files for this .bashrc file
install_bashrc_support() {
  local dtype
  dtype=$(distribution)

  if [ $dtype == "redhat" ]; then
    sudo yum install multitail tree joe
  elif [ $dtype == "suse" ]; then
    sudo zypper install multitail
    sudo zypper install tree
    sudo zypper install joe
  elif [ $dtype == "debian" ]; then
    sudo apt-get install multitail tree joe
  elif [ $dtype == "gentoo" ]; then
    sudo emerge multitail
    sudo emerge tree
    sudo emerge joe
  elif [ $dtype == "mandriva" ]; then
    sudo urpmi multitail
    sudo urpmi tree
    sudo urpmi joe
  elif [ $dtype == "slackware" ]; then
    echo "No install support for Slackware"
  else
    echo "Unknown distribution"
  fi
}

# Show current network information
netinfo() {
  echo "--------------- Network Information ---------------"
  /sbin/ifconfig | awk /'inet addr/ {print $2}'
  echo ""
  /sbin/ifconfig | awk /'Bcast/ {print $3}'
  echo ""
  /sbin/ifconfig | awk /'inet addr/ {print $4}'

  /sbin/ifconfig | awk /'HWaddr/ {print $4,$5}'
  echo "---------------------------------------------------"
}

# IP address lookup
alias whatismyip="whatsmyip"
function whatsmyip() {
  # Dumps a list of all IP addresses for every device
  # /sbin/ifconfig |grep -B1 "inet addr" |awk '{ if ( $1 == "inet" ) { print $2 } else if ( $2 == "Link" ) { printf "%s:" ,$1 } }' |awk -F: '{ print $1 ": " $3 }';

  # Internal IP Lookup
  echo -n "Internal IP: "
  /sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'

  # External IP Lookup
  echo -n "External IP: "
  wget http://smart-ip.net/myip -O - -q
}

# View Apache logs
apachelog() {
  if [ -f /etc/httpd/conf/httpd.conf ]; then
    cd /var/log/httpd && ls -xAh && multitail --no-repeat -c -s 2 /var/log/httpd/*_log
  else
    cd /var/log/apache2 && ls -xAh && multitail --no-repeat -c -s 2 /var/log/apache2/*.log
  fi
}

# Edit the Apache configuration
apacheconfig() {
  if [ -f /etc/httpd/conf/httpd.conf ]; then
    sedit /etc/httpd/conf/httpd.conf
  elif [ -f /etc/apache2/apache2.conf ]; then
    sedit /etc/apache2/apache2.conf
  else
    echo "Error: Apache config file could not be found."
    echo "Searching for possible locations:"
    sudo updatedb && locate httpd.conf && locate apache2.conf
  fi
}

# Edit the PHP configuration file
phpconfig() {
  if [ -f /etc/php.ini ]; then
    sedit /etc/php.ini
  elif [ -f /etc/php/php.ini ]; then
    sedit /etc/php/php.ini
  elif [ -f /etc/php5/php.ini ]; then
    sedit /etc/php5/php.ini
  elif [ -f /usr/bin/php5/bin/php.ini ]; then
    sedit /usr/bin/php5/bin/php.ini
  elif [ -f /etc/php5/apache2/php.ini ]; then
    sedit /etc/php5/apache2/php.ini
  else
    echo "Error: php.ini file could not be found."
    echo "Searching for possible locations:"
    sudo updatedb && locate php.ini
  fi
}

# Edit the MySQL configuration file
mysqlconfig() {
  if [ -f /etc/my.cnf ]; then
    sedit /etc/my.cnf
  elif [ -f /etc/mysql/my.cnf ]; then
    sedit /etc/mysql/my.cnf
  elif [ -f /usr/local/etc/my.cnf ]; then
    sedit /usr/local/etc/my.cnf
  elif [ -f /usr/bin/mysql/my.cnf ]; then
    sedit /usr/bin/mysql/my.cnf
  elif [ -f ~/my.cnf ]; then
    sedit ~/my.cnf
  elif [ -f ~/.my.cnf ]; then
    sedit ~/.my.cnf
  else
    echo "Error: my.cnf file could not be found."
    echo "Searching for possible locations:"
    sudo updatedb && locate my.cnf
  fi
}

# For some reason, rot13 pops up everywhere
rot13() {
  if [ $# -eq 0 ]; then
    tr '[a-m][n-z][A-M][N-Z]' '[n-z][a-m][N-Z][A-M]'
  else
    echo $* | tr '[a-m][n-z][A-M][N-Z]' '[n-z][a-m][N-Z][A-M]'
  fi
}

# Trim leading and trailing spaces (for scripts)
trim() {
  local var=$@
  var="${var#"${var%%[![:space:]]*}"}" # remove leading whitespace characters
  var="${var%"${var##*[![:space:]]}"}" # remove trailing whitespace characters
  echo -n "$var"
}

# Recursively execute provided command in sub directories
recursive() {
  for dir in */; do
    pushd $dir >/dev/null
    echo -e "\033[0;31mCurrent Directory: $PWD\033[0m"
    eval $@
    popd >/dev/null
  done
}

# Google Java Formatter
google-recursive-format() {
	find $1 -name '*.java' | xargs java -jar $HOME/google-java-format-1.9-all-deps.jar -r $2
}

# See http://w?User:Daviesza/KinitReduction for more information
# Request weekly expiration with 30 day renewal, although the
# server only gives out 10 hour expiration with 7 day renewal.
kmonday() { kinit -f -l 7d -r 30d; }

# Brazil Graph
path_to() { brazil-graph paths-from-all-targets -d $2 -g all -s $1; }

# Cloud workplace
CLOUD_WORKPLACE="$HOME/cloud/workplace"

mnt_cloud() {
  # create local folder to mount into
  mkdir -p $CLOUD_WORKPLACE

  # now mount your SSH File System
  sshfs -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 $USER@$USER.aka.corp.amazon.com:/workplace/$USER $CLOUD_WORKPLACE
}

umnt_cloud() {
  fusermount -u -z $CLOUD_WORKPLACE
  rmd $CLOUD_WORKPLACE
}

# Refresh AWS credentials
export DEFAULT_ROLE_ARN=arn:aws:iam::026671186639:role/Development
export DEFAULT_REGION=us-west-2
refresh_aws_credentials() {
  ROLE_ARN=$1
  REGION=$2
  if [ -z ${ROLE_ARN:+x} ]
  then
    ROLE_ARN=$DEFAULT_ROLE_ARN
  fi
  if [ -z ${REGION:+x} ]
  then
    REGION=$DEFAULT_REGION
  fi
  response=`curl -L -c ~/.midway/cookie -b ~/.midway/cookie -H "Accept: application/json" \
            https://iibs-midway.corp.amazon.com/GetAssumeRoleCredentials \
            --data-urlencode "duration=43200" \
            -G \
            --data-urlencode "roleARN=$ROLE_ARN"`
  echo $response | jq
  aws configure set aws_access_key_id `echo $response | jq -r '.accessKeyId'`
  aws configure set aws_secret_access_key `echo $response | jq -r '.secretAccessKey'`
  aws configure set aws_session_token `echo $response | jq -r '.sessionToken'`
  aws configure set region $REGION
}

#######################################################
# CUSTOM CONFIGURATION
#######################################################

export PATH=$HOME/.toolbox/bin:$PATH
export PATH=/apollo/env/envImprovement/bin:$PATH

export PERSONAL_AWS_ACCOUNT=026671186639
export DEV_DESKTOP_TLS_CERTIFICATE_ODIN_MATERIAL=com.amazon.certificates.lingnanl.aka.corp.amazon.com-STANDARD_SSL_SERVER_INTERNAL_ENDPOINT-RSA-Chain

# Use starship command prompt
eval "$(starship init bash)"
