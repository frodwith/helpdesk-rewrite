package WebGUI::Helpdesk2::Comment;

use Moose;
use DateTime;
use HTML::Entities;

use namespace::clean -except 'meta';

has timestamp => (
    is      => 'ro',
    isa     => 'DateTime',
    default => sub { DateTime->now }
);

has author => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has body => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has attachments => (
    traits     => ['Array'],
    isa        => 'ArrayRef[WebGUI::Helpdesk2::Attachment]',
    lazy_build => 1,
    handles    => {
        attachments    => 'elements',
        _addAttachment => 'push'
    },
);

has status => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has ticket => (
    is       => 'ro',
    isa      => 'WebGUI::Helpdesk2::Ticket',
    required => 1,
    weak_ref => 1,
    handles  => ['session', 'renderUser'],
);

sub render {
    return {
        timestamp   => WebGUI::Helpdesk2::DateFormat->format($self->timestamp),
        author      => $self->renderUser($self->author),
        body        => encode_entities($self->body),
        status      => $self->status,
        attachments => [ map { $_->render } $self->attachments ],
    };
}

sub attach {
    my ($self, $storage) = @_;
}

no namespace::clean;

1;
