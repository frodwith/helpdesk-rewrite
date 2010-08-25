package WebGUI::AssetCollateral::Helpdesk2::Comment;

use Moose;
use DateTime;
use HTML::Entities;
use WebGUI::AssetCollateral::Helpdesk2::Attachment;

use namespace::clean -except => 'meta';

=head1 NAME

WebGUI::AssetCollateral::Helpdesk2::Comment

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2009 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=cut

=head1 METHODS

=head2 _addAttachment

push() for attachments

=cut

#-------------------------------------------------------------------

=head2 _build_attachments

=cut

sub _build_attachments {
    WebGUI::AssetCollateral::Helpdesk2::Attachment->loadCommentAttachments(shift);
}


#-------------------------------------------------------------------

=head2 attach ($storage)

Attach all the files in the given storage.

=cut

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

=head2 attachments

An array of this comment's attachments

=cut

has attachments => (
    traits     => ['Array'],
    isa        => 'ArrayRef[WebGUI::AssetCollateral::Helpdesk2::Attachment]',
    lazy_build => 1,
    init_arg   => undef,
    handles    => {
        attachments    => 'elements',
        _addAttachment => 'push',
        getAttachment  => 'get',
    },
);

=head2 author

The userId of the comment's author.

=cut

has author => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    lazy     => 1,
    default  => sub { shift->session->user->userId },
);

=head2 body

The text of the comment

=cut

has body => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

=head2 clear_attachments

=cut

#-------------------------------------------------------------------

=head2 delete

Delete this comment and all its attachments.

=cut

sub delete {
    my $self = shift;
    my $sql  = 'delete from Helpdesk2_Comment where id=?';
    $_->delete for $self->attachments;
    $self->session->db->write($sql, [ $self->id ]);
}

=head2 getAttachment(index)

Gets this comment's nth attachment.

=head2 has_attachments

=head2 helpdesk

Gets the helpdesk this comment's ticket is associated with.

=head2 id

The id (randomly generated) of this comment.

=cut

has id => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    lazy     => 1,
    default  => sub { shift->session->id->generate },
);

#-------------------------------------------------------------------

=head2 insert (%args)

Wrapper around new() and save()

=cut

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

#-------------------------------------------------------------------

=head2 loadTicketComments ($ticket)

Loads all comments for the given ticket.

=cut

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

=head2 meta

=head2 new

Standard Moose constructor.  Accepts the following:

=head3 author

=head3 body

=head3 id

Automatically generated if not given.

=head3 status

=head3 ticket (WebGUI::AssetCollateral::Helpdesk2::Ticket)

Required.

=head3 timestamp (DateTime)

Defaults to the current time.

=cut

#-------------------------------------------------------------------

=head2 render

Returns a hashref representing this comment:

=head3 timestamp (formatted)

=head3 author (renderUser)

=head3 body html entity encoded)

=head3 status

=head3 attachments (rendered)

=cut

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

=head2 renderUser

Asks this comment's ticket to render the passed userId into some sort of
hashref.

=head2 session

The ticket's session.

=head2 status

This ticket's status (feedback, waiting, resolved, etc)

=cut

has status => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

=head2 ticket

The ticket this comment is associated with.

=cut

has ticket => (
    is       => 'ro',
    isa      => 'WebGUI::AssetCollateral::Helpdesk2::Ticket',
    required => 1,
    weak_ref => 1,
    handles  => ['session', 'helpdesk', 'renderUser'],
);

=head2 timestamp

The DateTime at which this comment was made.

=cut

has timestamp => (
    is      => 'ro',
    isa     => 'DateTime',
    default => sub { DateTime->now }
);

no namespace::clean;

__PACKAGE__->meta->make_immutable;

1;
