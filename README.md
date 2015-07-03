# pwd.sh

Script to manage passwords in an encrypted file using gpg.

![screencast gif](https://i.imgur.com/sQoF3VN.gif)

# Installation

    git clone https://github.com/drduh/pwd.sh && cd pwd.sh
    
Requires `gpg`

Install with `brew install gpg` or `sudo apt-get install gnupg` or build and install it from [source](https://www.gnupg.org/download/index.html).

# Use

Run the script with `./pwd.sh`
    
Type `w` to write a password.

Type `r` to read a password or all passwords.

Type `d` to delete a password.

The encrypted file `pwd.sh.safe` and script can be safely shared between machines over public channels (Google Drive, Dropbox, etc).

A sample `gpg.conf` configuration file is provided for your consideration.
