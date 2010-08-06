use Test::More;
use Test::MockObject::Extends;
use Test::MockObject;
use WebGUI::AssetAspect::GetMail;
use JSON;

use warnings;
use strict;

my %props = (getMail => 1);
my %opts  = (foo => 'bar');

my $asset = bless {}, 'WebGUI::AssetAspect::GetMail';
$asset = Test::MockObject::Extends->new($asset)
    ->mock(get => sub { $props{$_[1]} })
    ->mock(update => sub { my $h = $_[1]; @props{keys %$h} = values %$h })
    ->mock(getMailCreateCron => sub {})
    ->mock(getMailCronOptions => sub { \%opts });

ok !defined $asset->getMailCron;

$asset->commit();
$asset->called_ok('getMailCreateCron');

my %cron;
my $fakeCron = Test::MockObject->new
    ->mock(set => sub { my $h = $_[1]; @cron{keys %$h} = values %$h })
    ->mock(delete => sub {});
    
$asset->mock(getMailCron => sub { $fakeCron });
$props{getMail} = 0;
$asset->commit();
$fakeCron->called_ok('delete');

$props{getMail} = 1;
$asset->commit();
is_deeply(\%cron, \%opts);

sub cron_is {

    my ($seconds, $name, $value, $msg) = @_;
    local $props{getMailInterval} = $seconds;
    my $got = { $asset->getMailCronInterval };
    my $exp = { $name => "*/$value" };
    is_deeply $got, $exp, $msg
        or diag JSON::encode_json($got);
}

note 'testing cron intervals';
cron_is 60*5, minuteOfHour => 5, '5 minute';
cron_is 60*10, minuteOfHour => 10, '10 minute';
cron_is 3600, hourOfDay => 1, '1 hour';
cron_is 3600*5, hourOfDay => 5, '5 hour';
cron_is 3600*24*1, dayOfMonth => 1, '1 day';
cron_is 3600*24*21, dayOfMonth => 21, '21 days';
cron_is 3600*24*60, monthOfYear => 2, '2 months';

done_testing;
