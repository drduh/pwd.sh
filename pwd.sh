#!/bin/bash
#
# pwd.sh
#
# An interface to gpg for managing passwords.

#set -o errexit
#set -o xtrace
set -o pipefail
set -o nounset

safe=pwd.sh.safe
public=pwd.sh.pub
secret=pwd.sh.sec

del=/usr/bin/srm
del_opts=("--force --zero")

gpg=/usr/local/bin/gpg
gpg_opts=("--no-default-keyring --keyring ./${public} --secret-keyring ./${secret}")

name="nobody@pwd.sh"


get_pass () {
  # Fancy prompt for fetching a password.

  unset password
  prompt="Password: "
  while IFS= read -p "$prompt" -r -s -n 1 char
  do
      if [[ $char == $'\0' ]] ; then
          break
      fi
      prompt='*'
      password+="$char"
  done
}


decrypt () {
  # Decrypt a gpg-encrypted file with a password.

  ${gpg} ${gpg_opts} \
    --decrypt --armor --batch \
    --command-fd 0 --passphrase "${1}" "${2}" \
    2>/dev/null
}


encrypt () {
  # Encrypt and sign a file with a password.

  ${gpg} ${gpg_opts} \
    --encrypt --armor --sign --batch \
    --hidden-recipient "${name}" \
    --yes \
    --command-fd 0 --passphrase "${1}" \
    --output "${2}" "${3}" \
    2>/dev/null
}


read_pass () {
  # Reads a password.

  if [ ! -s ${safe} ] ; then
    echo "Empty safe, no passwords!"
    exit 3
  else
    echo "Enter password for ${safe}."
    get_pass ; echo
    decrypt ${password} ${safe}
  fi
}


write_pass () {
  # Writes a password.

  read -p "Username/ID: " id
  read -p "Create random password? (y/n default: y) " rand_pass
  if [ "${rand_pass}" == "n" ]; then
    echo "Choose a password for '${id}'."
    get_pass ; echo
    user_pass=$password
  else
    user_pass=$(gen_pass)
  fi

  echo "Enter password for ${safe}."
  get_pass ; echo

  tmp_secret=$(mktemp -q /tmp/pwd.sh.XXXXXX)
  if [ -s ${safe} ] ; then
    decrypt ${password} ${safe} | grep -v " ${id}" > ${tmp_secret}
  fi
  echo "${user_pass} ${id}" >> ${tmp_secret}
  encrypt ${password} ${safe} ${tmp_secret}
  ${del} ${del_opts} ${tmp_secret}

  echo "Wrote password for '${id}' to ${safe}."
}


gen_pass () {
  # Generate a random password.

  read -p "Password length? (min/avg/max default: max) " pass_length
  if [ "$pass_length" == "min" ]; then
    len=6
  elif [ "$pass_length" == "avg" ]; then
    len=12
  else
    len=24
  fi

  ${gpg} --gen-random -a 0 ${len}
}


create_keys () {
  # Create public and private GnuPG keys.

    echo "Choose a strong master password."
    get_pass ; echo
    key_pass=$password

    ${gpg} ${gpg_opts} \
      --gen-key --batch <(
        cat <<EOF
Key-Type: RSA
Key-Length: 4096
Expire-Date: 0
Name-Real: ${name}
Passphrase: ${key_pass}
%commit
EOF
) 2>/dev/null

  echo "Created keys: ${public} and ${secret}."
}


create_safe () {
  # Create an encrypted "safe" file to store passwords.

  touch ${safe} ; chmod 0600 ${safe}
  echo "Created encrypted safe file: ${safe}."
}


sanity_check () {
  # Make sure all necessary programs are installed and files exist.

  if [ ! -x ${gpg} ] ; then
    echo "GnuPG is not available!"
    exit 127
  fi

  if [ ! -x ${del} ] ; then
    echo "srm/rm is not available!"
    exit 127
  fi

  if [ ! -f ${secret} ] ; then
    echo "No keys found, creating new keys ..."
    create_keys
  else
    chmod 0600 ${secret}
  fi

  if [ ! -f ${safe} ] ; then
    echo "No safe found, creating new safe file ..."
    create_safe
  else
    chmod 0600 ${safe}
  fi
}


main () {
  # Main function.

  sanity_check

  read -p "Read or write a password? (r/w default: r) " action
  if [ "${action}" == "w" ] ; then
    write_pass
  else
    read_pass
  fi
}


main

exit 0

