use MooseX::Declare;

class Helpdesk::Attachment {
    use MooseX::Types::Moose qw(Str Int);

    has ['url', 'name'] => (
        is       => 'ro',
        isa      => Str,
        required => 1,
    );

    has size => (
        is       => 'ro',
        isa      => Int,
        required => 1,
    );

    method to_hash() {
        return { map { $_ => $self->$_ } qw(url name size) };
    }
}

1;
