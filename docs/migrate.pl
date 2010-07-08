use warnings;
use strict;

use FindBin;
use Getopt::Long;
use DBIx::Migration;

my ($config, $version, $verbose);
my $root = '/data/WebGUI';

GetOptions(
    'configFile=s' => \$config,
    'root:s'       => \$root,
    'version:i'    => \$version,
    'verbose'      => \$verbose,
) or die 'invalid options';

unshift @INC, "$root/lib";

require WebGUI::Session;
my $session = WebGUI::Session->open($root, $config);
my $c       = $session->config;

my $m = DBIx::Migration->new(
    {   dsn      => $c->get('dsn'),
        username => $c->get('dbuser'),
        password => $c->get('dbpass'),
        debug    => $verbose,
        dir      => "$FindBin::Bin/schema",
    }
);

$m->migrate($version);
$session->close();

exit 0;
