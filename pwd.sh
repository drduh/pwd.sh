#!/usr/bin/env bash
# https://github.com/drduh/pwd.sh/blob/master/pwd.sh
#set -x  # uncomment to debug
set -o errtrace
set -o nounset
set -o pipefail
umask 077
export LC_ALL="C"

now="$(date +%s)"
today="$(date +%F)"
gpg="$(command -v gpg || command -v gpg2)"
gpg_conf="${HOME}/.gnupg/gpg.conf"

clip="${PWDSH_CLIP:=xclip}"           # clipboard, 'pbcopy' on macOS
clip_args="${PWDSH_CLIP_ARGS:=}"      # args to pass to clip command
clip_dest="${PWDSH_DEST:=clipboard}"  # cb type, 'screen' for stdout
clip_timeout="${PWDSH_TIME:=10}"      # seconds to clear cb/screen
comment="${PWDSH_COMMENT:=}"          # *unencrypted* comment in files
daily_backup="${PWDSH_DAILY:=}"       # daily backup archive on write
pass_copy="${PWDSH_COPY:=}"           # copy password before write
pass_echo="${PWDSH_ECHO:=*}"          # show "*" when typing passwords
pass_len="${PWDSH_LEN:=14}"           # default password length
pepper="${PWDSH_PEPPER:=}"            # additional secret file name
safe_dir="${PWDSH_SAFE:=safe}"        # safe directory name
safe_ix="${PWDSH_INDEX:=pwd.index}"   # index file name
safe_backup="${PWDSH_BACKUP:=pwd.$(hostname).${today}.tar}"
pass_chars="${PWDSH_CHARS:='[:alnum:]!?@#$%^&*();:+='}"

trap cleanup EXIT INT TERM
cleanup () {
  # "Lock" files on trapped exits.

  ret=$?
  chmod -R 0000 "${pepper}" "${safe_dir}" "${safe_ix}" 2>/dev/null
  exit ${ret}
}

fail () {
  # Print an error in red and exit.

  tput setaf 1 ; printf "\nERROR: %s\n" "${1}" ; tput sgr0
  exit 1
}

warn () {
  # Print a warning in yellow.
  tput setaf 3 ; printf "\nWARNING: %s\n" "${1}" ; tput sgr0
}

generate_pepper () {
  # Generate pepper, avoid ambiguous characters.

  warn "${pepper} created"
  printf "%s" "$(tr -dc 'A-Z1-9' < /dev/urandom | \
    tr -d "1IOS5U" | fold -w 30 | sed "-es/./ /"{1..26..5} | \
    cut -c2- | tr " " "-" | head -1)" | \
    tee "${pepper}" || fail "Failed to create ${pepper}"
  printf "\n"
}

get_pass () {
  # Prompt for a password.

  password=""
  prompt="  ${1}"
  printf "\n"

  while IFS= read -p "${prompt}" -r -s -n 1 char ; do
    if [[ ${char} == $'\0' ]] ; then break
    elif [[ ${char} == $'\177' ]] ; then
      if [[ -z "${password}" ]] ; then prompt=""
      else
        prompt=$'\b \b'
        password="${password%?}"
      fi
    else
      prompt="${pass_echo}"
      password+="${char}"
    fi
  done
}

decrypt () {
  # Decrypt with GPG.

  printf "%s" "${1}${pep}" | \
    ${gpg} --armor --batch --no-symkey-cache \
    --decrypt --passphrase-fd 0 "${2}" 2>/dev/null
}

encrypt () {
  # Encrypt with GPG.

  ${gpg} --armor --batch --comment "${comment}" \
    --symmetric --yes --passphrase-fd 3 \
    --output "${2}" "${3}" 3< \
    <(printf "%s" "${1}${pep}") 2>/dev/null
}

read_pass () {
  # Read a password from safe.

  if [[ ! -s "${safe_ix}" ]] ; then fail "${safe_ix} not found" ; fi

  while [[ -z "${username}" ]] ; do
    if [[ -z "${2+x}" ]] ; then read -r -p "
  Username: " username
    else username="${2}" ; fi
  done

  get_pass "Password to access ${safe_ix}: " ; printf "\n"

  spath=$(decrypt "${password}" "${safe_ix}" | \
    grep -F "${username}" | tail -1 | cut -d ":" -f2) || \
      fail "Secret not available"

  emit_pass <(decrypt "${password}" "${spath}") || \
    fail "Failed to decrypt ${spath}"
}

generate_pass () {
  # Generate a password from urandom.

  if [[ -z "${3+x}" ]] ; then read -r -p "
  Password length (default: ${pass_len}): " length
  else length="${3}" ; fi

  if [[ "${length}" =~ ^[0-9]+$ ]] ; then
    pass_len="${length}"
  fi

  tr -dc "${pass_chars}" < /dev/urandom | \
    fold -w "${pass_len}" | head -1
}

generate_user () {
  # Generate a username.

  printf "%s%s\n" \
    "$(awk 'length > 2 && length < 12 {print(tolower($0))}' \
    /usr/share/dict/words | grep -v "'" | sort -R | head -n2 | \
    tr "\n" "_" | iconv -f utf-8 -t ascii//TRANSLIT)" \
    "$(tr -dc "[:digit:]" < /dev/urandom | fold -w 4 | head -1)"
}

write_pass () {
  # Write a password and update the index.

  spath="${safe_dir}/$(tr -dc "[:lower:]" < /dev/urandom | \
    fold -w10 | head -1)"

  if [[ -n "${pass_copy}" ]] ; then
    emit_pass <(printf '%s' "${userpass}") ; fi

  get_pass "Password to access ${safe_ix}: " ; printf "\n"

  printf '%s\n' "${userpass}" | \
    encrypt "${password}" "${spath}" - || \
      fail "Failed saving ${spath}"

  ( if [[ -f "${safe_ix}" ]] ; then
      decrypt "${password}" "${safe_ix}" || return ; fi
    printf "%s@%s:%s\n" "${username}" "${now}" "${spath}") | \
    encrypt "${password}" "${safe_ix}.${now}" - && \
      mv "${safe_ix}.${now}" "${safe_ix}" || \
        fail "Failed saving ${safe_ix}.${now}"
}

list_entry () {
  # Decrypt the index to list entries.

  if [[ ! -s "${safe_ix}" ]] ; then fail "${safe_ix} not found" ; fi
  get_pass "Password to access ${safe_ix}: " ; printf "\n\n"
  decrypt "${password}" "${safe_ix}" || fail "${safe_ix} not available"
}

backup () {
  # Archive index, safe and configuration.

  if [[ ! -f "${safe_backup}" ]] ; then
    if [[ -f "${safe_ix}" && -d "${safe_dir}" ]] ; then
      cp "${gpg_conf}" "gpg.conf.${today}"
      tar cf "${safe_backup}" "${safe_dir}" "${safe_ix}" \
        "${BASH_SOURCE}" "gpg.conf.${today}" && \
          printf "\nArchived %s\n" "${safe_backup}"
      rm -f "gpg.conf.${today}"
    else fail "Nothing to archive" ; fi
  else warn "${safe_backup} exists, skipping archive" ; fi
}

emit_pass () {
  # Use clipboard or stdout and clear after timeout.

  if [[ "${clip_dest}" = "screen" ]] ; then
    printf '\n%s\n' "$(cat ${1})"
  else ${clip} < "${1}" ; fi

  printf "\n"
  while [[ "${clip_timeout}" -gt 0 ]] ; do
    printf "\r\033[K  Password on %s! Clearing in %.d" \
      "${clip_dest}" "$((clip_timeout--))" ; sleep 1
  done
  printf "\r\033[K  Clearing password from %s ..." "${clip_dest}"

  if [[ "${clip_dest}" = "screen" ]] ; then clear
  else printf "\n" ; printf "" | ${clip} ; fi
}

new_entry () {
  # Prompt for username and password.

  if [[ -z "${2+x}" ]] ; then read -r -p "
  Username (Enter to generate): " username
  else username="${2}" ; fi

  if [[ -z "${username}" ]] ; then
    username=$(generate_user "$@") ; fi

  if [[ -z "${3+x}" ]] ; then
    get_pass "Password for \"${username}\" (Enter to generate): "
    userpass="${password}"
  fi

  printf "\n"
  if [[ -z "${password}" ]] ; then
    userpass=$(generate_pass "$@") ; fi
}

print_help () {
  # Print help text.

  printf """
  pwd.sh is a Bash shell script to manage passwords and other text-based secrets.\n
  It uses GnuPG to symmetrically (i.e., using a master password) encrypt and decrypt plaintext files.\n
  Each password is encrypted as a unique, randomly-named file in the 'safe' directory. An encrypted index is used to map usernames to the respective password file. Both the index and password files can also be decrypted directly with GnuPG without this script.\n
  Run the script interactively using ./pwd.sh or symlink to a directory in PATH:
    * 'w' to write a password
    * 'r' to read a password
    * 'l' to list passwords
    * 'b' to create an archive for backup\n
  Options can also be passed on the command line.\n
  * Create a 20-character password for userName:
    ./pwd.sh w userName 20\n
  * Read password for userName:
    ./pwd.sh r userName\n
  * Passwords are stored with an epoch timestamp for revision control. The most recent version is copied to clipboard on read. To list all passwords or read a specific version of a password:
    ./pwd.sh l
    ./pwd.sh r userName@1574723625\n
  * Create an archive for backup:
    ./pwd.sh b\n
  * Restore an archive from backup:
    tar xvf pwd*tar\n"""
}

if [[ -z "${gpg}" ]] ; then fail "GnuPG is not available" ; fi

if [[ ! -f "${gpg_conf}" ]] ; then fail "GnuPG config is not available" ; fi

if [[ ! -d "${safe_dir}" ]] ; then mkdir -p "${safe_dir}" ; fi

if [[ -n "${pepper}" && ! -f "${pepper}" ]] ; then generate_pepper ; fi

chmod -R 0700 "${pepper}" "${safe_dir}" "${safe_ix}" 2>/dev/null

if [[ -f "${pepper}" ]] ; then pep="$(cat ${pepper})" ; else pep="" ; fi

if [[ -z "$(command -v ${clip})" ]] ; then
  warn "Clipboard not available, passwords will print to screen/stdout!"
  clip_dest="screen"
elif [[ -n "${clip_args}" ]] ; then
  clip+=" ${clip_args}"
fi

username=""
password=""
action=""

if [[ -n "${1+x}" ]] ; then action="${1}" ; fi

while [[ -z "${action}" ]] ; do read -r -n 1 -p "
  Read or Write (or Help for more options): " action
  printf "\n"
done

if [[ "${action}" =~ ^([rR])$ ]] ; then read_pass "$@"
elif [[ "${action}" =~ ^([wW])$ ]] ; then
  new_entry "$@"
  write_pass
  if [[ -n "${daily_backup}" ]] ; then backup ; fi
elif [[ "${action}" =~ ^([lL])$ ]] ; then list_entry
elif [[ "${action}" =~ ^([bB])$ ]] ; then backup
else print_help ; fi

tput setaf 2 ; printf "\nDone\n" ; tput sgr0
