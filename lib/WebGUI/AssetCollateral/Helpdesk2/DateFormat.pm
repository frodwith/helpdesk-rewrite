package WebGUI::AssetCollateral::Helpdesk2::DateFormat;

=head1 NAME

WebGUI::AssetCollateral::Helpdesk2::DateFormat

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

=head1 CLASS METHODS

=cut

#-------------------------------------------------------------------

=head2 format_date ($dt)

Formats dt like 2010-01-01

=cut

sub format_date {
    my ($class, $dt) = @_;
    $date->format_datetime($dt);
}

#-------------------------------------------------------------------

=head2 format_datetime ($dt)

Formats dt like 2010-01-01 12:01

=cut

sub format_datetime {
    my ($class, $dt) = @_;
    $datetime->format_datetime($dt);
}

#-------------------------------------------------------------------

=head2 parse_date ($str)

The inverse of format_date

=cut

sub parse_date {
    my ($class, $str) = @_;
    $date->parse_datetime($str);
}

#-------------------------------------------------------------------

=head2 parse_datetime ($str)

The inverse of format_date

=cut

sub parse_datetime {
    my ($class, $str) = @_;
    $datetime->parse_datetime($str);
}

1;
