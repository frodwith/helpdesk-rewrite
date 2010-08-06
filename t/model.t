use Test::More;
use WebGUI::Test;
my $session = WebGUI::Test->session;

use WebGUI::Helpdesk2::Ticket;

my @tickets;

sub clean {
    my $thing = shift;
    if (eval { $thing->isa('WebGUI::Helpdesk2::Ticket') }) {
        push @tickets, $thing;
    }
    else {
        WebGUI::Test->addToCleanup($thing);
    }
}

my $tempspace = WebGUI::Asset->getTempspace($session);
clean(my $helpdesk = $tempspace->addChild(
    {    className => 'WebGUI::Asset::Wobject::Helpdesk2',
    }
));

clean(my $me = WebGUI::User->create($session));
clean(my $him = WebGUI::User->create($session));

$session->user({ user => $me });

clean(my $ticket = WebGUI::Helpdesk2::Ticket->open(
    helpdesk => $helpdesk,
    title    => 'test ticket',
));

my $storage = Test::MockObject->new
    ->mock(getFiles => sub { [qw(file1 file2) ] })
    ->mock(getFileSize => sub { $_[1] eq 'file1' ? 1 : 2 })
    ->mock(getUrl => sub { $_[1] eq 'file1' ? 'url1' : 'url2' })
    ->mock(getId  => sub { 'fakeid' })
    ->mock(delete => sub { });

my $testing = 1;
{
    no warnings 'redefine';
    package WebGUI::Storage;
    use Test::More;
    sub get { 
        ok $_[2] eq 'fakeid' if $testing;
        $storage;
    };
}

$ticket->postComment('This is comment 1', 'open', $storage);
sleep 1;
$ticket->postComment('this is comment 2', 'resolved');

$ticket->assign($him);
$ticket->save();

$ticket = WebGUI::Helpdesk2::Ticket->load($helpdesk, $ticket->id);
is $ticket->title, 'test ticket';
isa_ok $ticket->openedOn, 'DateTime';
is $ticket->openedBy, $me->getId;
is $ticket->assignedTo, $him->getId;
is $ticket->assignedBy, $me->getId;
isa_ok $ticket->assignedOn, 'DateTime';
my $c = $ticket->getComment(0);
is $c->body, 'This is comment 1';
is $c->status, 'open';
isa_ok $c->timestamp, 'DateTime';
is $c->author, $me->getId;

my $a = $c->getAttachment(0);
is $a->filename, 'file1';
is $a->url, 'url1';
is $a->size, 1;

$a = $c->getAttachment(1);
is $a->filename, 'file2';
is $a->url, 'url2';
is $a->size, 2;

ok !defined $c->getAttachment(2);

$c = $ticket->getComment(1);
is $c->body, 'this is comment 2';
is $c->status, 'resolved';

ok !defined $ticket->getComment(2);

done_testing;
$testing = 0;

END {
    $_->delete() for @tickets;
}
