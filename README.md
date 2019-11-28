pwd.sh is a Bash shell script to manage passwords and other secrets.

It uses GnuPG to symmetrically (i.e., using a master password) encrypt and decrypt plain text files.

[drduh/Purse](https://github.com/drduh/Purse) is a fork which uses public key authentication instead of a master password and can integrate with YubiKey.

# Release notes

## Version 1 (2015)

The original release which has been available for general use and review since July 2015. There are no known bugs nor security vulnerabilities identified in this stable version of pwd.sh. Compatible on Linux, OpenBSD, macOS.

## Version 2b (2019)

The second release of pwd.sh features several security and reliability improvements, and is an optional upgrade. Currently in beta testing. Compatible on Linux, OpenBSD, macOS.

Changelist:
* Passwords are now encrypted as individual files, rather than all encrypted as a single flat file.
* Individual password filenames are random, mapped to usernames in an encrypted index file.
* Index and password files are now "immutable" using chmod while pwd.sh is not running.
* Read passwords are now copied to clipboard and cleared after a timeout, instead of printed to stdout.
* Use printf instead of echo for improved portability.
* New option: list passwords in the index.
* New option: create tar archive for backup.
* Removed option: delete password; the index is now a permanent ledger.
* Removed option: read all passwords; no use case for having a single command.
* Removed option: suppress generated password output; should be read from safe to verify save.

# Use

```console
$ git clone https://github.com/drduh/pwd.sh
```

`cd pwd.sh` and run the script interactively using `./pwd.sh` or symlink to a directory in `PATH`:

* Type `w` to write a password
* Type `r` to read a password
* Type `l` to list passwords
* Type `b` to create an archive for backup
* Type `h` to print the help text

Options can also be passed on the command line.

Example usage:

Create a 30-character password for `userName`:

```console
$ ./pwd.sh w userName 30
```

Read password for `userName`:

```console
$ ./pwd.sh r userName
```

Passwords are stored with a timestamp for revision control. The most recent version is copied to clipboard on read. To list all passwords or read a previous version of a password:

```console
$ ./pwd.sh l

$ ./pwd.sh r userName@1574723600
```

Create an archive for backup:

```console
$ ./pwd.sh b
```

Restore an archive from backup:

```console
$ tar xvf pwd*tar""
```

The backup contains only encrypted files and can be publicly shared for use on trusted computers.

See [drduh/config/gpg.conf](https://github.com/drduh/config/blob/master/gpg.conf) for additional GPG configuration options.

# Similar software

* [drduh/Purse](https://github.com/drduh/Purse)
* [Pass: the standard unix password manager](https://www.passwordstore.org/)
* [caodonnell/passman.sh: a pwd.sh fork](https://github.com/caodonnell/passman.sh)
* [bndw/pick: command-line password manager for macOS and Linux](https://github.com/bndw/pick)
* [anders/pwgen: generate passwords using OS X Security framework](https://github.com/anders/pwgen)
