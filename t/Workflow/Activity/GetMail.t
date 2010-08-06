use Test::MockObject::Extends;
use Test::More;
use WebGUI::Workflow::Activity::GetMail;

my %properties = (getMail => 0);

my @gotMessages;
my $asset = Test::MockObject->new
    ->mock(get => sub { $properties{$_[1]} })
    ->mock(getUrl => sub { 'url' })
    ->mock(onMail => sub { push @gotMessages, $_[1] });

my $wf = bless {}, 'WebGUI::Workflow::Activity::GetMail';
$wf = Test::MockObject::Extends->new($wf)
    ->mock(connectError => sub { shift->ERROR });

is $wf->execute($asset), $wf->COMPLETE, 'complete when getMail is off';
$properties{getMail} = 1;

$wf->mock(mailGetter => sub { undef });
is $wf->execute($asset), $wf->ERROR, 'error when mailGetter returns undef';

my @messages = qw(1 2 3);
my @send     = @messages;
my $getter = Test::MockObject->new
    ->mock(getNextMessage => sub { shift(@send) })
    ->mock(disconnect => sub {});

$wf->mock(mailGetter => sub { $getter });
is $wf->execute($asset), $wf->COMPLETE, 'returns complete';

is_deeply \@gotMessages, \@messages, 'got all messages';
$getter->called_ok(disconnect => 'disconnected from mail');

$wf->mock(getTTL => sub { -1 });
@send = @messages;
is $wf->execute($asset), $wf->WAITING(1), 'waits on timeout';

done_testing;
