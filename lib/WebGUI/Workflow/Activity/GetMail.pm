package WebGUI::Workflow::Activity::GetMail;

use warnings;
use strict;

use base 'WebGUI::Workflow::Activity';

use WebGUI::Mail::Get;
use Scope::Guard qw(guard);

=head1 LEGAL

-------------------------------------------------------------------
 WebGUI is Copyright 2001-2008 Plain Black Corporation.
-------------------------------------------------------------------
 Please read the legal notices (docs/legal.txt) and the license
 (docs/license.txt) that came with this distribution before using
 this software.
-------------------------------------------------------------------
 http://www.plainblack.com                     info@plainblack.com
-------------------------------------------------------------------

=head1 NAME

WebGUI::Workflow::Activity::GetMail

=head1 DESCRIPTION

Retrieve incoming mail messages for GetMail assets.

=head1 SYNOPSIS

See WebGUI::Workflow::Activity for details on how to use any activity.

=head1 METHODS

These methods are available from this class:

=cut

#-------------------------------------------------------------------

=head2 definition ( session, definition )

See WebGUI::Workflow::Activity::defintion() for details.

=cut 

sub definition {
    my ($class, $session, $definition) = @_;
	my $i18n = WebGUI::International->new($session, 'AssetAspect_GetMail');
	
    push @$definition, {
		name       => $i18n->get('Get Mail'),
		properties => {},
	};
	return $class->SUPER::definition($session, $definition);
}


#-------------------------------------------------------------------

=head2 execute (  )

See WebGUI::Workflow::Activity::execute() for details.

=cut

sub execute {
    my ($self, $asset) = @_;

	my $finish = time + $self->getTTL;

    return $self->COMPLETE unless $asset->get('getMail');

	my $mail = $self->mailGetter($asset)
        or return $self->connectError($asset);

    my $cleanup = guard { $mail->disconnect };

    while (my $msg = $mail->getNextMessage) {
        $asset->onMail($msg);
        return $self->WAITING(1) if time >= $finish;
    }

    return $self->COMPLETE;
}

sub mailGetter {
    my ($self, $asset) = @_;

    return WebGUI::Mail::Get->connect(
        $self->session, {
            server   => $asset->get('getMailServer'),
            account  => $asset->get('getMailAccount'),
            password => $asset->get('getMailPassword'),
        }
    );
}

sub connectError {
    my ($self, $asset) = @_;

    my $server = $asset->get('getMailServer');
    my $url    = $asset->getUrl;

    $self->session->log->warn("Could not connect to $server. "
        . "Please check the mail account settings for $url.");

    return $self->ERROR;
}

1;
