use lib 'lib';
use Dancer;
use Plack::Builder;
use Dancer::Config qw(setting);

load_app 'Helpdesk::App';
setting apphandler => 'PSGI';
setting show_errors => true;
Dancer::Config->load;
Helpdesk::App->init('tickets');

builder {
#    enable 'Debug';
#    enable 'StackTrace';
    sub { Dancer->dance(Dancer::Request->new(shift)) };
};

# vim: ft=perl
