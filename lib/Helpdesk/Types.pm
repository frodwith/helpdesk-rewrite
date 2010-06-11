package Helpdesk::Types;
use DateTime;
use DateTime::Format::Strptime;

use MooseX::Types -declare => [qw(
    HelpdeskUser
    HelpdeskStatus
    HelpdeskSeverity
    HelpdeskTimestamp
    HelpdeskComments
    HelpdeskAttachments
)];
use MooseX::Types::Moose qw(Str Int ArrayRef);

my %users = (
    'pdriver'  => 'Paul Driver',
    'dbell'    => 'Doug Bell',
    'fldillon' => 'Frank Dillon',
    'xtopher'  => 'Chris Palamera',
    'vrby'     => 'Jamie Vrbsky',
);

my %status = (
    'open'         => 'Open',
    'acknowledged' => 'Acknowledged',
    'waiting'      => 'Waiting On External',
    'feedback'     => 'Feedback Requested',
    'confirmed'    => 'Confirmed',
    'resolved'     => 'Resolved',
);

my %severity = (
    'fatal'    => 'Fatal',
    'critical' => 'Critical',
    'minor'    => 'Minor',
    'cosmetic' => 'Cosmetic',
);

{

my $fmt = DateTime::Format::Strptime->new(
    pattern   => '%F %H:%M',
    locale    => 'en_US',
    time_zone => 'UTC',
    on_error  => 'croak',
);

sub format_timestamp {
    $fmt->format_datetime(shift);
}

sub parse_timestamp {
    $fmt->parse_datetime(shift);
}

}

subtype HelpdeskUser,
    as Str,
    where { exists $users{$_} };

subtype HelpdeskStatus,
    as Str,
    where { exists $status{$_} };

subtype HelpdeskSeverity,
    as Str,
    where { exists $severity{$_} };

class_type 'Helpdesk::Attachment';

subtype HelpdeskAttachments,
    as 'ArrayRef[Helpdesk::Attachment]';

coerce HelpdeskAttachments,
    from ArrayRef,
    via { [ map { Helpdesk::Attachment->new($_) } @$_ ] };

class_type 'Helpdesk::Comment';

subtype HelpdeskComments,
    as 'ArrayRef[Helpdesk::Comment]';

coerce HelpdeskComments,
    from ArrayRef,
    via { [ map { Helpdesk::Comment->new($_) } @$_ ] };

class_type 'Helpdesk::Ticket';

class_type HelpdeskTimestamp, { class => 'DateTime' };

coerce HelpdeskTimestamp,
    from Str,
    via { parse_timestamp($_) };

1;
