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
copy="$(command -v xclip || command -v pbcopy)"
gpg="$(command -v gpg || command -v gpg2)"
gpg_conf="${HOME}/.gnupg/gpg.conf"
pass_chars="[:alnum:]!?@#$%^&*();:+="

clip_dest="${PWDSH_DEST:=clipboard}"  # set to 'screen' to print to stdout
clip_timeout="${PWDSH_TIME:=10}"      # seconds to clear clipboard/screen
comment="${PWDSH_COMMENT:=}"          # *unencrypted* comment in files
daily_backup="${PWDSH_DAILY:=}"       # daily backup archive on write
pass_copy="${PWDSH_COPY:=}"           # copy password before write
pass_len="${PWDSH_LEN:=14}"           # default generated password length
safe_dir="${PWDSH_SAFE:=safe}"        # safe directory name
safe_ix="${PWDSH_INDEX:=pwd.index}"   # index file name
safe_backup="${PWDSH_BACKUP:=pwd.$(hostname).${today}.tar}"

trap cleanup EXIT INT TERM
cleanup () {
  # "Lock" safe on trapped exits.

  ret=$?
  chmod -R 0000 "${safe_ix}" "${safe_dir}" 2>/dev/null
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

get_pass () {
  # Prompt for a password.

  prompt="  ${1}"
  printf "\n"

  while IFS= read -p "${prompt}" -r -s -n 1 char ; do
    if [[ ${char} == $'\0' ]] ; then
      break
    elif [[ ${char} == $'\177' ]] ; then
      if [[ -z "${password}" ]] ; then
        prompt=""
      else
        prompt=$'\b \b'
        password="${password%?}"
      fi
    else
      prompt="*"
      password+="${char}"
    fi
  done
}

decrypt () {
  # Decrypt with GPG.

  printf "%s\n" "${1}" | \
    ${gpg} --armor --batch --no-symkey-cache \
    --decrypt --passphrase-fd 0 "${2}" 2>/dev/null
}

encrypt () {
  # Encrypt with GPG.

  ${gpg} --armor --batch --comment "${comment}" \
    --symmetric --yes --passphrase-fd 3 \
    --output "${2}" "${3}" 3< <(printf '%s\n' "${1}") 2>/dev/null
}

read_pass () {
  # Read a password from safe.

  if [[ ! -s ${safe_ix} ]] ; then fail "${safe_ix} not found" ; fi

  while [[ -z "${username}" ]] ; do
    if [[ -z "${2+x}" ]] ; then read -r -p "
  Username: " username
    else username="${2}" ; fi
  done

  get_pass "Password to unlock ${safe_ix}: " ; printf "\n"

  spath=$(decrypt "${password}" "${safe_ix}" | \
    grep -F "${username}" | tail -1 | cut -d : -f2) || \
      fail "Secret not available"

  clip <(decrypt "${password}" "${spath}") || \
    fail "Failed to decrypt ${spath}"
}

gen_pass () {
  # Generate a password from urandom.

  if [[ -z "${3+x}" ]] ; then read -r -p "
  Password length (default: ${pass_len}): " length
  else length="${3}" ; fi

  if [[ ${length} =~ ^[0-9]+$ ]] ; then pass_len=${length} ; fi

  tr -dc "${pass_chars}" < /dev/urandom | \
    fold -w "${pass_len}" | head -1
}

write_pass () {
  # Write a password and update the index.

  spath="${safe_dir}/$(tr -dc "[:lower:]" < /dev/urandom | \
    fold -w10 | head -1)"

  if [[ -n "${pass_copy}" ]] ; then
    clip <(printf '%s' "${userpass}")
  fi

  get_pass "Password to unlock ${safe_ix}: " ; printf "\n"

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

  if [[ ! -s ${safe_ix} ]] ; then fail "${safe_ix} not found" ; fi

  get_pass "Password to unlock ${safe_ix}: " ; printf "\n\n"

  decrypt "${password}" "${safe_ix}" || fail "${safe_ix} not available"
}

backup () {
  # Archive index, safe and configuration.

  if [[ -f "${safe_ix}" && -d "${safe_dir}" ]] ; then
    cp "${gpg_conf}" "gpg.conf.${today}"
    tar cf "${safe_backup}" "${safe_ix}" "${safe_dir}" \
      "${BASH_SOURCE}" "gpg.conf.${today}" && \
        printf "\nArchived %s\n" "${safe_backup}"
    rm -f "gpg.conf.${today}"
  else fail "Nothing to archive" ; fi
}

clip () {
  # Use clipboard or stdout and clear after timeout.

  if [[ "${clip_dest}" = "screen" ]] ; then
    printf '\n%s\n' "$(cat ${1})"
  else ${copy} < "${1}" ; fi

  printf "\n"
  while [ "${clip_timeout}" -gt 0 ] ; do
    printf "\r\033[K  Password on %s! Clearing in %.d" \
      "${clip_dest}" "$((clip_timeout--))" ; sleep 1
  done
  printf "\r\033[K  Clearing password from %s ..." "${clip_dest}"

  if [[ "${clip_dest}" = "screen" ]] ; then
    clear
  else printf "\n" ; printf "" | ${copy} ; fi

}

new_entry () {
  # Prompt for username and password.

  while [[ -z "${username}" ]] ; do
    if [[ -z "${2+x}" ]] ; then read -r -p "
  Username: " username
    else username="${2}" ; fi
  done

  if [[ -z "${3+x}" ]] ; then
    get_pass "Password for \"${username}\" (Enter to generate): "
    userpass="${password}"
  fi

  printf "\n"
  if [[ -z "${password}" ]] ; then
    userpass=$(gen_pass "$@")
  fi
}

print_help () {
  # Print help text.

  printf """\npwd.sh is a Bash shell script to manage passwords and other text-based secrets.

  It uses GnuPG to symmetrically (i.e., using a master password) encrypt and decrypt plaintext files.

  Each password is encrypted as a unique, randomly-named file in the 'safe' directory. An encrypted index is used to map usernames to the respective password file. Both the index and password files can also be decrypted directly with GnuPG without this script.

  Run the script interactively using ./pwd.sh or symlink to a directory in PATH:

    * 'w' to write a password
    * 'r' to read a password
    * 'l' to list passwords
    * 'b' to create an archive for backup

  Options can also be passed on the command line.

  * Create a 20-character password for userName:
    ./pwd.sh w userName 20

  * Read password for userName:
    ./pwd.sh r userName

  * Passwords are stored with an epoch timestamp for revision control. The most recent version is copied to clipboard on read. To list all passwords or read a specific version of a password:
    ./pwd.sh l
    ./pwd.sh r userName@1574723625

  * Create an archive for backup:
    ./pwd.sh b

  * Restore an archive from backup:
    tar xvf pwd*tar\n"""
}

if [[ -z "${gpg}" && ! -x "${gpg}" ]] ; then fail "GnuPG is not available" ; fi

if [[ ! -f "${gpg_conf}" ]] ; then fail "GnuPG config is not available" ; fi

if [[ ! -d "${safe_dir}" ]] ; then mkdir -p "${safe_dir}" ; fi

chmod -R 0700 "${safe_ix}" "${safe_dir}" 2>/dev/null

if [[ -z ${copy} && ! -x ${copy} ]] ; then
  warn "Clipboard not available, passwords will print to screen/stdout!"
  clip_dest="screen"
fi

username=""
password=""
action=""

if [[ -n "${1+x}" ]] ; then action="${1}" ; fi

while [[ -z "${action}" ]] ; do read -r -n 1 -p "
  Read or Write (or Help for more options): " action
  printf "\n"
done

if [[ "${action}" =~ ^([rR])$ ]] ; then
  read_pass "$@"
elif [[ "${action}" =~ ^([wW])$ ]] ; then
  new_entry "$@"
  write_pass
  if [[ -n "${daily_backup}" && ! -f ${safe_backup} ]]
    then backup
  fi
elif [[ "${action}" =~ ^([lL])$ ]] ; then list_entry
elif [[ "${action}" =~ ^([bB])$ ]] ; then backup
else print_help ; fi

tput setaf 2 ; printf "\nDone\n" ; tput sgr0
