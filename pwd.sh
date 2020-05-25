#!/usr/bin/env bash
# https://github.com/drduh/pwd.sh

set -o errtrace
set -o nounset
set -o pipefail

#set -x # uncomment to debug

umask 077

now=$(date +%s)
copy="$(command -v xclip || command -v pbcopy)"
gpg="$(command -v gpg || command -v gpg2)"
gpgconf="${HOME}/.gnupg/gpg.conf"
backuptar="${PWDSH_BACKUP:=pwd.$(hostname).$(date +%F).tar}"
safeix="${PWDSH_INDEX:=pwd.index}"
safedir="${PWDSH_SAFE:=safe}"
script="$(basename $BASH_SOURCE)"
timeout=10

fail () {
  # Print an error message and exit.

  tput setaf 1 1 1 ; printf "\nError: %s\n" "${1}" ; tput sgr0
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

  printf "%s\n" "${1}" | ${gpg} --armor --batch --no-symkey-cache \
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

  len=20
  max=80

  if [[ -z "${3+x}" ]] ; then read -r -p "
  Password length (default: ${len}, max: ${max}): " length
  else length="${3}" ; fi

  if [[ ${length} =~ ^[0-9]+$ ]] ; then len=${length} ; fi

  # base64: 4 characters for every 3 bytes
  ${gpg} --armor --gen-random 0 "$((max * 3 / 4))" | cut -c -"${len}"
}

write_pass () {
  # Write a password and update index file.

  password=""
  while [[ -z "${password}" ]] ; do get_pass "
  Password to unlock ${safeix}: " ; done
  printf "\n"

  fpath=$(tr -dc "[:lower:]" < /dev/urandom | fold -w8 | head -n1)
  spath=${safedir}/${fpath}
  printf '%s\n' "${userpass}" | \
    encrypt "${password}" "${spath}" - || \
      fail "Failed to put ${spath}"

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

  decrypt ${password} "${safeix}" || fail "Decryption failed"
}

backup () {
  # Archive encrypted index and safe directory.

  if [[ -f "${safeix}" && -d "${safedir}" ]] ; then \
    cp "${gpgconf}" "gpg.conf.${now}"
    tar cfv "${backuptar}" \
      "${safeix}" "${safedir}" "gpg.conf.${now}" "${script}"
    rm "gpg.conf.${now}"
  else fail "Nothing to archive" ; fi

  printf "\nArchived %s\n" "${backuptar}" ; \
}

clip () {
  # Use clipboard and clear after timeout.

  ${copy} < "${1}"

  printf "\n"
  shift
  while [ $timeout -gt 0 ] ; do
    printf "\r\033[KPassword on clipboard! Clearing in %.d" $((timeout--))
    sleep 1
  done

  printf "" | ${copy}
}

new_entry () {
  # Prompt for new username and/or password.

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
  if [[ -z "${password}" ]] ; then userpass=$(gen_pass "$@") ; fi
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

    * List stored passwords and copy a previous version:
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
  read -n 1 -p "
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

else read_pass "$@" ; fi

chmod -R 0400 "${safeix}" "${safedir}" 2>/dev/null

tput setaf 2 2 2 ; printf "\nDone\n" ; tput sgr0
