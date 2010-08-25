package WebGUI::AssetCollateral::Helpdesk2::Attachment;

use Moose;
use WebGUI::Storage;

use namespace::clean -except => 'meta';

=head1 NAME

WebGUI::AssetCollateral::Helpdesk2::Attachment

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

=cut

#-------------------------------------------------------------------

=head2 _build_size

=cut

sub _build_size {
    my $self = shift;
    return $self->storage->getFileSize($self->filename);
}

#-------------------------------------------------------------------

=head2 _build_storage

=cut

sub _build_storage {
    my $self = shift;
    return WebGUI::Storage->get($self->session, $self->storageId);
}

#-------------------------------------------------------------------

=head2 _build_storageId

=cut

sub _build_storageId {
    my $self = shift;
    return $self->storage->getId;
}

#-------------------------------------------------------------------

=head2 _build_url

=cut

sub _build_url {
    my $self = shift;
    return $self->storage->getUrl($self->filename);
}

=head2 clear_size

=head2 clear_storage

=head2 clear_storageId

=head2 clear_url

=cut

has ['storage', 'storageId'] => (
    is         => 'ro',
    lazy_build => 1,
);

has ['size', 'url'] => (
    is         => 'ro',
    init_arg   => undef,
    lazy_build => 1,
);

=head2 comment

a reference to the comment that this attachment is for.

=cut

has comment => (
    is       => 'ro',
    weak_ref => 1,
    required => 1,
    handles  => ['session'],
);

#-------------------------------------------------------------------

=head2 delete

Delete this attachment and its associated WebGUI::Storage.

=cut

sub delete {
    my $self = shift;
    my $s = $self->storage;
    $s->delete if $s;
    my $sql = q{
        delete from Helpdesk2_Attachment where storage = ? and filename = ?
    };
    $self->session->db->write($sql, [ $self->storageId, $self->filename ]);
}

=head2 filename

The filename to display (foo.gif) for this attachment, also used to identify
which file in the storage is being talked about.

=cut

has filename => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

=head2 has_size

=head2 has_storage

=head2 has_storageId

=head2 has_url

=cut

#-------------------------------------------------------------------

=head2 insert (%args)

Wrapper around new() and save()

=cut

sub insert {
    my $class = shift;
    my $args  = ref $_[0] eq 'HASH' ? $_[0] : { @_ };
    my $self  = $class->new($args);
    my $sql   = q{
        insert into Helpdesk2_Attachment (comment, storage, filename)
        values (?, ?, ?)
    };
    $self->session->db->write(
        $sql, [
            $self->comment->id,
            $self->storage->getId,
            $self->filename
        ]
    );
    return $self;
}

#-------------------------------------------------------------------

=head2 loadCommentAttachments ($comment)

Returns an arrayref of all the attachments for the passed comment.

=cut

sub loadCommentAttachments {
    my ($class, $comment) = @_;
    my $db  = $comment->session->db;
    my $sql = q{
        select * 
        from Helpdesk2_Attachment 
        where comment = ?
        order by filename
    };
    my $sth = $db->read($sql, [$comment->id]);
    my @attachments;
    while (my $row = $sth->hashRef) {
        $row->{comment} = $comment;
        $row->{storageId} = delete $row->{storage};
        push @attachments, $class->new($row);
    }
    \@attachments;
}

=head2 meta

=head2 new

Regular Moose constructor, accepts the following arguments:

=head3 storage (WebGUI::Storage)

=head3 storageId (string)

Only one of these should be set.  The other will be calculated.

=head3 comment (WebGUI::AssetCollateral::Helpdesk2::Comment)

Required.

=head3 filename (str)

Required.

=head3

=cut

#-------------------------------------------------------------------

=head2 render ($comment)

Returns an hashref representing this attachment (name, url, and size)

=cut

sub render {
    my $self = shift;
    return {
        name => $self->filename,
        url  => $self->url,
        size => $self->size,
    };
}

=head2 session

Gets the comment's WebGUI::Session.

=head2 size

Gets the size of this attachment's file

=head2 storage

The WebGUI::Storage this attachment is located in

=head2 storageId

storage's id

=head2 url

The url of this attachment's file

=cut

no namespace::clean;

__PACKAGE__->meta->make_immutable;

1;
