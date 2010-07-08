package WebGUI::Helpdesk2::Ticket;

use Moose;
use DateTime;
use DateTime::Format::Strptime;
use HTML::Entities;

use namespace::clean -except => 'meta';

my $dateFormatter = DateTime::Format::Strptime->new(
    pattern   => '%F %H:%M',
    locale    => 'en_US',
    time_zone => 'UTC',
    on_error  => 'croak',
);

has helpdesk => (
    is       => 'ro',
    isa      => 'WebGUI::Asset::Wobject::Helpdesk2',
    required => 1,
    weak_ref => 1,
    handles  => ['session', 'renderUser'],
);

has url => (
    is         => 'ro',
    init_arg   => undef,
    lazy_build => 1,
);

has id => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has openedBy => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has openedOn => (
    is       => 'ro',
    isa      => 'DateTime',
    default  => sub { DateTime->now },
    required => 1,
);

sub _build_url {
    my $self = shift;
    $self->helpdesk->ticketUrl($self);
}

has assignedOn => (
    is      => 'ro',
    writer  => '_setAssignedOn',
    isa     => 'DateTime',
);

has assignedTo => (
    is      => 'ro',
    isa     => 'Str',
    writer  => '_setAssignedTo',
);

has assignedBy => (
    is      => 'ro',
    isa     => 'Str',
    writer  => '_setAssignedBy',
);

sub assign {
    my ($self, $victim) = @_;
    $victim = $victim->userId if eval { $victim->can('userId') };
    $self->_setAssignedTo($victim);
    $self->_setAssignedOn(DateTime->now);
    $self->_setAssignedBy($self->session->user->userId);
}

has status => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has lastReply => (
    is       => 'ro',
    isa      => 'DateTime',
    writer   => '_setLastReply',
    required => 1,
    default  => sub { DateTime->now },
);

sub postComment {
    my ($self, $body, $status, $storages) = @_;
    my $comment = WebGUI::Helpdesk2::Comment->new(
        ticket => $self,
        body   => $body,
        status => $status,
    );
    $comment->save();
    if ($storages) {
        $comment->attach($_) for @$storages;
    }
    $self->_setLastReply(DateTime->now);
    if ($self->has_comments) {
        $self->_addComment($comment);
    }
}

has public => (
    is => 'rw',
    isa => 'Bool',
    default => 1,
);

has severity => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has [qw(title keywords webgui wre os)] => (
    is      => 'rw',
    isa     => Str,
    default => '',
);

has comments => (
    traits     => ['Array'],
    isa        => 'ArrayRef[WebGUI::Helpdesk2::Comment]',
    lazy_build => 1,
    handles    => {
        _addComment => 'push',
        comments    => 'elements',
    },
);

sub _build_comments {
    WebGUI::Helpdesk2::Comment->loadTicketComments(shift);
}

sub render {
    my %hash;

    for my $key (qw(id url status severity))
    {
        $hash{$key} = $self->$key;
    }

    for my $key (qw(title keywords webgui wre os)) {
        $hash{$key} = encode_entities($self->$key);
    }

    for my $key (qw(openedBy assignedTo assignedBy)) {
        $hash{$key} = $self->renderUser($self->$key);
    }

    for my $key (qw(openedOn assignedOn lastReply)) {
        if (my $stamp = $self->$key) {           
            $hash{$key} = $dateFormatter->format_datetime($stamp);
        }
    }

    $hash{visibility} = $self->public ? 'public' : 'private';
    $hash{comments} = [ map { $_->render } $self->comments ];

    \%hash;
}

sub load {
    my ($class, $helpdesk, $id) = @_;
    my $db   = $helpdesk->session->db;
    my $sql  = q{select * from Helpdesk2_Ticket where helpdesk = ? and id = ?};
    my $data = $db->quickHashRef($sql, $helpdesk->getId, $id);
    $data->{helpdesk} = $helpdesk;
    for my $key (qw(openedOn assignedOn lastReply)) {
        if (my $stamp = $data->{$key}) {
            $data->{$key} = DateTime->from_epoch(epoch => $stamp);
        }
    }
    $class->new($data);
}

sub save {
    my $self = shift;
    my $db   = $self->session->db;
    my $dbh  = $db->dbh;

    my %data = (helpdesk => $self->helpdesk->getId);
    for my $key (qw(id openedBy assignedTo assignedBy status public
                    severity title keywords webgui wre os)) 
    {
        $data{$key} = $self->$key;
    }
    for my $key (qw(openedOn assignedOn lastReply)) {
        if (my $date = $self->$key) {
            $data{$key} = $self->$key->epoch;
        }
    }
    my $fields = join ',', map { $dbh->quote_identifier } keys %data;
    my $places = join ',', map { '?' } keys %data;
    my $sql = "replace into Helpdesk2 ($fields) values ($places)";
    $db->write($sql, [values %data]);
}

__PACKAGE__->meta->make_immutable;

no namespace::clean;

1;
