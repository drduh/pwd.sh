#!/usr/bin/env bash
# https://github.com/drduh/pwd.sh/blob/master/pwd.sh

#set -x  # uncomment to debug
set -o errtrace
set -o nounset
set -o pipefail

umask 077
export LC_ALL="C"

read -r now today <<< "$(date +'%s %F')"

gpgExec="$(command -v gpg || command -v gpg2)"
gpgArgs=("--armor" "--batch")
gpgPath="${HOME}/.gnupg"
gpgConf="${gpgPath}/gpg.conf"

vers="v4"
name="${0##*/}"
app="${vers}-${name}"

backupFname="${app}.$(hostname).${today}.tar"
backupStore="${PWDSH_BACKUP_NAME:=${backupFname}}"

secretStore="${PWDSH_STORE:=${app}.secret}" # secrets storage directory
secretIndex="${PWDSH_INDEX:=${app}.index}"  # secrets index file
secretPepper="${PWDSH_PEPPER:=}"            # optional pepper file

clipCmd="${PWDSH_CLIP_CMD:=xclip}"     # clipboard, 'pbcopy' on macOS
clipArg="${PWDSH_CLIP_ARG:=}"          # args to pass to clip command
clipOut="${PWDSH_CLIP_OUT:=clipboard}" # cb type, 'screen' for stdout
clipSec="${PWDSH_CLIP_SEC:=10}"        # seconds until clipboard clear

optCopyBeforeWrite="${PWDSH_COPY:=}"  # copy secret before write
optDictionaryWords="${PWDSH_DICT:=/usr/share/dict/words}"
optPublicComment="${PWDSH_COMMENT:=}" # public/plaintext file comment
optSecretEchoChars="${PWDSH_ECHO:=*}" # echo "*" when typing passwords
optSecretLength="${PWDSH_LEN:=20}"    # default secret length
optSecretChars="${PWDSH_CHAR:='A-Za-z0-9!@#$%^&*()_+'}"
optRandSrc="${PWDSH_RANDSRC:=/dev/urandom}"

timestamp() { # Format current date and time.
  date +"%A %b %d %H:%M:%S"
}

log() { # Print formatted and timestamped events.
  local color="${1}"
  shift
  tput setaf "${color}"
  printf '(%s) %s\n' "$(timestamp)" "$*"
  tput sgr0
}

fail()  { log 1 "$@"; exit 1; }
final() { log 2 "$@"; exit 0; }
warn()  { log 3 "$@"; }

generatePepper() { # Generate, display and save "pepper" value.
  warn "Created '${secretPepper}' - copy to secure storage:"
  printf '%s\n' \
    "$(tr -dc 'A-Y2-9' < "${optRandSrc}" | tr -d "IOS5UB" |
    fold -w 6 | paste -sd - - | head -c 27)" |
    tee "${secretPepper}" || fail "Failed saving ${secretPepper}"
}

promptPassword() { # Prompt for a password.
  password=""
  prompt="${1}"

  while IFS= read -p "${prompt}" -r -s -n 1 char ; do
    if [[ ${char} == $'\0' ]] ; then break
    elif [[ ${char} == $'\177' ]] ; then
      if [[ -z "${password}" ]] ; then prompt=""
      else
        prompt=$'\b \b'
        password="${password%?}" ; fi
    else
      prompt="${optSecretEchoChars}"
      password+="${char}" ; fi
  done

  printf '\n'
}

decrypt() { # Decrypt with GPG.
  printf '%s' "${1}${pepperSecret}" |
    ${gpgExec} "${gpgArgs[@]}" \
    --decrypt --no-symkey-cache \
    --passphrase-fd 0 "${2}" 2>/dev/null
}

encrypt() { # Encrypt with GPG.
  ${gpgExec} "${gpgArgs[@]}" \
    --yes --symmetric \
    --comment "${optPublicComment}" \
    --passphrase-fd 3 \
    --output "${2}" "${3}" \
    3< <(printf '%s' "${1}${pepperSecret}") 2>/dev/null
}

readSecret() { # Decrypt to read a secret.
  verifyIndex

  while [[ -z "${username}" ]] ; do
    if [[ -z "${2+x}" ]] ; then read -r -p \
      "Username: " username
    else username="${2}" ; fi
  done

  promptPassword "Password to access ${secretIndex}: "

  local sline=$(decrypt "${password}" "${secretIndex}" |
    grep -F "${username}" | tail -1)
  if [[ -z "${sline}" ]] ; then
    fail "Secret not available"
  fi

  local spath="${secretStore}/${sline#*"${secretStore}"}"
  revealSecret <(decrypt "${password}" "${spath}") ||
    fail "Failed to decrypt ${spath}"
}

generateSecret() { # Generate a random string.
  if [[ -z "${3+x}" ]] ; then read -r -p \
    "Secret length (Enter for ${optSecretLength}): " length
  else length="${3}" ; fi

  if [[ "${length}" =~ ^[0-9]+$ ]] ; then
    optSecretLength="${length}" ; fi

  tr -dc "${optSecretChars}" < "${optRandSrc}" |
    head -c "${optSecretLength}"
}

generateUsername() { # Generate a random username.
  local countDigits=3
  local countWords=2
  local digits="$(tr -dc '0-9' < "${optRandSrc}" | head -c ${countDigits})"
  local words="$(awk 'length > 2 && length < 12 &&
    index($0, "'"'"'") == 0 { print tolower($0) }' \
    "${optDictionaryWords}" | sort -R |
    head -n ${countWords} | tr '\n' '-' | tr -cd 'a-z0-9-\n')"
  printf '%s%s' "${words}" "${digits}"
}

saveSecret() { # Write encrypted secret and update index.
  local sname="$(tr -dc 'a-z' < ${optRandSrc} | head -c 10)"
  local spath="${secretStore%/}/${sname}"

  if [[ -n "${optCopyBeforeWrite}" ]] ; then
    revealSecret <(printf '%s' "${userpass}") ; fi

  promptPassword "Password to access ${secretIndex}: "

  printf '%s\n' "${userpass}" |
    encrypt "${password}" "${spath}" - ||
      fail "Failed saving ${spath}"

  { if [[ -s "${secretIndex}" ]]; then
      decrypt "${password}" "${secretIndex}" || return
    fi
    printf '%s@%s:%s\n' "${username}" "${now}" "${spath}"
  } | encrypt "${password}" "${secretIndex}.${now}" -

  if ! mv "${secretIndex}.${now}" "${secretIndex}"; then
    fail "Failed saving ${secretIndex}.${now}" ; fi
}

listSecrets() { # Decrypt the index to list secrets.
  verifyIndex
  promptPassword "Password to access ${1}: "
  decrypt "${password}" "${1}" || fail "${1} not available"
}

backup() { # Archive index, secret store and GPG configuration.
  if [[ -s "${backupStore}" ]] ; then
    fail "Backup failed: '${backupStore}' exists" ; fi

  if [[ ! -s "${secretIndex}" ]] ; then
    fail "Backup failed: no secrets in '${secretIndex}'" ; fi

  if ! find "${secretStore}" -mindepth 1 -print -quit |
    grep -q "." ; then
    fail "Backup failed: no secrets in '${secretStore}'" ; fi

  local gpgConfCopy="${app}.gpg.conf"
  cp "${gpgConf}" "${gpgConfCopy}"

  local -a backupContent=(
    "${secretStore}" "${secretIndex}"
    "${gpgConfCopy}" "${BASH_SOURCE[0]}")
  tar cvf "${backupStore}" -- "${backupContent[@]}" ||
    fail "Failed archiving to ${backupStore}"
}

revealSecret() { # Reveal secret and clear after timeout.
  if [[ "${clipOut}" = "screen" ]] ; then
    printf '\n%s\n' "$(cat "${1}")"
  else ${clipCmd} < "${1}" ; fi

  printf '\n'
  while [[ "${clipSec}" -gt 0 ]] ; do
    printf '\r\033[KSecret on %s - clearing in %.d' \
      "${clipOut}" "$((clipSec--))"
    sleep 1
  done

  printf '\r\033[KClearing password from %s ...' \
    "${clipOut}"

  if [[ "${clipOut}" = "screen" ]] ; then
    clear
  else printf '\n' ; printf '' | ${clipCmd} ; fi
}

makeSecret() { # Prompt for username and password.
  if [[ -z "${2+x}" ]] ; then read -r -p \
    "Username (Enter to generate): " username
  else username="${2}" ; fi

  if [[ -z "${username}" ]] ; then
    username=$(generateUsername "$@") ; fi

  if [[ -z "${3+x}" ]] ; then
    promptPassword "Secret for '${username}' (Enter to generate): "
    userpass="${password}" ; fi

  if [[ -z "${password}" ]] ; then
    userpass=$(generateSecret "$@") ; fi
}

verifyIndex() { # Verify the index file exists and is non-empty.
  [[ -s "${secretIndex}" ]] || fail "${secretIndex} not found"
}

printHelp() { # Print available script options.
  printf '%s\n' "Available options:
  w - write (create) a secret
  r - read (access) a secret
  l - list secret names and paths
  s - generate a random secret
  u - generate a random username
  b - archive materials for backup
  v - print version information
  h - print help text

  ./pwd.sh w userName 20      - Write 20-char secret for 'userName'
  ./pwd.sh r userName         - Read latest secret for 'userName'
  ./pwd.sh r user1@1574723625 - Read version of secret for 'user1'"
}

printMenu() { # Print interactive menu.
  printf '%s\n' "Secrets"
  printf '  [%s] %-12s[%s] %-12s[%s] %s\n' \
         "W" "Write" "R" "Read" "L" "List"
  printf '\n%s\n' "Generate"
  printf '  [%s] %-12s[%s] %s\n' "S" "Secret" "U" "Username"
  printf '\n%s\n' "Backup"
  printf '  [%s] %s\n' "B" "Archive materials"
  printf '\n%s\n' "Info"
  printf '  [%s] %-12s[%s] %s\n\n' "V" "Version" "H" "Help"
}

initGnuPG() { # Fail if GnuPG materials are not available.
  [[ -n "${gpgExec}" ]] || fail "GnuPG binary not available"
  [[ -s "${gpgConf}" ]] || fail "GnuPG config not available"
}

initStorage() { # Create secret store and set permissions.
  if [[ ! -d "${secretStore}" ]] ; then
    mkdir -p "${secretStore}" ; fi
}

initPepper() { # Generate or load "pepper", if configured.
  pepperSecret=""
  if [[ -n "${secretPepper}" &&
      ! -s "${secretPepper}" ]] ; then generatePepper ; fi
  if [[ -s "${secretPepper}" ]] ; then
    pepperSecret="$(cat "${secretPepper}")" ; fi
}

initClipboard() { # Set up clipboard with optional args.
  if ! command -v "${clipCmd}" >/dev/null 2>&1; then
    clipOut="screen"
    warn "Clipboard not available -" \
         "secrets will appear on screen/stdout!"
  elif [[ -n "${clipArg}" ]] ; then
    clipCmd+=" ${clipArg}" ; fi
}

initOps() {
  initGnuPG
  initStorage
  initPepper
  initClipboard
}

activity=""
if [[ -n "${1+x}" ]] ; then activity="${1}" ; fi

while [[ -z "${activity}" ]] ; do
  printMenu
  read -n 1 -r -p "Select an option: " activity
  printf '\n'
done

case "${activity}" in
  [Hh]|[Uu]|[Ss]|[Vv]|[Rr]|[Ll]|[Ww]|[Bb]) : ;;
  *) fail "Invalid option selected" ;;
esac

case "${activity}" in
  [Hh]) final "$(printHelp)" ;;
  [Uu]) final "Username: $(generateUsername)" ;;
  [Ss]) final "Secret: $(generateSecret "$@")" ;;
  [Vv]) final "${app} - bash ${BASH_VERSION}" ;;
esac

initOps

username=""
password=""

case "${activity}" in
  [Rr]) readSecret "$@"
        final "Read secret" ;;
  [Ll]) listSecrets "${secretIndex}"
        final "Listed secrets" ;;
  [Ww]) makeSecret "$@"
        saveSecret
        final "Saved secret" ;;
  [Bb]) backup
        final "Archived ${backupStore}" ;;
esac
