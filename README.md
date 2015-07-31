# pwd.sh

Script to manage passwords in an encrypted file using gpg.

![screencast gif](https://i.imgur.com/sQoF3VN.gif)

# Installation

    git clone https://github.com/drduh/pwd.sh && cd pwd.sh

Requires `gpg`. Install with `brew install gpg` or `sudo apt-get install gnupg` or build and install it from [source](https://www.gnupg.org/download/index.html).

# Use

Run the script interactively with `./pwd.sh`

Type `w` to write a password.

Type `r` to read a password(s).

Type `d` to delete a password.

Options can also be passed on the command line, e.g.,

`./pwd.sh w gmail 30` to generate and write a password called 'gmail' with a length of 30 characters, or

`./pwd.sh r github` to read the password called 'github', or

`./pwd.sh d dropbox` to delete the password called 'dropbox'.

The script and `pwd.sh.safe` encrypted file can be safely shared between machines over public channels (Google Drive, Dropbox, etc).

A sample `gpg.conf` configuration file is provided for your consideration.
