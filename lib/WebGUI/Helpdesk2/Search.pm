package WebGUI::Helpdesk2::Search;
use Moose;
use Moose::Util::TypeConstraints;
use Template;
use WebGUI::Helpdesk2::Ticket;
use WebGUI::Helpdesk2::DateFormat;
use Modern::Perl;

use namespace::clean -except => 'meta';

has helpdesk => (
    is      => 'ro',
    isa     => 'WebGUI::Asset::Wobject::Helpdesk2',
    handles => ['session', 'canStaff'],
);

has size => (
    is      => 'ro',
    isa     => 'Int',
    default => 25,
);

has start => (
    is      => 'ro',
    isa     => 'Int',
    default => 0,
);

has sort => (
    is      => 'ro',
    isa     => enum([qw(
        id title openedBy openedOn assignedTo status lastReply
    )]),
    default => 'id',
);

has dir => (
    is      => 'ro',
    isa     => enum([qw(asc desc)]),
    default => 'asc',
);

has filter => (
    is        => 'ro',
    isa       => 'Maybe[HashRef]',
    predicate => 'has_filter',
);

has filter_clause => (
    is         => 'ro',
    init_arg   => undef,
    lazy_build => 1,
);

sub _userRule {
    my ($self, $which, $users) = @_;
    return '' unless $users && @$users;
    my $dbh = $self->session->db->dbh;
    my $str = join(',', map { $dbh->quote($_->{id}) } @$users);
    return "t.$which IN ($str)";
}

sub _dateRule {
    my ($self, $which, $from, $to) = @_;
    my $dbh = $self->session->db->dbh;
    ($from, $to) = map { $_ && $dbh->quote(
        WebGUI::Helpdesk2::DateFormat->parse_date($_)->epoch
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

sub _exactRule {
    my ($self, $which, $values) = @_;
    return '' unless @$values;
    my $dbh = $self->session->db->dbh;
    my $str = join(',', map { $dbh->quote($_) } @$values);
    return "t.$which IN ($str)";
}

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

has where_clause => (
    is         => 'ro',
    init_arg   => undef,
    lazy_build => 1,
);

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

    return map { WebGUI::Helpdesk2::Ticket->loadFromRow($self->helpdesk, $_) }
           @{ $self->session->db->buildArrayRefOfHashRefs($sql) }
}

sub count {
    my $self    = shift;
    my $where   = $self->where_clause;
    my $sql     = "select count(*) from Helpdesk2_Ticket t $where";

    return $self->session->db->quickScalar($sql);
}

__PACKAGE__->meta->make_immutable;

no namespace::clean;

1;
