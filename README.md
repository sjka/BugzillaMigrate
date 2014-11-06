BugzillaMigrate
===============

bzmigrate.pl is a Perl program to parse the XML output of Bugzilla
(2.22 onward?) into structures suitable for programmatic upload to a
new bug tracker; initally targeting GitHub Issues (v3).

The script can be run in interactive or batch mode. If run with -i
option, it prompts for the values interactively.

Note that Github Issues API does not currently allow attaching files
programatically so the script just prints its IDs and filenames. 

The script assumes that the target GitHub repository and issue tracker
has labels "bug" and "enhancement".

Install Perl libraries
----------------------

The script needs a number of Perl modules. To install these:

    $ perl -MCPAN -e 'install File::Slurp'
    $ perl -MCPAN -e 'install XML::Simple'
    $ perl -MCPAN -e 'install Data::Dumper'
    $ perl -MCPAN -e 'install List::MoreUtils'
    $ perl -MCPAN -e 'install Net::GitHub::V3'

To install these interactively:

    $ perl -MCPAN -e shell
    cpan> install File::Slurp
    cpan> install XML::Simple
    cpan> install Data::Dumper
    cpan> install List::MoreUtils
    cpan> install Net::GitHub::V3
    cpan> exit

Export bugs from Bugzilla
-------------------------

To export the full specification of all the bugs in a Bugzilla
installation:

* Browse to Bugzilla URL
* Click Search
* Set Status: All
* Set Product: All
* Click Search
* Click XML
* Save file e.g. bugzilla-export.xml

Set up a GitHub API token
-------------------------

A GitHub API token is needed to use this script to import the bugs
into GitHub:

* Log into GitHub
* Click USERNAME
* Click settings cog
* Click Applications
* Under Personal access tokens, click Generate new token
* Enter Token description: Import from Bugzilla
* Uncheck all scopes
* Check public_repo
* Check user
* Click Generate Token
* Copy the token and paste it into a file e.g. token.txt

Run the script
--------------

To run the script:

    $ perl bzmigrate.pl -p PRODUCT_NAME -l USER_NAME -o OWNER_NAME -r REPOSITORY_NAME -t TOKEN_FILE -f BUG_FILE

For example, to import the bugs into the issue tracker for
https://github.com/jenny/sometool, hosted by jenny, fred would run:

    $ perl bzmigrate.pl -p SomeTool -l fred -o jenny -r sometool -t token.txt -f bugzilla-export.xml

Run the script interactively
----------------------------

    $ perl bzmigrate.pl -i
    Wich Bugzilla product would you like to migrate bugs from? PRODUCT_NAME
    Enter the owner of the GitHub repo you want to add issues to.
    GitHub owner: OWNER_NAME
    Enter the name of the repository you want to add issues to.
    GitHub repo: https://github.com/OWNER_NAME/REPOSITORY_NAME
    Enter your GitHub user name: USER_NAME
    Enter your GitHub API token:  TOKEN
    Enter the name of the XML file with bugs in it: BUG_FILE

For example, to import the bugs into the issue tracker for
https://github.com/jenny/sometool, hosted by jenny, fred would run:

    $ perl bzmigrate.pl -i
    Wich Bugzilla product would you like to migrate bugs from? SomeTool
    Enter the owner of the GitHub repo you want to add issues to.
    GitHub owner: jenny
    Enter the name of the repository you want to add issues to.
    GitHub repo: https://github.com/jenny/sometool
    Enter your GitHub user name: fred
    Enter your GitHub API token:  abc123...789xyz
    Enter the name of the XML file with bugs in it: bugzilla-export.xml

View script options
-------------------

Running the script without any options shows all the command-line
arguments:

    $ perl bzmigrate.pl
