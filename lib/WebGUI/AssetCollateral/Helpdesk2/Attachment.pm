package WebGUI::AssetCollateral::Helpdesk2::Attachment;

use Moose;
use WebGUI::Storage;

use namespace::clean -except => 'meta';

has comment => (
    is       => 'ro',
    weak_ref => 1,
    required => 1,
    handles  => ['session'],
);

has ['storage', 'storageId'] => (
    is         => 'ro',
    lazy_build => 1,
);

sub _build_storage {
    my $self = shift;
    return WebGUI::Storage->get($self->session, $self->storageId);
}

sub _build_storageId {
    my $self = shift;
    return $self->storage->getId;
}

has ['size', 'url'] => (
    is         => 'ro',
    lazy_build => 1,
);

sub _build_size {
    my $self = shift;
    return $self->storage->getFileSize($self->filename);
}

sub _build_url {
    my $self = shift;
    return $self->storage->getUrl($self->filename);
}

has filename => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

sub render {
    my $self = shift;
    return {
        name => $self->filename,
        url  => $self->url,
        size => $self->size,
    };
}

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

sub delete {
    my $self = shift;
    my $s = $self->storage;
    $s->delete if $s;
    my $sql = q{
        delete from Helpdesk2_Attachment where storage = ? and filename = ?
    };
    $self->session->db->write($sql, [ $self->storageId, $self->filename ]);
}

no namespace::clean;

__PACKAGE__->meta->make_immutable;

1;
