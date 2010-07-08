package WebGUI::Asset::Wobject::Helpdesk2;

#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2010 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use WebGUI::International;
use JSON;

extends qw(
    WebGUI::Asset::Wobject
    WebGUI::AssetAspect::Installable
);

my @strings = split "\n", <<I18N;
Share this
link
Filter Tickets
Subscribe
Unsubscribe
Open New Ticket
#
Title
Opened By
Opened On
Assigned To
unassigned
Status
Last Reply
Status changed to
New Status
Open
Acknowledged
Waiting On External
Feedback Requested
Confirmed
Resolved
Add Attachment
Reply
Edit Ticket
Severity
Cosmetic
Minor
Critical
Fatal
Keywords
URL
WebGUI Version
WRE Version
OS
Assigned On
Assigned By
Title
Visibility
Public
Private
Save
Cancel
Match
Any
All
of the following rules
Ticket Status
Search
I18N

#-------------------------------------------------------------------

=head2 definition ( )

=cut

sub definition {
    my ($class, $session, $definition) = @_;
    my $i18n = WebGUI::International->new( $session, 'Asset_Helpdesk2' );

    tie my %properties, 'Tie::IxHash', (
        templateIdView => {
            fieldType   => "template",
            tab         => "display",
            namespace   => 'Helpdesk2/view',
            label       => $i18n->get('templateId label'),
            hoverHelp   => $i18n->get('templateIdView description'),
        },
    );

    push @$definition, {
        assetName         => $i18n->get('assetName'),
        autoGenerateForms => 1,
        tableName         => 'Asset_Helpdesk2',
        properties        => \%properties
    };
    return $class->SUPER::definition($session, $definition);
} ## end sub definition

#-------------------------------------------------------------------

=head2 view ( )

method called by the www_view method.  Returns a processed template
to be displayed within the page style.  

=cut

sub view {
    my $self    = shift;
    my $session = $self->session;
    my $style   = $session->style;
    my $url     = $session->url;
    my $config  = JSON::encode_json({
        base => $url->extras('/helpdesk2/'),
        app  => $self->getUrl,
    });
    $style->setRawHeadTags("<script>var helpdesk2 = $config</script>");
    $style->setScript('http://yui.yahooapis.com/combo?3.1.0/build/yui/yui.js');
    $style->setScript($url->extras('/helpdesk2/helpdesk2.js'));
    $style->setLink('http://yui.yahooapis.com/combo?3.1.0/build/cssreset/reset-min.css&3.1.0/build/cssfonts/fonts-min.css&3.1.0/build/cssbase/base-min.css',
        { rel => 'stylesheet' });

    return $self->processTemplate($self->get, $self->get('templateIdView'));
}

sub json {
    my ($self, $obj) = @_;
    $self->session->http->setMimeType('application/json');
    return JSON::encode_json($obj);
}

sub www_config {
    my $self = shift;
    my $i18n = WebGUI::International->new($self->session, 'Asset_Helpdesk2');
    return $self->json({
        strings    => { map { $_ => $i18n->get($_) } @strings },
        subscribed => 0,
    });
}

1;
