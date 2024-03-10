pwd.sh is a Bash shell script to manage passwords and other secrets.

It uses GnuPG to symmetrically (i.e., using a master password) encrypt and decrypt plaintext files.

[drduh/Purse](https://github.com/drduh/Purse) is a fork which uses public key authentication instead of a master password and can integrate with YubiKey.

# Release notes

See [Releases](https://github.com/drduh/pwd.sh/releases)

# Use

Clone the repository:

```console
git clone https://github.com/drduh/pwd.sh

```

Or download the script directly:

```console
wget https://raw.githubusercontent.com/drduh/pwd.sh/master/pwd.sh
```

Run the script interactively using `./pwd.sh` or symlink to a directory in `PATH`:

* Type `w` to write a password
* Type `r` to read a password
* Type `l` to list passwords
* Type `b` to create an archive for backup
* Type `h` to print the help text

Options can also be passed on the command line.

Create a 20-character password for `userName`:

```console
./pwd.sh w userName 20
```

Read password for `userName`:

```console
./pwd.sh r userName
```

Passwords are stored with a timestamp for revision control. The most recent version is copied to clipboard on read. To list all passwords or read a specific version of a password:

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

See [config/gpg.conf](https://github.com/drduh/config/blob/master/gpg.conf) for additional configuration options.
