pwd.sh is a Bash script to manage text secrets, such as passwords, using [GnuPG](https://gnupg.org/).

Each secret is saved to a randomly-named file in a directory. An encrypted index maps usernames to secrets contained in files. Both the index and files can be decrypted directly with GnuPG - without pwd.sh.

# Install

Download from [Releases](https://github.com/drduh/pwd.sh/releases), or to use the latest version, clone the repository:

```bash
git clone https://github.com/drduh/pwd.sh
```

Or download the script directly:

```bash
wget https://raw.githubusercontent.com/drduh/pwd.sh/main/pwd.sh
```

# Use

Run the script interactively using `./pwd.sh` or symlink to a directory in `PATH`:

- `w` - write (create) a secret
- `r` - read (access) a secret
- `l` - list secret names and paths
- `s` - generate a random secret
- `u` - generate a random username
- `b` - archive materials for backup
- `v` - print version information
- `h` - print help text

Options can also be passed on the command line.

Create a 20-character secret for `userName`:

```bash
./pwd.sh w userName 20
```

Read secret for `userName`:

```bash
./pwd.sh r userName
```

Secrets are stored with an epoch timestamp for revision control and the most recent version is read by default. To list all secrets or read a specific version of a secret:

```bash
./pwd.sh l
./pwd.sh r userName@1574723600
```

Create a backup tar archive:

```bash
./pwd.sh b
```

Restore from backup:

```bash
tar xvf pwd*tar
```

# Configure

pwd.sh can be configured with environment variables, for example using the [shell startup file](https://github.com/drduh/config/blob/main/zshrc):

Variable | Description | Default | Available options
:-: | :-: | :-: | :-:
`PWDSH_STORE` | secret storage directory | `app.store` | any valid string
`PWDSH_INDEX` | index file name | `pwd.index` | any valid string
`PWDSH_CLIP_CMD` | clipboard to use | `xclip` | `pbcopy` on macOS
`PWDSH_CLIP_ARG` | arguments to pass to clipboard command | unset (disabled) | `-i -selection clipboard` to use primary (control-v) clipboard with xclip
`PWDSH_CLIP_OUT` | secret output destination, will set to `screen` without clipboard | `clipboard` | `clipboard` or `screen`
`PWDSH_CLIP_SEC` | seconds to clear secret from clipboard/screen | `10` | any valid integer
`PWDSH_COPY` | copy secret to clipboard before write | unset (disabled) | `1` or `true` to enable
`PWDSH_COMMENT` | **unencrypted** comment to include in index and secret files | unset | any valid string
`PWDSH_ECHO` | character used to echo password input | `*` | any valid character
`PWDSH_LEN` | default secret length | `14` | any valid integer
`PWDSH_CHARS` | character set for secret | `[:alnum:]!?@#$%^&*();:+=` | any valid characters
`PWDSH_BACKUP_NAME` | backup archive file name | `pwd.$hostname.$today.tar` | any valid string
`PWDSH_PEPPER` | file containing [Pepper](#Pepper) | unset (disabled) | any valid file path

See [config/gpg.conf](https://github.com/drduh/config/blob/main/gpg.conf) for additional GnuPG options.

Also see [drduh/Purse](https://github.com/drduh/Purse) - a fork which integrates with [YubiKey](https://github.com/drduh/YubiKey-Guide) instead of using a passphrase.

# Pepper

The [Pepper](https://www.wikipedia.org/wiki/Pepper_(cryptography)) is an additional string appended to the storage passphrase to improve its strength. When the `PWDSH_PEPPER` option is set to a valid path, a secret value is generated and displayed once, then saved to the respective file.

The Pepper should be written down (for example, transcribed with [passphrase.html](https://raw.githubusercontent.com/drduh/YubiKey-Guide/main/templates/passphrase.html) or [passphrase.txt](https://raw.githubusercontent.com/drduh/YubiKey-Guide/main/templates/passphrase.txt) template) and stored in a secure, durable location for backup.

This feature may enable use of a more memorable - and possibly weaker passphrase - for convenience, while still guarding backups against passphrase brute-force attempts (provided the Pepper is backed up separately).

The Pepper feature is opt-in and has no effect unless explicitly enabled.

> [!WARNING]
> The Pepper is **not** included in backup archives! Without the Pepper, secret storage will **not** be accessible with the passphrase alone!
