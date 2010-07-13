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

use WebGUI::International;
use WebGUI::Helpdesk2::Search;
use WebGUI::Helpdesk2::Subscription;
use WebGUI::Storage;
use WebGUI::Group;
use JSON;

use base qw(
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
Reset
Tickets
I18N

#-------------------------------------------------------------------

=head2 definition ( )

=cut

sub definition {
    my ($class, $session, $definition) = @_;
    my $i18n = WebGUI::International->new( $session, 'Asset_Helpdesk2' );

    tie my %properties, 'Tie::IxHash', (
        subscribedGroupId => {
            fieldType  => 'group',
            tab        => 'security',
            label      => $i18n->get('subscribedGroupId label'),
            hoverHelp  => $i18n->get('subscribedGroupId description'),
            noFormPost => 1,
        },
        templateIdView => {
            fieldType   => 'template',
            tab         => 'display',
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

sub text {
    my ($self, $txt) = @_;
    $self->session->http->setMimeType('text/plain; charset=utf-8');
    return $txt;
}

sub json {
    my ($self, $obj) = @_;
    $self->session->http->setMimeType('application/json; charset=utf-8');
    return JSON::encode_json($obj);
}

sub ticketUrl {
    my ($self, $ticket) = @_;
    my $id    = $ticket->id;
    my $state = $self->session->url->escape(
        JSON::encode_json({open => $id, tickets => [$id]})
    );
    return $self->getUrl . "#helpdesk=$state";
}

sub www_config {
    my $self  = shift;
    my $session = $self->session;
    my $i18n    = WebGUI::International->new($session, 'Asset_Helpdesk2');
    my $group   = $self->subscribers;
    return $self->json({
        strings    => { map { $_ => $i18n->get($_) } @strings },
        subscribed => $group && $group->hasUser($session->user),
    });
}

sub www_ticketSource {
    my $self = shift;
    my $session = $self->session;
    my $form    = $session->form;

    my $json   = $form->get('filter');
    my $search = WebGUI::Helpdesk2::Search->new(
        helpdesk => $self,
        size     => $form->get('results'),
        start    => $form->get('startIndex'),
        sort     => $form->get('sort'),
        dir      => $form->get('dir'),
        filter   => $json && JSON::decode_json($json),
    );

    return $self->json({
        count   => $search->count,
        records => [ map { $_->render } $search->tickets ],
    });
}

sub renderUser {
    my ($self, $user) = @_;
    return unless $user;

    my $session = $self->session;
    my $id;
    if (eval { $user->can('userId') }) {
        $id = $user->userId;
    }
    else {
        $id = $user;
        $user = WebGUI::User->new($session, $id);
    }
    my $username = $user->get('username');
    my $fullname = join(' ', 
        grep { $_ } $user->get('firstName'), $user->get('lastName')
    ) || $username;
    return {
        id       => $id,
        username => $username,
        fullname => $fullname,
        profile  => $session->url->getSiteURL . 
            "?op=auth;module=profile;do=view;uid=$id",
    };
}

sub subscribe {
    my $self    = shift;
    my $session = $self->session;

    WebGUI::Helpdesk2::Subscription->subscribe(
        session  => $session,
        group    => $self->get('subscribedGroupId'),
        user     => $session->user,
        setGroup => sub {
            $self->update({ subscribedGroupId => shift->getId });
        }
    );
}

sub unsubscribe {
    my $self    = shift;
    my $session = $self->session;

    WebGUI::Helpdesk2::Subscription->unsubscribe(
        session    => $session,
        group      => $self->get('subscribedGroupId'),
        user       => $session->user,
        unsetGroup => sub {
            $self->update({ subscribedGroupId => '' });
        }
    );
}

sub www_toggleSubscription {
    my $self    = shift;
    my $session = $self->session;
    my $form    = $session->form;
    my $id      = $form->get('ticketId');
    my $obj     = $id ? $self->getTicket($id) : $self;
    my $group   = $obj->subscribers;

    if ($group && $group->hasUser($self->session->user)) {
        $obj->unsubscribe();
        return $self->text('unsubscribed');
    }
    else {
        $obj->subscribe();
        return $self->text('subscribed');
    }

}

sub subscribers {
    my $self = shift;
    my $id   = $self->get('subscribedGroupId') || return;
    return WebGUI::Group->new($self->session, $id);
}

sub www_userSource {
    my $self     = shift;
    my $session  = $self->session;
    my $db       = $session->db;
    my $q        = $session->form->get('query');
    my $query    = $db->dbh->quote("%$q%");
    my $fullName = q{
        trim(concat_ws(' ', trim(p.firstName), trim(p.lastName)))
    };
    my $sql = qq{
        select u.userId
          from users u join userProfileData p on u.userId = p.userId
         where u.username is not null
            and u.username <> ""
            and (u.username     like $query
                 or p.firstName like $query
                 or p.lastName  like $query
                 or $fullName   like $query)
         order by u.username
         limit 10
    };
    $self->json({ 
        users => [ map { $self->renderUser($_) } $db->buildArray($sql) ]
    });
}

sub getTicket {
    my ($self, $id) = @_;
    return WebGUI::Helpdesk2::Ticket->load($self, $id);
}

sub www_comment {
    my $self    = shift;
    my $session = $self->session;
    my $form    = $session->form;
    my $id      = $form->get('ticketId') || return;
    my $ticket  = $self->getTicket($id)  || return;

    my $body    = $form->get('body');
    my $status  = $form->get('status');
    my $storage = WebGUI::Storage->create($session);
    $storage->addFileFromFormPost('attachment');
    unless (@{ $storage->getFiles }) {
        $storage->delete;
        undef $storage;
    }

    $ticket->postComment($body, $status, $storage);
    return $self->text('ok');
}

sub www_ticket {
    my $self    = shift;
    my $session = $self->session;
    my $form    = $session->form;
    my $id      = $form->get('ticketId');
    my $ticket;
    if ($session->request->method eq 'GET') {
        $ticket = $self->getTicket($id);
        return $self->json($ticket->render);
    }

    if ($id eq 'new') {
        $ticket = WebGUI::Helpdesk2::Ticket->new(helpdesk => $self);
        $id = $ticket->id;
    }
    else {
        $ticket = $self->getTicket($id);
    }

    my @edit    = qw(title severity keywords webgui wre os);
    for my $f (@edit) {
        $ticket->$f($form->get($f));
    }

    if (my $victim = $form->get('assignedTo')) {
        $ticket->assign($victim);
    }

    $ticket->public($form->get('visibility') eq 'public');
    $ticket->save;
    return $self->text($id);
}

1;
