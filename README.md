# pwd.sh

Script to manage passwords in an encrypted file using gpg.

![screencast gif](https://i.imgur.com/sQoF3VN.gif)

# Installation

    git clone https://github.com/drduh/pwd.sh && cd pwd.sh

Requires `gpg`. Install with `brew install gpg` or `sudo apt-get install gnupg` or build and install it from [source](https://www.gnupg.org/download/index.html).

# Use

Run the script interactively with `./pwd.sh` or copy it to a folder in `$PATH`

Type `w` to write a password.

Type `r` to read a password.

Type `d` to delete a password.

Options can also be passed on the command line.

Create a password with a length of 30 characters for *gmail*:

    ./pwd.sh w gmail 30

Append `<space>q` to suppress generated password output.

Read the password for *user@github*:

    ./pwd.sh r user@github

Delete the password for *dropbox*:

    ./pwd.sh d dropbox

Copy the password for *github* to clipboard on OS X:

    ./pwd.sh r github | cut -f1 -d ' ' | tr -d '\n' | pbcopy

The script and `pwd.sh.safe` encrypted file can be safely shared between machines, for example through Google Drive or Dropbox.

An example `gpg.conf` configuration file is provided for your consideration.

# Similar software

[Pass: the standard unix password manager](http://www.passwordstore.org/)

[caodonnell/passman.sh: a pwd.sh fork](https://github.com/caodonnell/passman.sh)

[anders/pwgen: generate passwords using OS X Security framework](https://github.com/anders/pwgen)

