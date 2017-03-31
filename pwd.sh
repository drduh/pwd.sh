#!/usr/bin/env bash

set -o errtrace
set -o nounset
set -o pipefail

filter="$(command -v grep) -v -E"
gpg="$(command -v gpg || command -v gpg2)"
safe="${PWDSH_SAFE:=pwd.sh.safe}"


fail () {
  # Print an error message and exit.

  printf "\n\n"
  tput setaf 1 1 1 ; echo "Error: ${1}" ; tput sgr0
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
  # Decrypt with a password.

  echo "${1}" | ${gpg} --armor --batch \
    --decrypt --passphrase-fd 0 "${2}" 2>/dev/null
}


encrypt () {
  # Encrypt with a password.

  ${gpg} --armor --batch \
    --symmetric --yes --passphrase-fd 3 \
    --output "${2}" "${3}" 3< <(echo "${1}")
}


read_pass () {
  # Read a password from safe.

  if [[ ! -s ${safe} ]] ; then fail "No password safe found" ; fi

  if [[ -z "${2+x}" ]] ; then read -r -p "
  Username (Enter for all): " username
  else
    username="${2}"
  fi

  if [[ -z "${username}" || "${username}" == "all" ]] ; then username="" ; fi

  while [[ -z "${password}" ]] ; do get_pass "
  Password to unlock ${safe}: " ; done
  printf "\n\n"

  decrypt ${password} ${safe} | grep -F " ${username}" \
    || fail "Decryption failed"
}


gen_pass () {
  # Generate a password.

  len=50
  max=100

  if [[ -z "${3+x}" ]] ; then read -p "

  Password length (default: ${len}, max: ${max}): " length
  else
    length="${3}"
  fi

  if [[ ${length} =~ ^[0-9]+$ ]] ; then len=${length} ; fi

  # base64: 4 characters for every 3 bytes
  ${gpg} --armor --gen-random 0 "$((${max} * 3/4))" | cut -c -"${len}"
 }


write_pass () {
  # Write a password in safe.

  # If no password (delete action), clear the entry by writing an empty line.
  if [[ -z "${userpass+x}" ]] ; then
    entry=" "
  else
    entry="${userpass} ${username}"
  fi

  get_pass "
  Password to unlock ${safe}: " ; echo

  # If safe exists, decrypt it and filter out username, or bail on error.
  # If successful, append entry, or blank line.
  # Filter blank lines and previous timestamp, append fresh timestamp.
  # Finally, encrypt it all to a new safe file, or fail.
  # If successful, update to new safe file.
  ( if [[ -f "${safe}" ]] ; then
      decrypt ${password} ${safe} | \
      ${filter} " ${username}$" || return
    fi ; \
    echo "${entry}") | \
    (${filter} "^[[:space:]]*$|^mtime:[[:digit:]]+$";echo mtime:$(date +%s)) | \
    encrypt ${password} ${safe}.new - || fail "Write to safe failed"
    mv ${safe}{.new,}
}


new_entry () {
  # Prompt for new username and/or password.

  if [[ -z "${2+x}" ]] ; then read -r -p "
  Username: " username
  else
    username="${2}"
  fi

  if [[ -z "${3+x}" ]] ; then get_pass "
  Password for \"${username}\" (Enter to generate): "
    userpass="${password}"
  fi

  if [[ -z "${password}" ]] ; then userpass=$(gen_pass "$@")
    if [[ -z "${4+x}" || ! "${4}" =~ ^([qQ])$ ]] ; then
      echo "
  Password: ${userpass}"
    fi
  fi
}

print_help () {
  # Print help text.

  echo "
  pwd.sh is a shell script to manage passwords with GnuPG symmetric encryption.

  The script can be run interactively as './pwd.sh' or with the following args:

    * 'r' to read a password
    * 'w' to write a password
    * 'd' to delete a password
    * 'h' to see this help text

  A username can be supplied as an additional argument or 'all' for all entries.

  For writing, a password length can be appended. Append 'q' to suppress output.

  Examples:

    * Read all passwords:

      ./pwd.sh r all

    * Write a password for 'github':

      ./pwd.sh w github

    * Generate a 50 character password for 'github' and write:

      ./pwd.sh w github 50

    * To suppress the generated password:

      ./pwd.sh w github 50 q

    * Delete password for 'mail':

      ./pwd.sh d mail

  A password cannot be supplied as an argument, nor is used as one throughout
  the script, to prevent it from appearing in process listing or logs.

  To report a bug, visit https://github.com/drduh/pwd.sh
  "
}


if [[ -z ${gpg} && ! -x ${gpg} ]] ; then fail "GnuPG is not available" ; fi

password=""

action=""
if [[ -n "${1+x}" ]] ; then
  action="${1}"
fi 

while [[ -z "${action}" ]] ;
  do read -n 1 -p "
  Read, Write, or Delete password (or Help): " action
  printf "\n"
done

if [[ "${action}" =~ ^([hH])$ ]] ; then
  print_help
elif [[ "${action}" =~ ^([wW])$ ]] ; then
  new_entry "$@"
  write_pass
elif [[ "${action}" =~ ^([dD])$ ]] ; then
  if [[ -z "${2+x}" ]] ; then read -p "
  Username: " username
  else
    username="${2}"
  fi
  write_pass
else
  read_pass "$@"
fi

printf "\n" ; tput setaf 2 2 2 ; echo "Done" ; tput sgr0
