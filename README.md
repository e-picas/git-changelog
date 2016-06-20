GIT changelog
=============

A shell command to generate CHANGELOG from a GIT history.

Usage
-----

Usage of the command from a terminal:

    usage:          ./git-changelog.sh <arg>

    with <arg> in:
                    'all'        : get the full repository changelog
                    'tag1..tag2' : get a changelog between tag1 and tag2 (tag1 < tag2)
                    'hash'       : get a single commit changelog message
                    'init'       : get the full repository initial changelog (when no tag is available yet)

Generated rendering:

    # CHANGELOG for remote repository git@github.com:e-picas/git-changelog.git
    
    * (upcoming release)
    
        * be2f51e - Initial commit (picas)
    
    * v1.1.2 (2016-06-12 - 98ed75f)
    
        * 35a83ad - preparing version 1.1.2 Bower & Node ready (picas)
        * 27de223 - fix PHP bootstrapper (picas)
    
    * v1.1.1 (2016-06-12 - 4910542)
    
        * 465f92f - preparing version 1.1.1 (#nochangelog) (picas)
        * 0405aac - new environment settings (picas)
        * ea73906 - review of documentations & ignored paths (picas)

Installation
------------

As the command is a simple shell script, it can be used from source anywhere you need.
In a terminal, run:

    $ git clone https://github.com/e-picas/git-changelog.git
    $ cd git-changelog
    $ ./git-changelog.sh

To install it as a command available for all your system users, you can do (as a *root* user):

    $ cp /path/to/git-changelog.sh /usr/local/bin/
    $ chmod a+x /usr/local/bin/git-changelog.sh

If you want to use a clone (to keep up-to-date), you can also do something like (as a *root* user):

    $ cd /usr/local/lib/
    $ git clone https://github.com/e-picas/git-changelog.git
    $ ln -s /usr/local/lib/git-changelog/git-changelog.sh /usr/local/bin/

Support
-------

The *GIT changelog* source code repository is [hosted on GitHub](https://github.com/e-picas/git-changelog).
You can use this repository to transmit bug on the issue tracker or submit tested pull requests for review.

---

(c) 2014-2016 Pierre Cassat. *GIT changelog* is released under the terms of the MIT license; see `LICENSE` for details.
