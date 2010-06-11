use MooseX::Declare;

class Helpdesk::Comment {
    use DateTime;
    use Helpdesk::Attachment;
    use Helpdesk::Types qw(:all);
    use MooseX::Types::Moose qw(Str);

    has timestamp => (
        is      => 'ro',
        isa     => HelpdeskTimestamp,
        coerce  => 1,
        default => sub { DateTime->now }
    );

    has author => (
        is  => 'ro',
        isa => HelpdeskUser,
    );

    has body => (
        is  => 'ro',
        isa => Str,
    );

    has attachments => (
        traits  => ['Array'],
        is      => 'ro',
        isa     => HelpdeskAttachments,
        coerce  => 1,
        lazy    => 1,
        default => sub { [] },
        handles => {
            all_attachments => 'elements',
        },
    );

    has status => (
        is  => 'ro',
        isa => HelpdeskStatus,
    );

    method to_hash() {
        return {
            timestamp   => Helpdesk::Types::format_timestamp($self->timestamp),
            attachments => [ map { $_->to_hash } $self->all_attachments ],
            map { $_ => $self->$_ } qw(author body status),
        };
    }
}

1;
