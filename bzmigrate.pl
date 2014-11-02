#!/usr/bin/perl

use strict;

use File::Basename;
use Getopt::Std;
use File::Slurp;

use XML::Simple;
use Data::Dumper;
use List::MoreUtils qw/ uniq /;

use Net::GitHub::V3;

# you could define this stuff up here
my $xml_filename;
my $token_filename;
my $github_owner;
my $github_repo;
my $github_login;
my $github_token;
my $migrate_product;

my $bzmigrate_url = "http://goo.gl/IYYut";
my $progname = basename($0);

my $interactive;
my $dumper;
my $skip_resolved;
my $dry;

sub usage
{
    print "usage: $progname [-niDR] [-f bugzilla_file] [-l login] [-r repo] " .
        "[-o owner] [-p product] [-t token_file]\n" .
        "\t-D\tuse dumper\n" .
        "\t-n\tdry run\n" .
        "\t-R\tskip RESOLVED/VERIFIED bugs\n" .
        "\t-i\tinteractive mode, uses environment variables\n" .
  "\t-f\tXML file with Bugzilla data for one or more bugs\n" .
  "\t-l\tGithub login (GITHUB_LOGIN)\n" .
  "\t-r\tGithub repo (GITHUB_REPO)\n" .
  "\t-o\tGithub owner (GITHUB_OWNER)\n" .
  "\t-p\tProduct to migrate\n" .
  "\t-t\tAuthentication token file (GITHUB_TOKEN)\n\n";
    print "You must enter all required GitHub information:\n" .
        "\tproduct to migrate\n" .
        "\tGithub login\n" .
        "\tGithub repo\n" .
        "\tGithub token\n" .
        "\tGithub repo owner\n";
    exit(1);
}

our($opt_i, $opt_R, $opt_D, $opt_f, $opt_t, $opt_o, $opt_r, $opt_l, $opt_p,
    $opt_h, $opt_n);
getopts('hniRDf:t:l:r:o:p:');
$skip_resolved = $opt_R;
$dumper = $opt_D;
$interactive = $opt_i;
$xml_filename = $opt_f;
$token_filename = $opt_t;
$github_owner = $opt_o;
$github_repo = $opt_r;
$github_login = $opt_l;
$migrate_product = $opt_p;
$dry = $opt_n;
usage() if ($opt_h);

# load the token file
if($token_filename){
  $github_token = read_file($token_filename);
  chomp($github_token);
}

# interactive mode
if($interactive){
  if(! $migrate_product){
    print("Wich Bugzilla product would you like to migrate bugs from? ");
    $migrate_product = <STDIN>;
  }

  if(! $github_owner){
    print("Enter the owner of the GitHub repo you want to add " .
      "issues to.\n");
    print("GitHub owner: ");
    $github_owner = <STDIN>;
    chomp($github_owner);
  }

  if(! $github_repo){
    print("Enter the name of the repository you want to add issues to.\n");
    print("GitHub repo: https://github.com/$github_owner/");
    $github_repo = <STDIN>;
    chomp($github_repo);
  }

  if(! $github_login){
    print("Enter your GitHub user name: ");
    $github_login = <STDIN>;
    chomp($github_login);
  }

  if(! $github_token){
    print("Enter your GitHub API token: ");
    $github_token = <STDIN>;
    chomp($github_token);
  }

  if(! $xml_filename){
    print("Enter the name of the XML file with bugs in it: ");
    $xml_filename = <STDIN>;
    chomp($xml_filename);
  }
}

chomp($migrate_product);
# if we don't define something, print an error!
if(!($xml_filename &&
     $github_owner &&
     $github_repo &&
     $github_login &&
     $github_token &&
     $migrate_product)){
  usage();
}

my $xml = new XML::Simple;
my $root_xml = $xml->XMLin($xml_filename,
         ForceArray => ['long_desc', 'attachment']);
print Dumper($root_xml) if ($dumper);

my @bugs = $root_xml->{'bug'};
print "=== Bugs:\n" . Dumper(@bugs) if ($dumper);

my $gh = Net::GitHub::V3->new(
  login => $github_login,
  pass => $github_token,
);
$gh->set_default_user_repo($github_owner, $github_repo);
my $issue = $gh->issue;

my $i=0;

# this is a frustrating hack because I don't understand how perl works
foreach my $bugdummy (@bugs){
  for(my $i=0; $i <= (@$bugdummy); $i++){
    my $bug = $bugdummy->[$i];

    # get the bug ID
    my $id = $bug->{'bug_id'};
    print "migrating " if (!$dry);
    print "Bugzilla bug #$id\n";

    print "=== bug #$id dump:\n" . Dumper($bug) . "===\n" if ($dumper);

    # check the product
    my $product = $bug->{'product'};
    if ($product ne $migrate_product){
      print ("Skipping bug #$id - wrong product (\"$product\")\n");
      next;
    }

    # check the status
    my $status = $bug->{'bug_status'};
    if ($skip_resolved &&
        ($status eq "RESOLVED" || $status eq "VERIFIED")) {
      print("Skipping bug #$id - RESOLVED/VERIFIED\n");
      next;
    }

    # Process titles
    my $title = "$bug->{'short_desc'} (Bugzilla #$id)";
    $title =~ s/^RFE: //; # strip the Bugzilla RFE prefix
    # make sure that the title is unicode
    utf8::encode($title);

    my $component = $bug->{'component'};
    my $platform = $bug->{'rep_platform'};
    my $severity = $bug->{'bug_severity'};
    my $version = $bug->{'version'};
    my $milestone = $bug->{'target_milestone'};
    my $assigned_to = $bug->{'assigned_to'}{'name'};

    # each bug has a list of long_desc for the original description
    # and each comment thereafter
    my $body = "status $status " .
        "severity *$severity* " .
        "in component *$component* " .
        "for *$milestone*\n";
    $body .= "Reported in version *$version* on platform *$platform*\n";
    $body .= "Assigned to: $assigned_to\n";
    $body .= "\n";

    # ignore attachments
    #if (@{$bug->{'attachment'}}) {
    #    $body .= "Original attachment names and IDs:\n";
    #    foreach my $attachment (@{$bug->{'attachment'}}) {
    #        my $filename = $attachment->{'filename'};
    #        utf8::encode($filename) if (utf8::is_utf8($filename));
    #        $body .= "- _" . $filename . "_" .
    #            " (ID " . $attachment->{'attachid'} . ")\n";
    #    }
    #    $body .= "\n";
    #}

    my $comment;
    foreach my $desc (@{$bug->{'long_desc'}}){
      # Some names can be in Unicode, convert them to prevent HTTP::Message
      # from croaking. Other fields should probably receive similar treatment.
      my $name = $desc->{'who'}{'name'};
      utf8::encode($name);

      # do the 'from' line of the message quote
      $body .= "On $desc->{'bug_when'}, $name wrote";
      if (UNIVERSAL::isa( $desc->{'thetext'}, "HASH" )){
        $body .= " nothing.\n";
        next;
      }
      $body .= ":\n\n";

      # do the body of the comment
      my $pretty_text = $desc->{'thetext'};
      # $pretty_text =~ s/ ((> )+)/\n$1/g;
      # $pretty_text =~ s/^\s+//g; # strip leading whitespace
      # $pretty_text =~ s/\s+$//g; # strip trailing whitespace
      $pretty_text =~ s/\n/\n> /g; # quote everything by one more level

      # prevent # followed by numbers to be interpreted as Issue links
      $pretty_text =~ s/#(\d+)/# \1/g;

      # mark up any full git refs as linkable
      $pretty_text =~ s/([0-9a-fA-F]{40})/SHA: $1/g;

      # make sure that the text is unicode
      utf8::encode($pretty_text);

      $comment++;
      $body .= "> $pretty_text\n\n";
    }

    # add labels
    my @labels = ();
    if($severity eq "enhancement"){
      push (@labels,  $severity);
    }else{
      push (@labels,  "bug");
    }

    #print ("Title: $title\n$body\n\n");

    if (!$dry) {
      # actually submit the issue to GitHub
      my $iss = $issue->create_issue({
                title => $title,
                labels => @labels,
                body => $body});
      my $issue_id = $iss->{number};
      print "Bugzilla bug #$id migrated to Github Issue $issue_id";

      # If the original bug was closed then close the Github issue too.
      if ($status eq "CLOSED" || $status eq "RESOLVED") {
          $issue->update_issue( $issue_id, {
              state => 'closed'
          } );
          print " (closed)";
      }
      print "\n";
    }

    # ignore attachments
    #foreach my $attachment (@{$bug->{'attachment'}}) {
    #    # Suppress warnings for wide characters.
    #    binmode STDOUT, ":encoding(UTF-8)";
    #    print "  attachment \"" . $attachment->{'filename'} . "\"" .
    #        " (ID " . $attachment->{'attachid'} . ")\n";
    #}
  }
}
