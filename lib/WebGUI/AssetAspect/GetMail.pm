package WebGUI::AssetAspect::GetMail;

use warnings;
use strict;

use Modern::Perl;
use WebGUI::International;
use WebGUI::Workflow::Cron;
use List::Util qw(min);

=head1 NAME

WebGUI::AssetAspect::GetMail - Lets your asset receive mail

=head1 SYNOPSIS

package MyAsset;

use base qw(
    WebGUI::Asset
    WebGUI::AssetAspect::GetMail
);

sub onMail {
    my ($self, $message) = @_;
    ...
}

=head1 DESCRIPTION

Allows your asset to receive email

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

=head1 METHODS

#----------------------------------------------------------------------------

=head2 commit

Whenever this asset is commited, we're going to ensure its cron is properly
updated.

=cut

sub commit {
    my $self    = shift;
    my $cron    = $self->getMailCron;
    my $enabled = $self->get('getMail');

    $self->maybe::next::method();

    if ($cron) {
        if ($enabled) {
            $cron->set($self->getMailCronOptions);
        }
        else {
            $cron->delete();
        }
    }
    elsif ($enabled) {
        $self->getMailCreateCron();
    }
}

#----------------------------------------------------------------------------

=head2 definition ( session [, definition ] )

=cut

sub definition {
    my ($class, $session, $definition) = @_;
    my $i18n = WebGUI::International->new($session, 'AssetAspect_GetMail');

    tie my %properties, 'Tie::IxHash', (
        getMailServer => {
            fieldType => 'text',
            tab       => 'get mail',
            label     => $i18n->get('POP3 Server'),
            hoverHelp => $i18n->get('POP3 Server help'),
        },
        getMailAccount => {
            fieldType => 'text',
            tab       => 'get mail',
            label     => $i18n->get('Username'),
            hoverHelp => $i18n->get('Username help'),
        },
        getMailPassword => {
            fieldType => 'password',
            tab       => 'get mail',
            label     => $i18n->get('Password'),
            hoverHelp => $i18n->get('Password help'),
        },
        getMail => {
            fieldType    => 'yesNo',
            tab          => 'get mail',
            defaultValue => 0,
            label        => $i18n->get('Enabled'),
            hoverHelp    => $i18n->get('Enabled help'),
        },
        getMailInterval => {
            fieldType    => 'interval',
            defaultValue => 300,
            tab          => 'get mail',
            label        => $i18n->get('Check Mail Every'),
            hoverHelp    => $i18n->get('Check Mail Every help'),
        },
        getMailCronId => {
            fieldType       => "hidden",
            defaultValue    => undef,
            noFormPost      => 1
        },
    );

    push @$definition, {
        autoGenerateForms       => 1,
        tableName               => "AssetAspect_GetMail",
        properties              => \%properties,
    };

    $class->maybe::next::method( $session, $definition ); 
}

#----------------------------------------------------------------------------

=head2 duplicate ( [ options ] )

Duplicated assets should have all their getMail properties reset, cause more
than one asset getting mail from the same account would be bad.

=cut

sub duplicate {
    my ($self, $properties) = @_;
    $self = $self->next::method( $properties );
    my %reset = map { "getMail$_" => '' }, qw(Server Account Password CronId);
    $self->update(\%reset);
    return $self;
}

#----------------------------------------------------------------------------

=head2 getEditTabs

Add the get mail tab.

=cut

sub getEditTabs {
	my $self = shift;
	return ($self->maybe::next::method(), ['get mail', 'GetMail', 9]);
}

#----------------------------------------------------------------------------

=head2 getMailCreateCron

Create a new cron job for this asset.

=cut

sub getMailCreateCron {
    my $self = shift;
    my $cron = WebGUI::Workflow::Cron->create(
        $self->session,
        $self->getMailCronOptions,
    );
    $self->update({ getMailCronId => $cron->getId });
}

#----------------------------------------------------------------------------

=head2 getMailCronInterval

Returns a hash of options suitable for adding to the WebGUI::Workflow::Cron
constructor.  It isn't exact (every 5 days means every 5th day (of the month,
so the 5th, 10th, 15th, etc.), but it's as close as we can get with crontab
format.

=cut

sub getMailCronInterval {
    my $self = shift;
    my @times = (
        { seconds => 60*60*24*30, property => 'monthOfYear',  max => 12 },
        { seconds => 60*60*24,    property => 'dayOfMonth',   max => 28 },
        { seconds => 60*60,       property => 'hourOfDay',    max => 24 },
        { seconds => 60,          property => 'minuteOfHour', max => 60 },
    );
    my $sec = $self->get('getMailInterval');

    for my $t (@times) {
        my $tsec = $t->{seconds};
        if ($sec >= $tsec) {
            my $max = min($t->{max}, int($sec/$tsec));
            return ( $t->{property} => "*/$max" );
        }
    }

    die "Couldn't calculate cron interval";
}

#----------------------------------------------------------------------------

=head2 getMailCronOptions

Returns a hashref of properties to be used for creating or updating this
workflow's cron.

=cut

sub getMailCronOptions {
    my $self = shift;

    return {
        enabled    => $self->get('getMail'),
        title      => $self->getMailCronTitle,
        className  => ref $self,
        methodName => 'new',
        parameters => $self->getId,
        workflowId => $self->getMailCronWorkflowId,
        $self->getMailCronInterval,
    }
}

#----------------------------------------------------------------------------

=head2 getMailCronTitle

Returns the proper title of this asset's getmail cron

=cut

sub getMailCronTitle {
    my $self = shift;
    return $self->getTitle . ' Mail';
}

#----------------------------------------------------------------------------

=head2 getMailCronWorkflowId

Returns the workflow ID that this asset's cron should use

=cut

sub getMailCronWorkflowId { 'AIMUsNRlIl58Lqugncjzow' }

#----------------------------------------------------------------------------

=head2 getMailCron

Gets the cron associated with this asset (or undef)

=cut

sub getMailCron {
    my $self   = shift;
    my $cronId = $self->get('getMailCronId') || return;
    return WebGUI::Workflow::Cron->new($self->session, $cronId);
}

#----------------------------------------------------------------------------

=head2 onMail (message)

Override this and do something with the mail you receive.  The message
argument is exactly what you'd get back from
WebGUI::Mail::Get->getNextMessage.

=cut

sub onMail {
    my ($self, $message) = @_;
    # do nothing, slowly.
    $self->maybe::next::method($message);
}

#----------------------------------------------------------------------------

=head2 DOES ( role )

Returns true if the asset does the specified role. This mixin does the 
"GetMail" role.

=cut

sub DOES {
    my ($self, $role) = @_;
    
    return 1 if ( lc $role eq 'getmail' );
    return $self->maybe::next::method( $role );
}

1;
