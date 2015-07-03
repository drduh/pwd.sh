#!/bin/bash
#
# Script for managing passwords in a symmetrically encrypted file using GnuPG.

set -o errtrace
set -o nounset
set -o pipefail

gpg=$(which gpg)
safe=${PWDSH_SAFE:=pwd.sh.safe}


fail () {
  # Print an error message and exit.

  tput setaf 1 ; echo "Error: ${1}"
  exit 1
}


get_pass () {
  # Prompt for a password.

  unset password
  prompt="${1}"
  while IFS= read -p "${prompt}" -r -s -n 1 char ; do
      if [[ ${char} == $'\0' ]] ; then
        break
      fi
      prompt='*'
      password+="${char}"
  done

  if [ -z ${password+x} ] ; then
    fail "No password provided"
  fi
}


decrypt () {
  # Decrypt with a password.

  ${gpg} \
    --decrypt --armor --batch \
    --command-fd 0 --passphrase "${1}" "${2}" 2>/dev/null
}


encrypt () {
  # Encrypt with a password.

  ${gpg} \
    --symmetric --armor --batch --yes \
    --command-fd 0 --passphrase "${1}" \
    --output "${2}" "${3}" 2>/dev/null
}


read_pass () {
  # Read a password from safe.

  if [[ -z ${username} || ${username} == "all" ]] ; then
    username=""
  fi

  if [ ! -s ${safe} ] ; then
    fail "No passwords found"
  else
    get_pass "Enter password to unlock ${safe}: " ; echo
    decrypt ${password} ${safe} | grep " ${username}" || fail "Decryption failed"
  fi
}


gen_pass () {
  # Generate a password.

  len=40
  read -p "Password length? (default: 40, max: 100) " length

  if [[ ${length} =~ ^[0-9]+$ ]] ; then
    len=${length}
  fi

  # base64: 4 characters for every 3 bytes
  ${gpg} --gen-random -a 0 75 | cut -c -${len}
}


write_pass () {
  # Write a password in safe.

  # If no password provided, clear the entry by writing an empty line.
  if [ -z ${userpass+x} ] ; then
    new_entry=" "
  else
    new_entry="${userpass} ${username}"
  fi

  get_pass "Enter password to unlock ${safe}: " ; echo

  # If safe exists, decrypt it and filter out username, or bail on error.
  # If successful, append new entry, or blank line.
  # Filter out any blank lines.
  # Finally, encrypt it all to a new safe file, or fail.
  # If successful, update to new safe file.
  ( if [ -f ${safe} ] ; then
      decrypt ${password} ${safe} | \
      grep -v -e " ${username}$" || return
    fi ; \
    echo "${new_entry}") | \
    grep -v -e "^[[:space:]]*$" | \
    encrypt ${password} ${safe}.new - || fail "Write to safe failed"
    mv ${safe}.new ${safe}
}


create_username () {
  # Create a new username and password.

  read -p "Username: " username
  read -p "Generate password? (y/n, default: y) " rand_pass
  if [ "${rand_pass}" == "n" ]; then
    get_pass "Enter password for \"${username}\": " ; echo
    userpass=$password
  else
    userpass=$(gen_pass)
    echo "Password: ${userpass}"
  fi
}


sanity_check () {
  # Make sure required programs are installed and can be executed.

  if [[ -z ${gpg} && ! -x ${gpg} ]] ; then
    fail "GnuPG is not available"
  fi
}


sanity_check

read -p "Read, write, or delete a password? (r/w/d, default: r) " action

if [ "${action}" == "w" ] ; then
  create_username && write_pass
elif [ "${action}" == "d" ] ; then
  read -p "Username to delete? " username
  write_pass
else
  read -p "Username to read? (default: all) " username
  read_pass
fi

tput setaf 2 ; echo "Done"

