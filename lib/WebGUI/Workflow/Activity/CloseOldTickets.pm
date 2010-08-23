package WebGUI::Workflow::Activity::CloseOldTickets;

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

use warnings;
use strict;
use base 'WebGUI::Workflow::Activity';

use WebGUI::Asset;
use WebGUI::International;
use DateTime;
use Scope::Guard qw(guard);

=head1 NAME

WebGUI::Workflow::Activity::CloseOldTickets

=head1 DESCRIPTION

Close tickets that have been sitting in 'Feedback Requested' or 'Resolved' for
over a week.

=head1 SYNOPSIS

See WebGUI::Workflow::Activity for details on how to use any activity.

=head1 METHODS

These methods are available from this class:

=cut

#-------------------------------------------------------------------

=head2 definition ( session, definition )

See WebGUI::Workflow::Activity::definition() for details.

=cut 

sub definition {
    my ( $class, $session, $definition ) = @_;
    my $i18n = WebGUI::International->new( $session, 'Asset_Helpdesk2' );
    push @$definition, {
        name       => $i18n->get('Close Old Tickets'),
        properties => {}
        };
    return $class->SUPER::definition( $session, $definition );
}

#-------------------------------------------------------------------

=head2 execute ( [ object ] )

See WebGUI::Workflow::Activity::execute() for details.

=cut

sub execute {
    my ( $self, $object, $instance ) = @_;
    my $session = $self->session;
    my $stop    = time + $self->getTTL;
    my $sql     = q{
        SELECT * FROM (
            SELECT   MAX(timestamp) as stamp, helpdesk, ticket
            FROM     Helpdesk2_Comment
            WHERE    status IN ('feedback', 'resolved')
            GROUP BY helpdesk, ticket
        ) t
        WHERE t.stamp < ?
    };

    # Log in as admin to post closing comments
    my $user = $session->user;
    my $restore = guard { $session->user( { user => $user } ) };
    $session->user( { userId => 3 } );

    # No sense in instantiating more than one of each desk.
    my %desks;
    my $old = DateTime->now->subtract( weeks => 1 )->epoch;
    my $sth = $session->db->read( $sql, [$old] );

    while ( my ( $stamp, $helpdeskId, $ticketId ) = $sth->array ) {
        my $helpdesk = $desks{$helpdeskId} ||= WebGUI::Asset->new( $session, $helpdeskId ) || next;
        my $ticket = $helpdesk->getTicket($ticketId) || next;
        $ticket->postComment( 'Closing automatically', 'closed' );

        if ( time >= $stop ) {
            $sth->finish;
            return $self->WAITING(1);
        }
    }

    return $self->COMPLETE;
} ## end sub execute

1;

#vim:ft=perl
