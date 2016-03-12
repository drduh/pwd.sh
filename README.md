# pwd.sh

Script to manage passwords in an encrypted file using gpg.

![screencast gif](https://i.imgur.com/sQoF3VN.gif)

# Installation

    git clone https://github.com/drduh/pwd.sh && cd pwd.sh

Requires `gpg`. Install with `brew install gpg` or `sudo apt-get install gnupg` or build and install it from [source](https://www.gnupg.org/download/index.html).

# Use

Run the script interactively using `./pwd.sh` or symlink to a folder in `$PATH` and run directly.

Type `w` to write a password.

Type `r` to read a password.

Type `d` to delete a password.

Options can also be passed on the command line.

Create password with length of 30 characters for *gmail*:

    ./pwd.sh w gmail 30

Append `<space>q` to suppress generated password output.

Read password for *user@github*:

    ./pwd.sh r user@github

Delete password for *dropbox*:

    ./pwd.sh d dropbox

Copy password for *github* to clipboard on OS X:

    ./pwd.sh r github | cut -f 1 -d ' ' | awk 'NR==3{print $1}' | pbcopy

The script and `pwd.sh.safe` encrypted file can be safely shared between computers, for example through Google Drive or Dropbox.

A recommended `~/.gnupg/gpg.conf` configuration is included in this repository.

# Similar software

[Pass: the standard unix password manager](http://www.passwordstore.org/)

[caodonnell/passman.sh: a pwd.sh fork](https://github.com/caodonnell/passman.sh)

[bndw/pick: a minimal password manager for OS X and Linux](https://github.com/bndw/pick)

[anders/pwgen: generate passwords using OS X Security framework](https://github.com/anders/pwgen)

