package WebGUI::Helpdesk2::DateFormat;

use DateTime::Format::Strptime;

my $datetime = DateTime::Format::Strptime->new(
    pattern   => '%F %H:%M',
    locale    => 'en_US',
    time_zone => 'UTC',
    on_error  => 'croak',
);

my $date = DateTime::Format::Strptime->new(
    pattern   => '%F',
    locale    => 'en_US',
    time_zone => 'UTC',
);

sub format_datetime {
    my ($class, $dt) = @_;
    $datetime->format_datetime($dt);
}

sub parse_datetime {
    my ($class, $str) = @_;
    $datetime->parse_datetime($str);
}

sub format_date {
    my ($class, $dt) = @_;
    $date->format_datetime($dt);
}

sub parse_date {
    my ($class, $str) = @_;
    $date->parse_datetime($str);
}

1;
