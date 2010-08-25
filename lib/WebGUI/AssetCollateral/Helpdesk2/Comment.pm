package WebGUI::AssetCollateral::Helpdesk2::Comment;

use Moose;
use DateTime;
use HTML::Entities;
use WebGUI::AssetCollateral::Helpdesk2::Attachment;

use namespace::clean -except => 'meta';

has id => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    lazy     => 1,
    default  => sub { shift->session->id->generate },
);

has timestamp => (
    is      => 'ro',
    isa     => 'DateTime',
    default => sub { DateTime->now }
);

has author => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    lazy     => 1,
    default  => sub { shift->session->user->userId },
);

has body => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has attachments => (
    traits     => ['Array'],
    isa        => 'ArrayRef[WebGUI::AssetCollateral::Helpdesk2::Attachment]',
    lazy_build => 1,
    handles    => {
        attachments    => 'elements',
        _addAttachment => 'push',
        getAttachment  => 'get',
    },
);

sub _build_attachments {
    WebGUI::AssetCollateral::Helpdesk2::Attachment->loadCommentAttachments(shift);
}

has status => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has ticket => (
    is       => 'ro',
    isa      => 'WebGUI::AssetCollateral::Helpdesk2::Ticket',
    required => 1,
    weak_ref => 1,
    handles  => ['session', 'helpdesk', 'renderUser'],
);

sub render {
    my $self = shift;
    my $ts = WebGUI::AssetCollateral::Helpdesk2::DateFormat->format_datetime($self->timestamp);
    return {
        timestamp   => $ts,
        author      => $self->renderUser($self->author),
        body        => encode_entities($self->body),
        status      => $self->status,
        attachments => [ map { $_->render } $self->attachments ],
    };
}

sub attach {
    my ($self, $storage) = @_;
    for my $name (@{ $storage->getFiles }) {
        my $attachment = WebGUI::AssetCollateral::Helpdesk2::Attachment->insert(
            comment  => $self,
            filename => $name,
            storage  => $storage,
        );
        $self->_addAttachment($attachment) if $self->has_attachments;
    }
}

sub insert {
    my $class = shift;
    my $args  = ref $_[0] eq 'HASH' ? $_[0] : { @_ };
    my $self  = $class->new($args);
    my $sql   = q{
        insert into Helpdesk2_Comment (
            id, helpdesk, ticket, timestamp, author, body, status
        ) values (?, ?, ?, ?, ?, ?, ?)
    };

    $self->session->db->write(
        $sql, [
            $self->id,
            $self->helpdesk->getId,
            $self->ticket->id,
            $self->timestamp->epoch,
            $self->author,
            $self->body,
            $self->status,
        ]
    );

    return $self;
}

sub loadTicketComments {
    my ($class, $ticket) = @_;
    my @comments;
    my $db = $ticket->session->db;
    my $sql = q{
        select * 
        from Helpdesk2_Comment
        where helpdesk   = ? 
              and ticket =  ?
        order by timestamp asc
    };
    my $sth = $db->read($sql, [$ticket->helpdesk->getId, $ticket->id]);
    while (my $row = $sth->hashRef) {
        delete $row->{helpdesk};
        $row->{ticket}    = $ticket;
        $row->{timestamp} = DateTime->from_epoch(epoch => $row->{timestamp});
        push @comments, $class->new($row);
    }
    return \@comments;
}

sub delete {
    my $self = shift;
    my $sql  = 'delete from Helpdesk2_Comment where id=?';
    $_->delete for $self->attachments;
    $self->session->db->write($sql, [ $self->id ]);
}

no namespace::clean;

__PACKAGE__->meta->make_immutable;

1;
