# pwd.sh

Script to manage passwords in an encrypted file using gpg.

![screencast gif](https://i.imgur.com/sQoF3VN.gif)

**New!** [drduh/Purse](https://github.com/drduh/Purse) is a fork which uses public key authentication instead of a master passphrase and can integrate with YubiKey.

# Installation

```console
$ git clone https://github.com/drduh/pwd.sh
```

# Use

`cd pwd.sh` and run the script interactively using `./pwd.sh`

* Type `w` to write a password.
* Type `r` to read a password.
* Type `d` to delete a password.
* Type `h` to print the help text.

Options can also be passed on the command line.

Examples:

Create 30-character password for `gmail`:

```console
$ ./pwd.sh w gmail 30
```

Append `q` to create a password without displaying it.

Read password for `user@github`:

```console
$ ./pwd.sh r user@github
```

Delete password for `dropbox`:

```console
$ ./pwd.sh d dropbox
```

Copy password for `github` to clipboard (substitute `pbcopy` on macOS):

```console
$ ./pwd.sh r github | cut -f 1 -d ' ' | awk 'NR==3{print $1}' | xclip
```

The script and encrypted `pwd.sh.safe` file can be publicly shared between trusted computers.

See [drduh/config/gpg.conf](https://github.com/drduh/config/blob/master/gpg.conf) for additional GPG options.

# Similar software

* [drduh/Purse](https://github.com/drduh/Purse)
* [Pass: the standard unix password manager](https://www.passwordstore.org/)
* [caodonnell/passman.sh: a pwd.sh fork](https://github.com/caodonnell/passman.sh)
* [bndw/pick: command-line password manager for macOS and Linux](https://github.com/bndw/pick)
* [anders/pwgen: generate passwords using OS X Security framework](https://github.com/anders/pwgen)
