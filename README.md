# pwd.sh
GnuPG wrapper for password management.

This script uses GPG to manage an encrypted text file containing passwords.

![Screencapture GIF](https://i.imgur.com/088iLqu.gif)

# Requirements
Requires `gpg`.

Install with `brew install gpg` or `sudo apt-get install gnupg` or build and install it from [source](https://www.gnupg.org/download/index.html).

# Installation

    git clone https://github.com/drduh/pwd.sh && cd pwd.sh
    
# Use

Run the script with `./pwd.sh`
    
Type `w` to write a password.

Type `r` to read a password or all passwords.

Type `d` to delete a password.

The encrypted file `pwd.sh.safe` can be safely shared between machines over public channels (Google Drive, Dropbox, etc).

A sample `gpg.conf` configuration file is provided for your consideration.
