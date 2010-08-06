package WebGUI::Helpdesk2::Ticket;

use Moose;
use DateTime;
use HTML::Entities;
use WebGUI::Helpdesk2::Comment;
use WebGUI::Helpdesk2::DateFormat;
use WebGUI::Helpdesk2::Subscription;
use WebGUI::User;

use namespace::clean -except => 'meta';

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
    is         => 'ro',
    isa        => 'Int',
    lazy_build => 1,
    required   => 1,
);

sub _build_id {
    my $self = shift;
    my $db   = $self->session->db;
    my $sql  = 'select max(id) from Helpdesk2_Ticket where helpdesk = ?';
    my $max  = $db->quickScalar($sql, [$self->helpdesk->getId]);
    return ($max || 0) + 1;
}

has openedBy => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    required => 1,
    default  => sub { $_[0]->session->user->userId },
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
    isa     => 'Maybe[DateTime]',
);

has assignedTo => (
    is      => 'ro',
    isa     => 'Maybe[Str]',
    writer  => '_setAssignedTo',
);

has assignedBy => (
    is      => 'ro',
    isa     => 'Maybe[Str]',
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
    default  => 'open',
);

has lastReply => (
    is       => 'ro',
    isa      => 'DateTime',
    writer   => '_setLastReply',
    required => 1,
    default  => sub { DateTime->now },
);

sub postComment {
    my ($self, $body, $status, $storage) = @_;
    my $comment = WebGUI::Helpdesk2::Comment->insert(
        ticket => $self,
        body   => $body,
        status => $status || $self->status,
    );
    $comment->attach($storage) if $storage;
    $self->_setLastReply(DateTime->now);
    $self->status($comment->status);
    $self->save();
    if ($self->has_comments) {
        $self->_addComment($comment);
    }
    $self->notifySubscribers();
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
    default  => 'cosmetic',
);

has [qw(title keywords webgui wre os)] => (
    is      => 'rw',
    isa     => 'Str',
    default => '',
);

has groupId => (
    is        => 'ro',
    isa       => 'Maybe[Str]',
    writer    => '_setGroupId',
    clearer   => '_killGroupId',
);

has subscribers => (
    is         => 'ro',
    isa        => 'Maybe[WebGUI::Group]',
    writer     => '_set_subscribers',
    lazy_build => 1,
);

sub _build_subscribers {
    my $self = shift;
    $self->groupId && 
        WebGUI::Group->new($self->session, $self->groupId);
};

sub isOwner {
    my ($self, $user) = @_;
    my $session = $self->session;
    if ($user) {
        $user = $user->userId if eval { $user->can('userId') };
    }
    else {
        $user = $session->user->userId;
    }
    return $user eq $self->openedBy;
}

sub subscribe {
    my $self    = shift;
    my $session = $self->session;
    my $hdid    = $self->helpdesk->getId;
    my $id      = $self->id;

    WebGUI::Helpdesk2::Subscription->subscribe(
        session  => $session,
        group    => $self->groupId,
        user     => $session->user,
        name     => "Ticket $hdid-$id",
        setGroup => sub {
            my $g = shift;
            $self->_set_subscribers($g);
            $self->_setGroupId($g->getId);
            $self->save();
        }
    );
}

sub unsubscribe {
    my $self    = shift;
    my $session = $self->session;

    WebGUI::Helpdesk2::Subscription->unsubscribe(
        session    => $session,
        group      => $self->groupId,
        user       => $session->user,
        unsetGroup => sub {
            my $g = shift;
            $self->clear_subscribers();
            $self->_killGroupId();
            $self->save();
        }
    );
}

has comments => (
    traits     => ['Array'],
    isa        => 'ArrayRef[WebGUI::Helpdesk2::Comment]',
    lazy_build => 1,
    handles    => {
        _addComment => 'push',
        getComment  => 'get',
        comments    => 'elements',
    },
);

sub _build_comments {
    WebGUI::Helpdesk2::Comment->loadTicketComments(shift);
}

sub render {
    my $self = shift;
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
            $hash{$key} = 
                WebGUI::Helpdesk2::DateFormat->format_datetime($stamp);
        }
    }

    $hash{visibility} = $self->public ? 'public' : 'private';
    $hash{comments}   = [ map { $_->render } $self->comments ];
    $hash{owner}      = $self->isOwner;

    if (my $group = $self->subscribers) {
        $hash{subscribed} = $group->hasUser($self->session->user);
    }

    \%hash;
}

sub load {
    my ($class, $helpdesk, $id) = @_;
    my $db  = $helpdesk->session->db;
    my $sql = q{select * from Helpdesk2_Ticket where helpdesk = ? and id = ?};
    my $row = $db->quickHashRef($sql, [$helpdesk->getId, $id]);
    return unless $row;
    $class->loadFromRow($helpdesk, $row);
}

sub loadFromRow {
    my ($class, $helpdesk, $row) = @_;
    my %data = %$row;
    $data{helpdesk} = $helpdesk;
    for my $key (qw(openedOn assignedOn lastReply)) {
        if (my $stamp = $data{$key}) {
            $data{$key} = DateTime->from_epoch(epoch => $stamp);
        }
    }
    $class->new(\%data);
}

sub open {
    my $class = shift;
    my $self  = $class->new(@_);
    $self->save();
    return $self;
}

sub save {
    my $self = shift;
    my $db   = $self->session->db;
    my $dbh  = $db->dbh;

    my %data = (helpdesk => $self->helpdesk->getId);
    for my $key (qw(id openedBy assignedTo assignedBy status public
                    severity title keywords webgui wre os groupId)) 
    {
        $data{$key} = $self->$key;
    }
    for my $key (qw(openedOn assignedOn lastReply)) {
        if (my $date = $self->$key) {
            $data{$key} = $self->$key->epoch;
        }
    }
    my $fields = join ',', map { $dbh->quote_identifier($_) } keys %data;
    my $places = join ',', map { '?' } keys %data;
    my $sql = "replace into Helpdesk2_Ticket ($fields) values ($places)";
    $db->write($sql, [values %data]);
}

sub delete {
    my $self = shift;
    $_->delete for $self->comments;
    my $sql = 'delete from Helpdesk2_Ticket where helpdesk = ? and id = ?';
    $self->session->db->write($sql, [$self->helpdesk->getId, $self->id]);
}

sub notifySubscribers {
}

__PACKAGE__->meta->make_immutable;

no namespace::clean;

1;
