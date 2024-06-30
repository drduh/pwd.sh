pwd.sh is a Bash shell script to manage passwords and other text-based secrets.

It uses GnuPG to symmetrically (i.e., using a passphrase) encrypt and decrypt plaintext files.

Each password is encrypted individually as a randomly-named file in the "safe" directory. An encrypted index is used to map usernames to the respective password file. Both the index and password files can also be decrypted directly with GnuPG without this script.

# Install

For the latest version, clone the repository or download the script directly:

```console
git clone https://github.com/drduh/pwd.sh

wget https://raw.githubusercontent.com/drduh/pwd.sh/master/pwd.sh
```

Versioned [Releases](https://github.com/drduh/pwd.sh/releases) are also available.

# Use

Run the script interactively using `./pwd.sh` or symlink to a directory in `PATH`:

- `w` to write a password
- `r` to read a password
- `l` to list passwords
- `b` to create an archive for backup
- `h` to print the help text

Options can also be passed on the command line.

Create a 20-character password for `userName`:

```console
./pwd.sh w userName 20
```

Read password for `userName`:

```console
./pwd.sh r userName
```

Passwords are stored with an epoch timestamp for revision control. The most recent version is copied to clipboard on read. To list all passwords or read a specific version of a password:

```console
./pwd.sh l

./pwd.sh r userName@1574723600
```

Create an archive for backup:

```console
./pwd.sh b
```

Restore an archive from backup:

```console
tar xvf pwd*tar
```

# Configure

Several customizable options and features are also available, and can be configured with environment variables, for example in the [shell rc](https://github.com/drduh/config/blob/master/zshrc) file:

Variable | Description | Default | Available options
-|-|-|-
`PWDSH_CLIP` | clipboard to use | `xclip` | `pbcopy` on macOS
`PWDSH_CLIP_ARGS` | arguments to pass to clipboard command | unset (disabled) | `-i -selection clipboard` to use primary (control-v) clipboard with xclip
`PWDSH_TIME` | seconds to clear password from clipboard/screen | `10` | any valid integer
`PWDSH_LEN` | default password length | `14` | any valid integer
`PWDSH_COPY` | copy password to clipboard before write | unset (disabled) | `1` or `true` to enable
`PWDSH_DAILY` | create daily backup archive on write | unset (disabled) | `1` or `true` to enable
`PWDSH_CHARS` | character set for passwords | `[:alnum:]!?@#$%^&*();:+=` | any valid characters
`PWDSH_COMMENT` | **unencrypted** comment to include in index and safe files | unset | any valid string
`PWDSH_DEST` | password output destination, will set to `screen` without clipboard | `clipboard` | `clipboard` or `screen`
`PWDSH_ECHO` | character used to echo password input | `*` | any valid character
`PWDSH_SAFE` | safe directory name | `safe` | any valid string
`PWDSH_INDEX` | index file name | `pwd.index` | any valid string
`PWDSH_BACKUP` | backup archive file name | `pwd.$hostname.$today.tar` | any valid string
`PWDSH_PEPPER` | file containing "pepper" value, see [Detail 1](#Details#1) | unset (disabled) | any valid file path

See [config/gpg.conf](https://github.com/drduh/config/blob/master/gpg.conf) for additional GnuPG options.

Also see [drduh/Purse](https://github.com/drduh/Purse) - a fork which integrates with [YubiKey](https://github.com/drduh/YubiKey-Guide) instead of using a passphrase.

# Details

1. The ["pepper"](https://en.wikipedia.org/wiki/Pepper_(cryptography)) is an additional string appended to the main passphrase to improve its strength. When the `PWDSH_PEPPER` option is enabled, a secret value is generated and displayed once, then saved to the respective file.

    The pepper should be written down (can be transcribed with either [passphrase.html](https://github.com/drduh/YubiKey-Guide/blob/master/passphrase.html) or [passphrase.csv](https://raw.githubusercontent.com/drduh/YubiKey-Guide/master/passphrase.csv) template) and stored in a durable location for backup.

    It is the opinion of the author this feature allows the use of a more memorable, weaker main passphrase without compromising overall security, provided the pepper is backed up separately from the safe.

    **Warning** The pepper file is **not** included in backup archives - without the pepper, the safe will **not** be accessible with the main passphrase alone! This feature is opt-in and the pepper has no effect unless explicitly enabled.
