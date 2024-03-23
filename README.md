pwd.sh is a Bash shell script to manage passwords and other text-based secrets.

It uses GnuPG to symmetrically (i.e., using a master password) encrypt and decrypt plaintext files.

Each password is encrypted as a unique, randomly-named file in the "safe" directory. An encrypted index is used to map usernames to the respective password file. Both the index and password files can also be decrypted directly with GnuPG without this script.

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

Variable | Description | Default | Values
-|-|-|-
`PWDSH_TIME` | seconds to clear password from clipboard/screen | `10` | any valid integer
`PWDSH_LEN` | default generated password length | `14` | any valid integer
`PWDSH_COPY` | copy password to clipboard before write | unset (disabled) | `1` or `true` to enable
`PWDSH_DAILY` | create daily backup archive on write | unset (disabled) | `1` or `true` to enable
`PWDSH_COMMENT` | **unencrypted** comment to include in index and safe files | unset | any valid string
`PWDSH_DEST` | password output destination, will set to `screen` without clipboard | `clipboard` | `clipboard` or `screen`
`PWDSH_SAFE` | safe directory name | `safe` | any valid string
`PWDSH_INDEX` | index file name | `pwd.index` | any valid string
`PWDSH_BACKUP` | backup archive file name | `pwd.$hostname.$today.tar` | any valid string

See [config/gpg.conf](https://github.com/drduh/config/blob/master/gpg.conf) for additional GnuPG options.

Also see [drduh/Purse](https://github.com/drduh/Purse) - a fork which integrates with [YubiKey](https://github.com/drduh/YubiKey-Guide) instead of using a master password.
