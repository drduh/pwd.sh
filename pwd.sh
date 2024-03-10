#!/usr/bin/env bash
# https://github.com/drduh/pwd.sh/blob/master/pwd.sh
set -o errtrace
set -o nounset
set -o pipefail
#set -x  # uncomment to debug

umask 077

cb_timeout=10         # seconds to keep password on clipboard
daily_backup="false"  # if true, create daily archive on write
pass_copy="false"     # if true, keep password on clipboard before write
pass_len=14           # default password length
pass_chars="[:alnum:]!@#$%^&*();:+="

gpgconf="${HOME}/.gnupg/gpg.conf"
backuptar="${PWDSH_BACKUP:=pwd.$(hostname).$(date +%F).tar}"
safeix="${PWDSH_INDEX:=pwd.index}"
safedir="${PWDSH_SAFE:=safe}"

now="$(date +%s)"
copy="$(command -v xclip || command -v pbcopy)"
gpg="$(command -v gpg || command -v gpg2)"
script="$(basename "${BASH_SOURCE}")"

fail () {
  # Print an error message and exit.

  tput setaf 1 ; printf "\nError: %s\n" "${1}" ; tput sgr0
  exit 1
}

get_pass () {
  # Prompt for a password.

  password=""
  prompt="${1}"

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

  ${gpg} --armor --batch \
    --symmetric --yes --passphrase-fd 3 --no-symkey-cache \
    --output "${2}" "${3}" 3< <(printf '%s\n' "${1}") 2>/dev/null
}

read_pass () {
  # Read a password from safe.

  if [[ ! -s ${safeix} ]] ; then fail "${safeix} not found" ; fi

  username=""
  while [[ -z "${username}" ]] ; do
    if [[ -z "${2+x}" ]] ; then read -r -p "
  Username: " username
    else username="${2}" ; fi
  done

  while [[ -z "${password}" ]] ; do get_pass "
  Password to unlock ${safeix}: " ; done
  printf "\n"

  spath=$(decrypt "${password}" "${safeix}" | \
    grep -F "${username}" | tail -n1 | cut -d : -f2) || \
      fail "Failed to decrypt ${safeix}"

  clip <(decrypt "${password}" "${spath}") || \
    fail "Failed to decrypt ${spath}"
}

gen_pass () {
  # Generate a password using GPG.

  if [[ -z "${3+x}" ]] ; then read -r -p "
  Password length (default: ${pass_len}): " length
  else length="${3}" ; fi

  if [[ ${length} =~ ^[0-9]+$ ]] ; then pass_len=${length} ; fi

  LC_LANG=C tr -dc "${pass_chars}" < /dev/urandom | \
    fold -w "${pass_len}" | head -1
}

write_pass () {
  # Write a password and update index file.

  password=""
  while [[ -z "${password}" ]] ; do get_pass "
  Password to unlock ${safeix}: " ; done
  printf "\n"

  if [[ "${pass_copy}" = "true" ]] ; then
    clip <(printf '%s' "${userpass}")
  fi

  fpath="$(LC_LANG=C tr -dc '[:lower:]' < /dev/urandom | fold -w10 | head -1)"
  spath="${safedir}/${fpath}"
  printf '%s\n' "${userpass}" | \
    encrypt "${password}" "${spath}" - || \
      fail "Failed to put ${spath}"
  userpass=""

  ( if [[ -f "${safeix}" ]] ; then
      decrypt "${password}" "${safeix}" || return ; fi
    printf "%s@%s:%s\n" "${username}" "${now}" "${spath}") | \
    encrypt "${password}" "${safeix}.${now}" - || \
      fail "Failed to put ${safeix}.${now}"

  mv "${safeix}.${now}" "${safeix}"
}

list_entry () {
  # Decrypt the index to list entries.

  if [[ ! -s ${safeix} ]] ; then fail "${safeix} not found" ; fi

  while [[ -z "${password}" ]] ; do get_pass "
  Password to unlock ${safeix}: " ; done
  printf "\n\n"

  decrypt "${password}" "${safeix}" || \
    fail "Decryption failed"
}

backup () {
  # Archive index, safe and configuration.

  if [[ -f "${safeix}" && -d "${safedir}" ]] ; then
    cp "${gpgconf}" "gpg.conf.${now}"
    tar --create --file "${backuptar}" \
      "${safeix}" "${safedir}" "gpg.conf.${now}" "${script}"
    rm "gpg.conf.${now}"
  else fail "Nothing to archive" ; fi

  printf "\nArchived %s\n" "${backuptar}"
}

clip () {
  # Use clipboard and clear after timeout.

  ${copy} < "${1}"

  printf "\n"
  shift
  while [ $cb_timeout -gt 0 ] ; do
    printf "\r\033[KPassword on clipboard! Clearing in %.d" $((cb_timeout--))
    sleep 1
  done

  printf "\n"
  printf "" | ${copy}
}

new_entry () {
  # Prompt for username and password.

  username=""
  while [[ -z "${username}" ]] ; do
    if [[ -z "${2+x}" ]] ; then read -r -p "
  Username: " username
    else username="${2}" ; fi
  done

  if [[ -z "${3+x}" ]] ; then get_pass "
  Password for \"${username}\" (Enter to generate): "
    userpass="${password}"
  fi

  printf "\n"
  if [[ -z "${password}" ]] ; then
    userpass=$(gen_pass "$@")
  fi
}

print_help () {
  # Print help text.

  printf """
  pwd.sh is a Bash shell script to manage passwords with GnuPG symmetric encryption.

  pwd.sh can be used interactively or by passing one of the following options:

    * 'w' to write a password
    * 'r' to read a password
    * 'l' to list passwords
    * 'b' to create an archive for backup

  Example usage:

    * Generate a 30 character password for 'userName':
        ./pwd.sh w userName 30

    * Copy the password for 'userName' to clipboard:
        ./pwd.sh r userName

    * List stored passwords and copy a specific version:
        ./pwd.sh l
        ./pwd.sh r userName@1574723625

    * Create an archive for backup:
        ./pwd.sh b

    * Restore an archive from backup:
        tar xvf pwd*tar"""
}

if [[ -z ${gpg} && ! -x ${gpg} ]] ; then fail "GnuPG is not available" ; fi

if [[ -z ${copy} && ! -x ${copy} ]] ; then fail "Clipboard is not available" ; fi

if [[ ! -f ${gpgconf} ]] ; then fail "GnuPG config is not available" ; fi

if [[ ! -d "${safedir}" ]] ; then mkdir -p "${safedir}" ; fi

chmod -R 0600 "${safeix}"  2>/dev/null
chmod -R 0700 "${safedir}" 2>/dev/null

password=""
action=""
if [[ -n "${1+x}" ]] ; then action="${1}" ; fi

while [[ -z "${action}" ]] ; do
  read -r -n 1 -p "
  Read or Write (or Help for more options): " action
  printf "\n"
done

if [[ "${action}" =~ ^([hH])$ ]] ; then
  print_help

elif [[ "${action}" =~ ^([bB])$ ]] ; then
  backup

elif [[ "${action}" =~ ^([lL])$ ]] ; then
  list_entry

elif [[ "${action}" =~ ^([wW])$ ]] ; then
  new_entry "$@"
  write_pass

  if [[ "${daily_backup}" = "true" ]] ; then
    if [[ ! -f ${backuptar} ]] ; then
      backup
    fi
  fi

else read_pass "$@" ; fi

chmod -R 0400 "${safeix}" "${safedir}" 2>/dev/null

tput setaf 2 ; printf "\nDone\n" ; tput sgr0
