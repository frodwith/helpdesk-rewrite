package WebGUI::AssetCollateral::Helpdesk2::Search;

use Moose;
use Moose::Util::TypeConstraints;
use Template;
use WebGUI::AssetCollateral::Helpdesk2::Ticket;
use WebGUI::AssetCollateral::Helpdesk2::DateFormat;
use Modern::Perl;

use namespace::clean -except => 'meta';

=head1 NAME

WebGUI::AssetCollateral::Helpdesk2::Search

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

=head1 METHODS

=cut

#-------------------------------------------------------------------

=head2 _build_filter_clause

=cut

sub _build_filter_clause {
    my $self = shift;
    my $filter = $self->has_filter && $self->filter || return '';
    my $rules  = $filter->{rules} || return '';

    my @built  = 
        grep { $_ } 
        map { my $r = $self->_ruleSql($_); $r && "($r)" } 
        @$rules;

    my $conj = $filter->{match} eq 'all' ? 'AND' : 'OR';
    join(" $conj ", @built);
}

#-------------------------------------------------------------------

=head2 _build_where_clause

=cut

sub _build_where_clause {
    my $self    = shift;
    my $session = $self->session;
    my $dbh     = $session->db->dbh;
    my $filter  = $self->filter_clause;
    my $id      = $dbh->quote($self->helpdesk->getId);
    my @clauses = ("t.helpdesk = $id");
    unless ($self->canStaff) {
        my $user = $dbh->quote($session->user->userId);
        push @clauses, "t.public = 1 OR t.openedBy = $user"
    }
    push(@clauses, $filter) if $filter;
    my $where = join(" AND ", map { "($_)" } @clauses);
    return $where && "WHERE $where";
}

#-------------------------------------------------------------------

=head2 _dateRule

=cut

sub _dateRule {
    my ($self, $which, $from, $to) = @_;
    my $dbh = $self->session->db->dbh;
    ($from, $to) = map { $_ && $dbh->quote(
        WebGUI::AssetCollateral::Helpdesk2::DateFormat->parse_date($_)->epoch
    ) } ($from, $to);

    if ($from && $to) {
        return "t.$which BETWEEN $from AND $to";
    }
    elsif ($from) {
        return "t.$which >= $from";
    }
    elsif ($to) {
        return "$.$which <= $to";
    }
    else {
        return '';
    }
}

#-------------------------------------------------------------------

=head2 _exactRule

=cut

sub _exactRule {
    my ($self, $which, $values) = @_;
    return '' unless @$values;
    my $dbh = $self->session->db->dbh;
    my $str = join(',', map { $dbh->quote($_) } @$values);
    return "t.$which IN ($str)";
}

#-------------------------------------------------------------------

=head2 _ruleSql

=cut

sub _ruleSql {
    my ($self, $rule) = @_;
    my $a = $rule->{args};
    my $t = $rule->{type};
    given ($t) {
        when ([qw(assignedTo openedBy)]) {
            return $self->_userRule($t, $a);
        }
        when ([qw(openedOn lastReply)]) {
            return $self->_dateRule($t, $a->{from}, $a->{to});
        }
        when ('status') {
            return $self->_exactRule($t, $a);
        }
    }
    return;
}


#-------------------------------------------------------------------

=head2 _userRule

These methods assemble chunks of SQL to be used in the main query, and are
private.

=cut

sub _userRule {
    my ($self, $which, $users) = @_;
    return '' unless $users && @$users;
    my $dbh = $self->session->db->dbh;
    my $str = join(',', map { $dbh->quote($_->{id}) } @$users);
    return "t.$which IN ($str)";
}


#-------------------------------------------------------------------

=head2 canStaff ( [ $user ] )

Asks the helpdesk if the given user has staff permissions.

=head2 clear_filter_clause

=head2 clear_where_clause

=cut

#-------------------------------------------------------------------

=head2 count

Returns the number of records that match the given search parameters

=cut

sub count {
    my $self    = shift;
    my $where   = $self->where_clause;
    my $sql     = "select count(*) from Helpdesk2_Ticket t $where";

    return $self->session->db->quickScalar($sql);
}

=head2 dir

The direction of the sort (asc or desc)

=cut

has dir => (
    is      => 'ro',
    isa     => enum([qw(asc desc)]),
    default => 'asc',
);

=head2 filter

An optional hashref of rules of the form:

    {
        match => 'any' # or all 
        rules = [
            {
                type => 'assignedTo',
                args => 'frodwith'
            }
        ]
    }

=cut

has filter => (
    is        => 'ro',
    isa       => 'Maybe[HashRef]',
    predicate => 'has_filter',
);

=head2 filter_clause

A chunk of sql that implements the rules given in filter.

=cut

has filter_clause => (
    is         => 'ro',
    init_arg   => undef,
    lazy_build => 1,
);

=head2 has_filter

=head2 has_filter_clause

=head2 has_where_clause

=head2 helpdesk

The helpdesk this search is for

=cut

has helpdesk => (
    is      => 'ro',
    isa     => 'WebGUI::Asset::Wobject::Helpdesk2',
    handles => ['session', 'canStaff'],
);

=head2 meta

=head2 new (%args)

Standard Moose constructor.  Accepts the following arguments:

=head3 dir

=head3 filter

=head3 helpdesk

=head3 size

=head3 sort

=head3 start

=head2 session

The helpdesk's session

=head2 size

Limit the number of tickets returned by the search.

=cut

has size => (
    is      => 'ro',
    isa     => 'Int',
    default => 25,
);

=head2 sort

The field name to sort by

=cut

has sort => (
    is      => 'ro',
    isa     => enum([qw(
        id title openedBy openedOn assignedTo status lastReply
    )]),
    default => 'id',
);

=head2 start

The number of records to skip (for pagination)

=cut

has start => (
    is      => 'ro',
    isa     => 'Int',
    default => 0,
);

#-------------------------------------------------------------------

=head2 tickets

Returns a list of tickets that match the search criteria

=cut

sub tickets {
    my $self = shift;
    my $template = <<SQL;
[% FILTER collapse %]
    [% s = self.sort %]
    [% userSort = (s == "openedBy" || s == "assignedTo") %]

    SELECT t.* 
    FROM   Helpdesk2_Ticket t
    [% IF userSort %]
        LEFT JOIN userProfileData u ON t.[% self.sort %] = u.userId
    [% END %]

    [% self.where_clause %]

    ORDER BY
    [% IF userSort %]
        u.lastName  [% self.dir %],
        u.firstName [% self.dir %]
    [% ELSE %]
        t.[% s %]   [% self.dir %]
    [% END %]

    LIMIT  [% self.size %]
    OFFSET [% self.start %]
[% END %]
SQL
    my $tt = Template->new;
    $tt->process( \$template, { self => $self }, \my $sql ) or die $tt->error;

    return map { WebGUI::AssetCollateral::Helpdesk2::Ticket->loadFromRow($self->helpdesk, $_) }
           @{ $self->session->db->buildArrayRefOfHashRefs($sql) }
}

=head2 where_clause

A chunk of SQL that limits the returned results.

=cut

has where_clause => (
    is         => 'ro',
    init_arg   => undef,
    lazy_build => 1,
);

__PACKAGE__->meta->make_immutable;

no namespace::clean;

1;
