use MooseX::Declare;

class Helpdesk::Ticket {
    use JSON;
    use DateTime;
    use Helpdesk::Comment;
    use Helpdesk::Types qw(:all);
    use MooseX::Types::Moose qw(Str Bool Undef);

    has baseUrl => (
        is       => 'ro',
        isa      => Str,
        required => 1,
    );

    has url => (
        is       => 'ro',
        isa      => Str,
        init_arg => undef,
        lazy     => 1,
        default  => sub {
            my $self = shift;
            join('/', $self->baseUrl, $self->id);
        },
    );

    has id => (
        is  => 'ro',
        isa => Str,
    );

    has openedBy => (
        is       => 'ro',
        isa      => HelpdeskUser,
        required => 1,
    );

    has openedOn => (
        is       => 'ro',
        isa      => HelpdeskTimestamp,
        coerce   => 1,
        default  => sub { DateTime->now },
    );

    has assignedOn => (
        is       => 'rw',
        isa      => HelpdeskTimestamp | Undef,
        coerce   => 1,
        clearer  => 'clear_assignedOn',
    );

    has assignedTo => (
        is        => 'rw',
        isa       => 'Maybe[Str]',
        clearer   => 'clear_assignedTo',
        predicate => 'assigned'
    );
    
    has assignedBy => (
        is       => 'rw',
        isa      => 'Maybe[Str]',
        clearer  => 'clear_assignedBy',
    );

    has status => (
        is      => 'rw',
        isa     => HelpdeskStatus,
        default => 'open',
    );

    has lastReply => (
        is      => 'rw',
        isa     => HelpdeskTimestamp,
        coerce  => 1,
        default => sub { DateTime->now },
    );

    has public => (
        is      => 'rw',
        isa     => Bool,
        default => 1,
    );
    
    has severity => (
        is      => 'rw',
        isa     => HelpdeskSeverity,
        default => 'minor',
    );

    has [qw(title keywords webgui wre os)] => (
        is      => 'rw',
        isa     => Str,
        default => '',
    );

    has comments => (
        traits  => ['Array'],
        is      => 'ro',
        isa     => HelpdeskComments,
        coerce  => 1,
        default => sub { [] },
        handles => {
            add_comment  => 'push',
            all_comments => 'elements',
        },
    );

    method to_hash() {
        my %hash;
        for my $key (qw(id url title openedBy assignedTo assignedBy
                        status severity keywords webgui wre os))
        {
            $hash{$key} = $self->$key;
        }
        $hash{visibility} = $self->public ? 'public' : 'private';
        for my $key (qw(openedOn assignedOn lastReply)) {
            if (my $stamp = $self->$key) {           
                $hash{$key} = Helpdesk::Types::format_timestamp($stamp);
            }
        }
        $hash{comments} = [ map { $_->to_hash } $self->all_comments ];
        \%hash;
    }

    method assign(Str $assigner, Str $new?) {
        if ($new) {
            if (!$self->assigned or $new ne $self->assignedTo) {
                $self->assignedTo($new);
                $self->assignedBy($assigner);
                $self->assignedOn(DateTime->now);
            }
        }
        else {
            $self->clear_assignedTo;
            $self->clear_assignedBy;
            $self->clear_assignedOn;
        }
    }
}

1;
