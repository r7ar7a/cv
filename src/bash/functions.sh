#!/bin/bash

function echo_np {
  declare string_template newline result_template
  if [ "${ECHO_E-0}" == "0" ]; then
    string_template="%s"
  else
    string_template="%b"
  fi
  if [ "${ECHO_N-0}" == "0" ]; then
    newline="\n"
  else
    newline=""
  fi
  result_template="$(printn "$string_template " $#)"
  result_template="${result_template% }$newline"
  printf "$result_template" "$@"
}

function mount_sshfs_if_needed {
  if [ "$(df -P "$2")" == "$(df -P "$2/..")" ]; then
    command=(sshfs -o transform_symlinks -o idmap=user $1 $2)
    echo_np "${command[@]}"
    "${command[@]}"
  fi
}

parse_git_branch() {
  declare -f branch branch_string local_name remote_name
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'
}

parse_git_branch_plus() {
  declare branch branch_string local_name remote_name issue_num
  branch_string="$(parse_git_branch)"
  if [ -z "${branch_string}" ]; then
    return;
  fi
  for prefix in RAD DEV RM HHO; do
    if [ "$branch_string" != "${branch_string%$prefix-*}" ]; then
      issue_num="${branch_string#*$prefix-}"
      issue_num="${issue_num%%[![:digit:]]*}"
      branch_string="$prefix-$issue_num"
    fi
  done
  
  if [ "${#branch_string}" -gt 18 ]; then
    branch_string="${branch_string:0:15}..."
  else
    branch_string="${branch_string}"
  fi
  if [ "$1" == "color" ]; then 
    local_name="$(basename "$(git rev-parse --show-toplevel)")"
    remote_name="$(basename "$(git config --get remote.origin.url)")" || remote_name=""
    remote_name="${remote_name%.git}"
    if [ "$remote_name" != "$local_name" ]; then
      branch_string="\e[7m$branch_string\e[27m"
    fi
    branch_string="($branch_string)"
  fi
  echo -e "$branch_string"
}
function ps1_git_branch {
  declare branch_string
  branch_string="$(parse_git_branch_plus)"

  branch_string="($(echo -e "($branch_string)"))"

  # set the PS1 variable
  if [ "$PS1" == "${PS1%%parse_git_branch*}" ]; then
    left_side="${PS1%\\\$*}"
    right_side="${PS1##*\\\$}"
    export PS1="${left_side}\$(parse_git_branch_plus color)\$${right_side}"
  fi
}

function init_git_commit {
  echo "git commit -am $(escape_string "$(parse_git_branch)")"
}

function init_git_commit_radoop {
  declare orig rad_issue_num dev_issue_num
  echo "git commit -am $(escape_string "$(parse_git_branch_plus) ")"
}

function absolutize_no_link_following {
  relative_file_path="$1"
  relative_dir_path="$(dirname "$relative_file_path")"
  file_name="$(basename "$relative_file_path")"
  pushd "$relative_dir_path" > "/dev/null"
    absolute_dir_path="$(pwd)"
  popd > "/dev/null"
  absolute_file_path="$absolute_dir_path/$file_name"
  echo "$absolute_file_path"
}
function binding_absolutize_no_link_following {
  escape_string "$(absolutize_no_link_following "$1")"
}

function index_of {
  declare element 
  declare -i index=0
  for element in "${@:2}"; do
    if [ "$element" == "$1" ]; then
      echo $index
      return
    fi
    ((++index))
  done
  return 1
}

function contains_element {
  declare e
  for e in "${@:2}"; do
    [[ "$e" == "$1" ]] && return 0;
  done
  return 1
}

#declare -f escape_string escape_strings wrap_function 
function wrap_function {
  declare prefix declaration f_name
  prefix="$1"
  for f_name in "${@:2}"; do
    declaration='function '"$f_name"' { bash -ceu "$(declare -f '"$prefix$f_name"')"'\''; '"$prefix$f_name"\''" $(escape_strings "$@")"; }'
    eval "$declaration"
  done
}

function ensure_true { 
  declare trys_till_timeout sleep_time counter success
  command="$1"
  trys_till_timeout="$2"
  sleep_time="${3-1}"
  counter=0
  success=1
  echo 'Ensuring '"$command"
  while ! eval "$command"; do
    ((++counter))
    if [ "$counter" -ge "$trys_till_timeout" ]; then
      return 1
    fi
    echo -n "."
    sleep $sleep_time;
  done;
  echo 'OK!'
}

function ensure_true_silent { 
  declare command trys_till_timeout sleep_time counter success tmp_file
  command="$1"
  add_tmp_file tmp_file
  silenced_command="( $command ) &> $(escape_string "$tmp_file")"
  if ! ensure_true "$silenced_command" "${@:2}"; then
    echo "stdout + stderr:" >> /dev/stderr
    echo "===============" >> /dev/stderr
    cat "$tmp_file"
    echo "===============" >> /dev/stderr
    return 1
  fi
}

function my_reset {
  echo -e "\033c"
}

function find_element {
  declare i
  i=0
  for e in "${@:2}"; do
    if [ "$e" == "$1" ]; then
      echo i;
      return 0;
    fi
    ((++i))
  done
  return 1
}

function check_command {
  declare command_name
  for command_name in "$@"; do
    compgen -c "$command_name" | grep -xq "$command_name" || (echo "$command_name: command not found, but needed"; false )
  done
}

function is_port_free {
  declare port
  port="${1?'function is_port_free: port is not set(1. argument)!'}"
  ! (
    exec 6<>"/dev/tcp/localhost/$port" 
  ) >/dev/null 2>&1
  return "$?"
}

#declare -f diff_recursive do_on_each_output_line
function diff_recursive {
  declare dir1 dir2 find_options diff_command command
  dir1="$1"
  dir2="$2"
  shift 2
  find_options=("$@")
  exist_command='[ -e "$dir2/$file_name" ]'
  diff_command='diff "$dir1/$file_name" "$dir2/$file_name"'
  command='('"$exist_command"' || (echo "File $dir2/$file_name does not exist."; exit 2) || exit; '"$diff_command"' > /dev/null || eval echo "$diff_command")'
  do_on_each_output_line '(cd "$dir1" && find . \( -type f -or -type l \) "${find_options[@]--true}" )' "$command" file_name
}

#declare -f find_free_port is_port_free
function find_free_port {
  declare lowerPort upperPort port how_many
  declare -i how_many="${1-1}"
  read lowerPort upperPort < /proc/sys/net/ipv4/ip_local_port_range
  for (( port = lowerPort ; port <= upperPort ; port++ )); do
    if is_port_free "$port"; then
      echo "$port"
      ((--how_many))
      if [ "$how_many" -le 0 ]; then
        break
      fi
    fi
  done
  if [ "$port" -gt "$upperPort" ]; then
    return 1;
  fi
}

#declare -f add_trap escape_string
function add_trap {
  declare command signal signals orig_trap_command rtrim old_command new_command
  command="${1?More parameter needed}"
  signals=("${@:2}")
  for signal in "${signals[@]?More parameter needed}"; do
    orig_trap_command="$(trap -p "$signal")"
    if [ -z "$orig_trap_command" ]; then
      old_command="':'"
    else
      rtrim="${orig_trap_command% $signal}"
      if [ "$orig_trap_command" == "$rtrim" ]; then
        echo "Invalid signal name: $signal. Use whole terms for signals when calling add_trap function ('SIGINT', instead of 'INT', 'int' or '1'...)" >> /dev/stderr
        return 3
      fi
      old_command="${rtrim#trap -- }"
    fi
    eval new_command="$(escape_string "$command;")$old_command"
    trap -- "$new_command" "$signal"
  done
}

#declare -f add_tmp_file add_trap escape_string
function add_tmp_file {
  declare temp_file command
  var_name="${1?}"
  temp_file="$(mktemp)"
  command='rm '"$(escape_string "$temp_file")"
  add_trap "$command" EXIT
  eval "$var_name"='"$temp_file"'
}

#declare -f add_tmp_dir add_trap escape_string
function add_tmp_dir {
  declare temp_dir command
  var_name="${1?}"
  temp_dir="$(mktemp -d )"
  command='rm -r '"$(escape_string "$temp_dir")"
  add_trap "$command" EXIT
  eval "$var_name"='"$temp_dir"'
}

function printn {
  declare str num
  str="$1"
  num="$2"
  spaces="$( printf "%$num"s )"; 
  echo "${spaces// /$str}"
}

function menu {
  declare message answer case_string param
  message="$1"
  shift 1
  echo_np "$message"
  case_string='case "${answer,,}" in '
  for param in "$@"; do
    case_string="$case_string ${param%%:*}) ${param#*:} ;;"
  done
  case_string="$case_string *) menu \"\$message\" \"\$@\" ;;"
  case_string="$case_string esac"
#  echo "$case_string"
  read -r answer
  eval "$case_string"
}

function trim_string {
  declare input
  input="$1"
  input="${input#"${input%%[![:space:]]*}"}"   # remove leading whitespace characters
  echo_np "${input%"${input##*[![:space:]]}"}"   # remove trailing whitespace characters  
}

function remove_comment_from_line {
  declare input
  input="$1"
  if [ "${#input}" -gt 0 ] && [ "${input:0:1}" == "#" ]; then
    echo
    return
  fi
  echo_np "${input%%[[:space:]]#*}"
}

function get_config_param {
  declare config_file param result conf_line found
  # procedure_line
  config_file="$1"
  param="$2"
  declare -i found=1
  function procedure_line {
    declare input_line needed_param stripped_line cutted_line
    input_line="$1"
    needed_param="$2"
    stripped_line="$(trim_string "$input_line")"
    stripped_line="$(remove_comment_from_line "$stripped_line")"
    cutted_line="${stripped_line#"$needed_param="}"
    if [ "$cutted_line" != "$stripped_line" ]; then
      result="$cutted_line"
      found=0
    fi
  }
  do_on_each_output_line 'cat "$config_file"' 'procedure_line "$line" "$param"' 'line'
  if [ "$found" == 0 ]; then
    echo_np "$result"
  else
    echo "$param: Not found in config file($config_file)."
  fi
  return $found
}

# wip, or trash
function try_to_create_empty {
  declare file_name
  file_name="$1"
  if [ -e "$file_name" ]; then
    if [ -f "$file_name" ] && tty >"/dev/null" 2>&1; then
      menu "Remove existing file("$file_name")? (n/y)" 'n:return 1' 'y:rm "$file_name"' || return 1
    else
      echo "$file_name: file exists, but not regular, or not a tty"
      return 2
    fi
  fi
  touch "$file_name"
}

function create_params_string {
  declare param params_string
  params_string=""
  for param in "$@"; do
    params_string+=" $(escape_string "$param") "
  done
  echo_np "$params_string"
}

# doesn't work
function port_forward_bg {
  bash --norc -c 'port_forward '"$(escape_string "$1")"' && wait $!' &
}

function finish_port_forward_bg_command { 
  echo "echo > /proc/$(trim_string "$(cat "/proc/$!/task/$!/children")")/fd/0"; 
}

#port_forward_bg "devops:35666->aradnai@info.ilab.sztaki.hu:?->:35666"
##### it works!!!
#coproc xxx { ssh info 'coproc xxx { ssh hulk "sleep 10000 & read;kill \$!"; }& read;kill $!'; }
#coproc xxx { ssh info 'coproc xxx { ssh hulk "sleep 10000 & read;kill \$!"; }& read; echo >&${xxx[1]}'; }
#aport=5475; nohup ssh -o StrictHostKeyChecking=no hulk -L $aport:localhost:$aport 'ssh -o StrictHostKeyChecking=no info -NL '$aport':localhost:22'&
#coproc xxx { ssh info -L "3551:localhost:3551" 'coproc xxx { ssh hulk -NL "3551:localhost:22"& read;kill $!; }& read; echo >&${xxx[1]}'; }
#nohup -- bash -c '. "/home/aradnai/bash/useful_functions/"functions.sh; port_forward "info:22->hulk:?->:5566"; add_tmp_file alma; rm "$alma"; mkfifo "$alma"; cat < "$alma" '&

#declare -f port_forward find_free_port is_port_free escape_string
function port_forward {
  declare fwd_string forward_to remaining_fwd_string forward_from to_remaining to_host to_port from_remaining from_user from_host from_port script_on_host
  declare from_sshport from_sshport_with_paranthese from_sshport_with_parantheses
  fwd_string="$1"
  forward_to="${fwd_string##*->}"
  remaining_fwd_string="${fwd_string%->*}"
  forward_from="${remaining_fwd_string##*->}"
  if [ "$forward_to" == "$remaining_fwd_string" ]; then
    coproc xxx { read; }&
    return 0
  fi
    
  to_remaining="${forward_to##*@}"
  to_host="${to_remaining%:*}"
  to_port="${to_remaining##*:}"
  if [ "$to_port" == "?" ]; then
    to_port="$(find_free_port)"
    echo "Found port: $to_host:$to_port" >> /dev/stderr
  fi
  from_remaining="${forward_from#(*)}"
  from_sshport_with_parantheses="${forward_from%"$from_remaining"}"
  from_sshport_with_paranthese="${from_sshport_with_parantheses%")"}"
  from_sshport="${from_sshport_with_paranthese#"("}"  
  forward_from="$from_remaining"
#  echo $from_sshport
#  echo $from_remaining
  from_remaining="${from_remaining##*@}"
  if [ "$from_remaining" == "$forward_from" ]; then
    from_user="$USER"
  else 
    from_user="${forward_from%@*}"
  fi
  from_host="${from_remaining%:*}"
  from_port="${from_remaining##*:}"
  if [ "$from_port" == "?" ]; then
    script_on_host="$(cat << SCRIPT_ON_HOST 
$(declare -f find_free_port is_port_free)
'find_free_port'
SCRIPT_ON_HOST
)"
    script_on_host="bash --norc -c $(escape_string "$script_on_host")"
    from_port="$(ssh -p "${from_sshport:-22}" "$from_user@$from_host" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet "$script_on_host")"
    if [ -z "$from_port" ]; then
      echo "ERROR: connection failed on host: $from_user@$from_host" >> /dev/stderr
      return 1
    fi
    remaining_fwd_string="${remaining_fwd_string%"$forward_from"}$from_user@$from_host:$from_port"
    echo "Found port: $from_host:$from_port" >> /dev/stderr
  fi
  
  echo "$remaining_fwd_string"
  script_on_host="$( cat << SCRIPT_ON_HOST 
$(declare -f port_forward find_free_port is_port_free escape_string echo_np printn)
port_forward $(escape_string "$remaining_fwd_string") 
read
echo >&\${xxx[1]}
SCRIPT_ON_HOST
)"
  coproc xxx {
    ssh -p "${from_sshport:-22}" "$from_user@$from_host" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=quiet -ATL "$to_port:localhost:$from_port" "$script_on_host" 
  }&
  [ -n "$xxx_PID" ] || (echo failure; exit 1) || return 1 
  echo 'echo > /proc/'"$xxx_PID"'/fd/0'
}

function get_state {
  options="$1"
  current_options_non_empty="$-\$"
  for (( i=0; i<"${#options}"; i++ )); do
    option="${options:$i:1}"
    if [ -z "${current_options_non_empty##*$option*}" ]; then
      echo -n "-"
    else
      echo -n "+"
    fi
    echo "$option"
  done
}

function findmm {
  first=${1%%:*}
  second=${1##*:}
  shift 1
  if [ -n "$first" ]; then
    mindepth_string="-mindepth $first"
  else
    mindepth_string=""
  fi
  if [ -n "$second" ]; then
    maxdepth_string="-maxdepth $second"
  else
    maxdepth_string=""
  fi

  find "$@" $maxdepth_string $mindepth_string
}

#  globbing="$(get_state f)"
#  set -f
#  set "$globbing"

#declare -f do_on_each_output_line
function do_on_each_output_line {
  declare doeol_command doeol_iteration_command doeol_var_name
  doeol_command="$1"
  doeol_iteration_command="$2"
  doeol_var_name="${3-line}"
    while IFS= read -r "$doeol_var_name"; do
      eval "$doeol_iteration_command" < /dev/null
    done < <(eval "$doeol_command")
}

function substitute_alias {
  command="$1"
  if alias "$command" > /dev/null 2>&1; then
    alias_value="$(alias "$command")"
    lstripped="${alias_value##"alias $command='"}"
    echo_np "${lstripped%%\'}"
  else
    echo_np "$command"
    return 1
  fi
}

function do_string_at_location {
  declare localhost command_string
  location="$2"
  command_string="$1"
#  base_command="${command_string%% *}"
#  length_of_base="${#base_command}"
#  rest_of_command="${command_string:$length_of_base}"
  pushd "$location" > /dev/null
#    if base_command="$(substitute_alias "$base_command")"; then
#      echo $base_command::::::$rest_of_command
#      eval "$base_command$rest_of_command"
#    else
    eval "$command_string" 
#    fi
  popd > /dev/null
}

function do_at_location {
  location="${!#}"
  command=("${@:1:$[$# - 1]}")
#  echo "x${command[0]}x"
#  substitute_alias "${command[0]}"
#  echo "${command[@]}"
  pushd "$location" > /dev/null
    if command[0]="$(substitute_alias "${command[0]}")"; then
      eval "${command[0]}" '"${command[@]:1:$[$# - 1]}"'
    else
      "${command[@]}"
    fi
  popd > /dev/null
}

function escape_string {
  declare string
  string="$1"
  echo "'$(echo_np "$string" | sed "s|'|'\\\''|g")'"
}

function escape_strings {
  declare param result
  result=""
  for param in "$@"; do
    result+="$(escape_string "$param") "
  done
  if [ -z "$result" ]; then 
    return
  fi
  echo "${result:0:-1}"
}

function initialize_clever_history {
  if [ -n "$CLEVER_HISTFILE_INITIALIZED" ]; then
    echo initialize_clever_history have already run.
    return 1
  fi
  used_hist_file=0
  function switch_history_type {
    if [ "$1" == "b" ]; then 
      direction="-1";
    else
      direction="1";
    fi
    cycle[0]="DUMMY_HISTFILE"
    cycle[1]="CLEVER_HISTFILE"
    cycle[2]="VERY_CLEVER_HISTFILE"
    used_hist_file=$[($used_hist_file + 1 * $direction) % ${#cycle[@]}]
    history -a
    history -cr "${!cycle[$used_hist_file]}"
    echo "Used hisory file: \"${!cycle[used_hist_file]}\"."
  }
  HISTIGNORE="$HISTIGNORE:history*"

  export PROMPT_COMMAND="${PROMPT_COMMAND-:}"';last_command=$(echo " $(history 1)" | tr -s " " | cut -d " " -f 3-); if [[ "$last_command" != do_string_at_location* ]] && [[ "$last_command" != do_at_location* ]] && [[ "$last_command" != \#* ]]; then echo "do_at_location $last_command \"$PWD\"" >> $CLEVER_HISTFILE; echo "do_string_at_location $(escape_string "$last_command") \"$PWD\"" >> $VERY_CLEVER_HISTFILE; fi'

  bind '"\x1b\xc3\xa9r": "\C-e \C-u switch_history_type\n\C-y\C-h"'
  bind '"\x1b\xc3\xa9R": "\C-e \C-u switch_history_type b\n\C-y\C-h"'
  bind '"\x1b\xc3\xa9B": "\C-e\ewb\C-ucd \n\C-y\C-a\ewf\C-u\e\C-e\C-e"'
  bind '"\x1b\xc3\xa9b": "\C-e\ewb\C-ucd \n\C-y\C-a\ewf\C-u\C-e"'
  CLEVER_HISTFILE_INITIALIZED="true"
}

function do_until_it_works {
  command="$1"
  sleep_time=$2
  on_succes="${3-:}"
  
  counter=0
  success=1
  while ! eval "$command"; do
    counter=$[$counter + 1]
    echo -e "\r$counter unsuccessful try."
    sleep $sleep_time
  done
  eval "$on_succes"
}

function new_bind {
  declare bind command after
  bind '"\ewb":shell-backward-word'
  bind '"\ewf":shell-forward-word'
#  bind '"\ewb":vi-backward-word'
#  bind '"\ewf":vi-forward-word'
  delete="\x1b\x5b\x33\x7e"
  backspace="\x7f"
  bind="$1"
  command="$2"
  after="${3-}"
  occurence_num="$(count_occurence "$to_replace" "$command")"
  bind_command=()
  bind_command[0]="bind"
  bind_command[1]='"'"$bind"'": "\ewb\ewf \C-b'
  backward=$(for ((i = 0; i < "$occurence_num"; ++i)); do echo -n "\ewb"; done)
  forward=$(for ((i = 0; i < "$occurence_num"; ++i)); do echo -n "\ewf"; done)
  bind_command[1]+="$backward"' \C-u'"$forward"'\C-f\C-b\C-k\C-a$('
  substituted_command="$(echo_np "$command" | sed 's|'"$to_replace"'|\\ewf|g')"
  bind_command[1]+="$substituted_command"
  bind_command[1]+=')\e\C-e'"$delete"'\C-y'"$backspace"'\C-a\C-y\ey\ewf'
  bind_command[1]+="$after"\"
  if [ "$SILENT_BIND" != "true" ]; then
    print_array bind_command
  fi
  "${bind_command[@]}"
}

function paste_shortcut {
  # lines width max 256 (xte str)
  bash -c '
selected="$(xsel)";
function do_on_each_output_line {
  declare doeol_command doeol_iteration_command doeol_var_name;
  doeol_command="$1";
  doeol_iteration_command="$2";
  doeol_var_name="${3-line}";
    while IFS= read -r "$doeol_var_name"; do
      eval "$doeol_iteration_command" < /dev/null;
    done < <(eval "$doeol_command");
};
params=();
do_on_each_output_line '\''xsel; echo .'\'' '\''params+=("str $line" "key Return")'\'';
last_param="${params[${#params[@]}-2]}";
xte "keyup Control_L" "keyup Alt_L" "keyup Control_R" "keyup p" "${params[@]:0:${#params[@]}-2}" "${last_param:0:${#last_param}-1}"'
#  sh -c 'xsel > /dev/null; xte "keyup Control_L" "keyup Alt_L" "keyup Control_R" "str p$(xsel)" '
}

function search_shortcut {
  bash -c '
selection="$(xsel)";
url_encoded="$(python -c "import sys, urllib as ul; print ul.quote_plus(sys.argv[1])" "$selection")";
xdg-open "https://www.google.hu/search?q=$url_encoded&gws_rd=cr,ssl&ei=ILFNVpGkCquMzAO-2p6ACw"
'
}

function translate_shortcut {
  bash -c '
selection="$(xsel)";
url_encoded="$(python -c "import sys, urllib as ul; print ul.quote_plus(sys.argv[1])" "$selection")";
xdg-open "https://translate.google.com/?hl=hu#en/hu/$url_encoded"
'
}

function translate_sztaki_shortcut {
  bash -c '
selection="$(xsel)";
url_encoded="$(python -c "import sys, urllib as ul; print ul.quote_plus(sys.argv[1])" "$selection")";
xdg-open "http://szotar.sztaki.hu/search?fromlang=all&tolang=all&searchWord=$url_encoded&langcode=hu&u=0&langprefix=&searchMode=WORD_PREFIX&viewMode=full&ignoreAccents=1"
'
}

function search_gui_shortcut {
  bash -c '
selection=$(zenity --entry --text="Google search") || exit;
url_encoded="$(python -c "import sys, urllib as ul; print ul.quote_plus(sys.argv[1])" "$selection")";
xdg-open "https://www.google.hu/search?q=$url_encoded&gws_rd=cr,ssl&ei=ILFNVpGkCquMzAO-2p6ACw"
'
}

function translate_gui_shortcut {
  bash -c '
selection=$(zenity --entry --text="Google translate") || exit;
url_encoded="$(python -c "import sys, urllib as ul; print ul.quote_plus(sys.argv[1])" "$selection")";
xdg-open "https://translate.google.com/?hl=hu#en/hu/$url_encoded"
'
}

function translate_sztaki_gui_shortcut {
  bash -c '
selection=$(zenity --entry --text="SZTAKI translate") || exit;
url_encoded="$(python -c "import sys, urllib as ul; print ul.quote_plus(sys.argv[1])" "$selection")";
xdg-open "http://szotar.sztaki.hu/search?fromlang=all&tolang=all&searchWord=$url_encoded&langcode=hu&u=0&langprefix=&searchMode=WORD_PREFIX&viewMode=full&ignoreAccents=1"
'
}


function newest_bind {
  bind '"\ewb":shell-backward-word'
  bind '"\ewf":shell-forward-word'
  delete="\x1b\x5b\x33\x7e"
  backspace="\x7f"
  bind="$1"
  command="$2"
  params="$3"
  occurence_num="$(count_occurence "$to_replace" "$params")"
  bind_command=()
  bind_command[0]="bind"
  bind_command[1]='"'"$bind"'": "\ewb\ewf \C-b'
  backward=$(for ((i = 0; i < "$occurence_num"; ++i)); do echo -n "\ewb"; done)
  forward=$(for ((i = 0; i < "$occurence_num"; ++i)); do echo -n "\ewf"; done)
  bind_command[1]="${bind_command[1]}""$backward"' \C-u'"$forward"'\C-f\C-b\C-k\C-a'
  substituted_params="$(echo_np "$params" | sed 's|'"$to_replace"'|\\ewf|g')"
  substituted_command="$substituted_params"'\C-a\C-ktemp_v=$(cat << '"'$VERY_UNUSED_WORD'"'\n\C-y'
  substituted_command="$substituted_command"'\n'"$VERY_UNUSED_WORD"'\n'
  bind_command[1]="${bind_command[1]}""$substituted_command"
  bind_command[1]="${bind_command[1]}"')\n$('"$command"' \"$temp_v\")\e\C-e'"$delete"'\C-y\ey'"$backspace"'\C-a\C-y\ey\ewf"'
  if [ "$SILENT_BIND" != "true" ]; then
    print_array bind_command
  fi
  "${bind_command[@]}"
}

function transpose_parameters {
  param_num="$#"
  result_plus_space="$(
    for ((i = "$param_num"; i >= 1; --i)); do
      echo -n "\"${!i}\" "
    done
  )"
  if [ -n "$result_plus_space" ]; then
    length="${#result_plus_space}"
    result="${result_plus_space:0:$(($length - 1))}"
    echo_np "$result"
  fi
}

function transpose_parameters_by_delimiter {
  delim="$1"
  params="$2"
  param_num="$(count_occurence "$delim" "$params")"
  params="$delim$params"
  delim_length="${#delim}"
  result_plus_space="$(
    for ((i = "$param_num"; i >= 0; --i)); do
      param="${params##*"$delim"}"
      param_length="${#param}"
      params="${params:0:-$param_length-$delim_length}"
      echo -n "${param} "
    done
  )"
  if [ -n "$result_plus_space" ]; then
    length="${#result_plus_space}"
    result="${result_plus_space:0:$(($length - 1))}"
    echo_np "$result"
  fi
}

function absolutize {
  relative_file_path="$1"
  absolute_file_path="$(readlink -f "$relative_file_path")"
  echo_np "$absolute_file_path"
}

function binding_absolutize {
  escape_string "$(absolutize "$1")"
}

#declare -f print_array escape_strings
function print_array {
  declare array
  copy_array "$1" array
  escape_strings "${array[@]}"
}

#declare -f print_array escape_strings
function print_array_to_lines {
  declare array_name="$1"
  (set +u; eval 'printf -- '\''%s\n'\'' "${'"$array_name"'[@]}"')
}

function copy_array {
  from_name="$1"
  to_name="$2"
  eval "$to_name"'=()'
#  print_array_command='eval '\''printf -- '\''\'\'\''%s\n'\''\'\'\'' "${'\''$from_name'\''[@]}"'\'
  print_array_command='print_array_to_lines $from_name'
  do_on_each_output_line "$print_array_command" 'eval "$to_name"'\''+=("$line")'\'
}

#cannot copy empty array!
#function copy_array {
#  from_name="$1"
#  to_name="$2"
#  eval "$to_name"'=("${'"$from_name"'[@]}")'
#}

function count_occurence {
  pattern="$1"
  string="$2"
  whitespaceless="$(echo_np "$string" | tr -d '\r\n\t ')"
  array=(${whitespaceless//"$pattern"/x x})
  echo $((${#array[@]}-1))
}

function substract_sets {
  declare minuend_set subtrahend_set result_set_name 
  copy_array "$1" minuend_set
  copy_array "$2" subtrahend_set
  result_set_name="$3"
  eval "$result_set_name"'=()'
  for element in "${minuend_set[@]}"; do
    if (set +u; ! contains_element "$element" "${subtrahend_set[@]}"); then
      eval "$result_set_name"+='("$element")'
    fi
  done
}

function is_variable_name {
  declare var_name
  var_name="$1"
  [ -n "$var_name" ] && echo "$var_name" | grep -qx '[qwertzuiopasdfghjklyxcvbnmQWERTZUIOPASDFGHJKLYXCVBNM_][qwertzuiopasdfghjklyxcvbnmQWERTZUIOPASDFGHJKLYXCVBNM0-9_]*'
}

function export_empty_methods {
  declare method_name impletmentation_string
  for method_name in "$@"; do
    impletmentation_string="function $method_name { :; }; export -f $method_name"
    eval "$impletmentation_string"
  done
}

function get_descendant_processes { 
  declare children process
  for process in "$@"; do
    children=($(ps h -o pid --ppid "$process")) || continue
    print_array_to_lines children
    get_descendant_processes "${children[@]}" 2>/dev/null
  done
}

function get_yaml_cfg_param {
  declare yaml_file cfg_param_names
  yaml_file="$1"
  cfg_param_names=("${@:2}")
  python -c '
import yaml
import sys
cfg=yaml.load(sys.stdin)
for key in sys.argv[1:]:
  if key not in cfg:
    key = int(key)
  cfg=cfg[key]
print cfg
' "${cfg_param_names[@]}" < "$yaml_file"

}

function gradle {
  if ! [ -f "build.gradle" ]; then
    echo "build.gradle not found."
    return 1
  fi
  if ! [ -x "./gradlew" ]; then
    echo 'CREATING gradlew executable first.'
    command gradle wrapper
    exit_val="$?"
    if [ 0 != "$exit_val" ]; then
      return "$exit_val"
    fi
  fi
  echo ./gradlew "$@"
  ./gradlew "$@"
}

function find_java { 
  declare chars pattern 
  pattern=""
  for ((i = 0; i < ${#1}; ++i)); do
    char="${1:i:1}"
    pattern+="*$char"
  done
  pattern+="*.java"
  find . -name "$pattern"
}


function diff_jars { j1="$(readlink -f "$1")"; j2="$(readlink -f "$2")"; add_tmp_dir d1; add_tmp_dir d2; (cd "$d1"; jar xf "$j1"); (cd "$d2"; jar xf "$j2"); diff_recursive "$d1" "$d2"; }
export -f echo_np mount_sshfs_if_needed absolutize_no_link_following contains_element wrap_function ensure_true ensure_true_silent my_reset find_element check_command is_port_free diff_recursive find_free_port add_trap add_tmp_file add_tmp_dir printn menu trim_string remove_comment_from_line get_config_param try_to_create_empty create_params_string port_forward_bg finish_port_forward_bg_command port_forward get_state findmm do_on_each_output_line substitute_alias do_string_at_location do_at_location escape_string escape_strings initialize_clever_history do_until_it_works new_bind newest_bind transpose_parameters transpose_parameters_by_delimiter absolutize binding_absolutize print_array count_occurence copy_array print_array_to_lines substract_sets export_empty_methods get_descendant_processes get_descendant_processes get_yaml_cfg_param gradle parse_git_branch ps1_git_branch init_git_commit find_java index_of 
