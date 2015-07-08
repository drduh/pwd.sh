#!/usr/bin/env bash
#
# Script for managing passwords in a symmetrically encrypted file using GnuPG.

set -o errtrace
set -o nounset
set -o pipefail

gpg=$(command -v gpg || command -v gpg2)
safe=${PWDSH_SAFE:=pwd.sh.safe}


fail () {
  # Print an error message and exit.

  tput setaf 1 ; echo "Error: ${1}" ; tput sgr0
  exit 1
}


get_pass () {
  # Prompt for a password.

  password=''
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

  if [[ -z ${password} ]] ; then
    fail "No password provided"
  fi
}


decrypt () {
  # Decrypt with a password.

  echo "${1}" | ${gpg} \
    --decrypt --armor --batch \
    --passphrase-fd 0 "${2}" 2>/dev/null
}


encrypt () {
  # Encrypt with a password.


  ${gpg} \
    --symmetric --armor --batch --yes \
    --passphrase-fd 3 \
    --output "${2}" "${3}" 3< <(echo "${1}")
}


read_pass () {
  # Read a password from safe.

  if [[ -z ${username} || ${username} == "all" ]] ; then
    username=""
  fi

  if [[ ! -s ${safe} ]] ; then
    fail "No passwords found"
  else
    get_pass "
  Enter password to unlock ${safe}: "
    printf "\n\n"
    decrypt ${password} ${safe} | grep " ${username}" || fail "Decryption failed"
  fi
}


gen_pass () {
  # Generate a password.

  len=50
  max=100
  read -p "
  Password length? (default: ${len}, max: ${max}) " length

  if [[ ${length} =~ ^[0-9]+$ ]] ; then
    len=${length}
  fi

  # base64: 4 characters for every 3 bytes
  ${gpg} --gen-random -a 0 "$((${max} * 3/4))" | cut -c -${len}
}


write_pass () {
  # Write a password in safe.

  # If no password provided, clear the entry by writing an empty line.
  if [ -z ${userpass+x} ] ; then
    new_entry=" "
  else
    new_entry="${userpass} ${username}"
  fi

  get_pass "
  Enter password to unlock ${safe}: " ; echo

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

  read -p "
  Username: " username
  read -p "
  Generate password? (y/n, default: y) " rand_pass

  if [[ "${rand_pass}" =~ ^([nN][oO]|[nN])$ ]]; then
    get_pass "
  Enter password for \"${username}\": " ; echo
    userpass=$password
  else
    userpass=$(gen_pass)
    echo "
  Password: ${userpass}"
  fi
}


sanity_check () {
  # Make sure required programs are installed and can be executed.

  if [[ -z ${gpg} && ! -x ${gpg} ]] ; then
    fail "GnuPG is not available"
  fi
}


sanity_check

read -n 1 -p "Read, write, or delete password? (r/w/d, default: r) " action
printf "\n"

if [[ "${action}" =~ ^([wW])$ ]] ; then
  create_username && write_pass
elif [[ "${action}" =~ ^([dD])$ ]] ; then
  read -p "
  Username to delete? " username && write_pass
else
  read -p "
  Username to read? (default: all) " username && read_pass
fi

tput setaf 2 ; echo "
Done" ; tput sgr0

