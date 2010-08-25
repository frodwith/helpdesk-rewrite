package WebGUI::Asset::Wobject::Helpdesk2;

use strict;
use warnings;

use Encode;
use WebGUI::International;
use WebGUI::AssetCollateral::Helpdesk2::Search;
use WebGUI::AssetCollateral::Helpdesk2::Subscription;
use WebGUI::AssetCollateral::Helpdesk2::Email;
use WebGUI::Storage;
use WebGUI::Group;
use WebGUI::Mail::Send;
use JSON;
use Scope::Guard qw(guard);

use base qw(
    WebGUI::AssetAspect::Installable
    WebGUI::AssetAspect::GetMail
    WebGUI::AssetAspect::Subscribable
    WebGUI::Asset::Wobject
);

=head1 NAME

WebGUI::Asset::Wobject::Helpdesk2

=head1 DESCRIPTION

A Wobject bug tracker.

=head1 LEGAL

-------------------------------------------------------------------
 WebGUI is Copyright 2001-2010 Plain Black Corporation.
-------------------------------------------------------------------
 Please read the legal notices (docs/legal.txt) and the license
 (docs/license.txt) that came with this distribution before using
 this software.
-------------------------------------------------------------------
 http://www.plainblack.com                     info@plainblack.com
-------------------------------------------------------------------

=head1 SECURITY

There are three levels of access to the Helpdesk.  Each successive group
implies access to the previous.

=head2 Public

Users in this group can see tickets, search for them, etc. but cannot affect
them in any way (no commenting, editing, etc).  This is the canView group.

=head2 Reporters

These users can post new tickets and comment on public tickets, but cannot
edit existing tickets (by changing status or assigning them, for instance).

=head2 Staff

These users can edit, change status, and see all private tickets.

=head2 Owners

The reporter of any particular ticket is its owner, and has staff permissions
on that ticket.

=head1 METHODS

=cut

sub _user {
    my ( $self, $user ) = @_;
    my $session = $self->session;
    $user ||= $session->user;
    $user = WebGUI::User->new( $session, $user )
        unless eval { $user->can('userId') };

    return $user;
}

sub canView {
    my ( $self, $user ) = @_;

    return $self->SUPER::canView($user) || $self->canReport($user);
}

sub canReport {
    my ( $self, $user ) = @_;

    return $self->_user($user)->isInGroup( $self->get('reportersGroupId') )
        || $self->canStaff($user);
}

sub canStaff {
    my ( $self, $user ) = @_;

    return $self->_user($user)->isInGroup( $self->get('staffGroupId') );
}

sub i18n {
    my $self = shift;
    my $session = shift || $self->session;
    WebGUI::International->new( $session, 'Asset_Helpdesk2' );
}

sub getContentLastModified {time}

#-------------------------------------------------------------------

=head2 definition ( )

=cut

sub definition {
    my ( $class, $session, $definition ) = @_;
    my $i18n = $class->i18n($session);

    tie my %properties, 'Tie::IxHash', (
        staffGroupId => {
            fieldType => 'group',
            tab       => 'security',
            label     => $i18n->get('staffGroupId label'),
            hoverHelp => $i18n->get('staffGroupId description'),
        },
        reportersGroupId => {
            fieldType => 'group',
            tab       => 'security',
            label     => $i18n->get('reportersGroupId label'),
            hoverHelp => $i18n->get('reportersGroupId description'),
        },
        templateIdView => {
            fieldType => 'template',
            tab       => 'display',
            namespace => 'Helpdesk2/view',
            label     => $i18n->get('templateId label'),
            hoverHelp => $i18n->get('templateIdView description'),
        },
        mailingListAddress => {
            fieldType => 'text',
            tab       => 'display',
            label     => $i18n->get('mailingListAddress label'),
            hoverHelp => $i18n->get('mailingListAddress description'),
        },
        );

    push @$definition, {
        assetName         => $i18n->get('assetName'),
        autoGenerateForms => 1,
        tableName         => 'Asset_Helpdesk2',
        className         => __PACKAGE__,
        properties        => \%properties
        };
    return $class->next::method( $session, $definition );
} ## end sub definition

sub historyId { join( '-', 'helpdesk2', shift->getId, 'history' ) }

#-------------------------------------------------------------------

=head2 view ( )

method called by the www_view method.  Returns a processed template
to be displayed within the page style.  

=cut

sub view {
    my $self    = shift;
    my $session = $self->session;
    my $style   = $session->style;
    $style->setLink(
        'http://yui.yahooapis.com/combo?3.1.0/build/cssreset/reset-min.css&3.1.0/build/cssfonts/fonts-min.css&3.1.0/build/cssbase/base-min.css',
        { rel => 'stylesheet' }
    );
    $style->setScript('http://yui.yahooapis.com/combo?3.1.0/build/yui/yui.js');
    $style->setScript( $session->url->extras('/helpdesk2/helpdesk2.js') );

    my $c = $self->processTemplate( $self->get, $self->get('templateIdView') );

    my $assetId = $self->getId;
    my $div     = "helpdesk2-$assetId-div";
    my $config  = JSON::encode_json( {
            rootId    => $div,
            historyId => $self->historyId,
            url       => $self->getUrl,
        }
    );

    return qq{
        <div class="helpdesk yui-skin-sam yui3-skin-sam" id="$div">$c</div>
        <iframe id='yui-history-iframe'
            src='/extras/helpdesk2/blank.html'></iframe>
        <input id='yui-history-field' type='hidden' />
        <script>Helpdesk2.register($config);</script>
    };
} ## end sub view

sub forbidden {
    return shift->session->privilege->insufficient;
}

sub text {
    my ( $self, $txt ) = @_;
    $self->session->http->setMimeType('text/plain; charset=utf-8');
    return $txt;
}

sub json {
    my ( $self, $obj ) = @_;
    $self->session->http->setMimeType('application/json; charset=utf-8');
    return JSON::encode_json($obj);
}

sub ticketUrl {
    my ( $self, $ticket ) = @_;
    my $id = eval { $ticket->id } || $ticket;
    $self->session->url->getSiteURL . $self->getUrl . "/$id";
}

{

    my @strings = split "\n", <<I18N;
Share this
link
Filter Tickets
Subscribe
Unsubscribe
Open New Ticket
#
Title
Comment
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
Closed
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
Add New
Ticket Status
Search
Reset
Tickets
I18N

    sub www_config {
        my $self = shift;
        return $self->forbidden unless $self->canView;

        my $session = $self->session;
        my $i18n    = $self->i18n;
        my $group   = $self->getSubscriptionGroup;
        return $self->json( {
                strings => { map { $_ => $i18n->get($_) } @strings },
                subscribed => $group && $group->hasUser( $session->user ),
                reporter   => $self->canReport,
                staff      => $self->canStaff,
            }
        );
    }
}

sub www_ticketSource {
    my $self = shift;
    return $self->forbidden unless $self->canView;

    my $session = $self->session;
    my $form    = $session->form;

    my %args = ( helpdesk => $self );
    if ( my $json = $form->get('filter') ) {
        $args{filter} = JSON::decode_json($json);
    }
    my %tr = (
        size  => 'results',
        start => 'startIndex',
        sort  => 'sort',
        dir   => 'dir',
    );
    for my $k ( keys %tr ) {
        my $v = $form->get( $tr{$k} ) or next;
        $args{$k} = $v;
    }
    my $search = WebGUI::AssetCollateral::Helpdesk2::Search->new( \%args );

    return $self->json( {
            count   => $search->count,
            records => [ map { $_->render } $search->tickets ],
        }
    );
} ## end sub www_ticketSource

sub dispatch {
    my ( $self, $fragment ) = @_;
    if ( $fragment =~ m|^/(\d+)/?$| ) {
        my $session   = $self->session;
        my $url       = $session->url;
        my $state     = $url->escape( JSON::encode_json( { open => $1, tickets => [$1] } ) );
        my $history   = $self->historyId;
        my $ticketUrl = $url->getSiteURL . $self->getUrl . "#$history=$state";
        $session->http->setRedirect($ticketUrl);
        return 'redirect';
    }
    return $self->SUPER::dispatch($fragment);
}

sub renderUser {
    my ( $self, $user ) = @_;
    return unless $user;

    my $session = $self->session;
    my $id;
    if ( eval { $user->can('userId') } ) {
        $id = $user->userId;
    }
    else {
        $id = $user;
        $user = WebGUI::User->new( $session, $id );
    }
    my $username = $user->get('username');
    my $fullname = join( ' ', grep {$_} $user->get('firstName'), $user->get('lastName') ) || $username;
    return {
        id       => $id,
        username => $username,
        fullname => $fullname,
        profile  => $session->url->getSiteURL . "?op=auth;module=profile;do=view;uid=$id",
    };
} ## end sub renderUser

# We'll create our own subscription groups (so we can delete them when they
# have nobody in them)
sub createSubscriptionGroup { }

# we'll call notifySubscribers manually when tickets are opened/updated
sub shouldSkipNotification {1}

sub subscribe {
    my ( $self, $user ) = @_;
    my $session = $self->session;
    my $id      = $self->getId;

    WebGUI::AssetCollateral::Helpdesk2::Subscription->subscribe(
        session  => $session,
        group    => $self->getSubscriptionGroup,
        user     => $user || $session->user,
        name     => "Helpdesk $id",
        setGroup => sub {
            $self->update( { subscriptionGroupId => shift->getId } );
        }
    );
}

sub unsubscribe {
    my ( $self, $user ) = @_;
    my $session = $self->session;

    WebGUI::AssetCollateral::Helpdesk2::Subscription->unsubscribe(
        session    => $session,
        group      => $self->getSubscriptionGroup,
        user       => $user || $session->user,
        unsetGroup => sub {
            $self->update( { subscriptionGroupId => '' } );
        }
    );
}

sub www_toggleSubscription {
    my $self = shift;
    return $self->forbidden unless $self->canView;

    my $session = $self->session;
    my $form    = $session->form;
    my $id      = $form->get('ticketId');
    my $obj;
    if ($id) {
        $obj = $self->getTicket($id);
        return $self->forbidden
            unless $obj->public || $obj->isOwner || $self->canStaff;
    }
    else {
        $obj = $self;
    }

    my $group = $obj->getSubscriptionGroup;

    if ( $group && $group->hasUser( $self->session->user ) ) {
        $obj->unsubscribe();
        return $self->text('unsubscribed');
    }
    else {
        $obj->subscribe();
        return $self->text('subscribed');
    }
} ## end sub www_toggleSubscription

sub getSubscriptionGroup {
    my $self = shift;
    my $id = $self->get('subscriptionGroupId') || return undef;
    return WebGUI::Group->new( $self->session, $id );
}

sub www_userSource {
    my $self = shift;
    return $self->forbidden unless $self->canView;

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
    $self->json( { users => [ map { $self->renderUser($_) } $db->buildArray($sql) ] } );
} ## end sub www_userSource

sub getTicket {
    my ( $self, $id ) = @_;
    return WebGUI::AssetCollateral::Helpdesk2::Ticket->load( $self, $id );
}

sub attachmentStorage {
    my ( $self, $name ) = @_;
    my $storage = WebGUI::Storage->create( $self->session );
    $storage->addFileFromFormPost($name);
    unless ( @{ $storage->getFiles } ) {
        $storage->delete;
        return undef;
    }
    return $storage;
}

sub www_comment {
    my $self = shift;
    return $self->forbidden unless $self->canReport;

    my $form   = $self->session->form;
    my $id     = $form->get('ticketId') || return;
    my $ticket = $self->getTicket($id) || return;
    my $body   = $form->get('body');
    my $status = ( $ticket->isOwner || $self->canStaff ) && $form->get('status');

    my $storage = $self->attachmentStorage('attachment');
    $ticket->postComment( $body, $status, $storage );
    return $self->text('ok');
}

sub getSubscriptionTemplateNamespace {'Helpdesk2/email'}

sub notifySubscribers {
    my ( $self, $ticket ) = @_;
    my $group   = $self->getSubscriptionGroup || return;
    my $session = $self->session;
    my $tid     = $ticket->id;
    my $aid     = $self->getId;
    my $count   = $ticket->commentCount;
    my $prev    = $count - 1;
    my $addr    = $self->get('mailingListAddress')
        || $self->get('getMailAccount');
    my $subj = sprintf( '%s #%d', $self->getTitle, $ticket->id );
    $subj = "RE: $subj" if $count > 1;

    no warnings 'once';
    local *_makeMessageId = sub {"$tid.$count\@$aid"};
    local *getTemplateVars = sub {
        {   helpdesk  => $self->get,
            ticket    => $ticket->render,
            commentor => $self->renderUser( $session->user ),
        };
    };
    local *getSubscriptionGroup = sub {
        if ( my $tg = $ticket->groupId ) {
            my $g = WebGUI::Group->new( $session, 'new' );
            $g->isAdHocMailGroup(1);
            $g->deleteGroups( [3] );
            $g->addGroups( [ $group->getId, $tg ] );
            return $g;
        }
        return $group;
    };

    $self->SUPER::notifySubscribers( {
            subject     => $subj,
            from        => $addr,
            replyTo     => $addr,
            listAddress => $addr,
            inReplyTo   => "$tid.$prev\@$aid",
        }
    );
} ## end sub notifySubscribers

sub www_ticket {
    my $self = shift;
    return $self->forbidden unless $self->canView;

    my $session = $self->session;
    my $form    = $session->form;
    my $id      = $form->get('ticketId');
    my $ticket;

    if ( $session->request->method eq 'GET' ) {
        $ticket = $self->getTicket($id);

        return $self->forbidden
            unless $ticket->public || $ticket->isOwner || $self->canStaff;

        return $self->json( $ticket->render );
    }

    if ( $id eq 'new' ) {
        return $self->forbidden unless $self->canReport;
        $ticket = WebGUI::AssetCollateral::Helpdesk2::Ticket->new( helpdesk => $self );
        $id = $ticket->id;
        my $storage = $self->attachmentStorage('attachment');
        my $comment = $form->get('comment');
        $ticket->postComment( $comment, 'open', $storage );
    }
    else {
        $ticket = $self->getTicket($id);
        return $self->forbidden unless $ticket->isOwner || $self->canStaff;
    }

    my @edit = qw(title severity keywords webgui wre os);
    for my $f (@edit) {
        $ticket->$f( $form->get($f) );
    }

    if ( my $victim = $form->get('assignedTo') ) {
        $ticket->assign($victim);
    }

    $ticket->public( $form->get('visibility') eq 'public' );
    $ticket->save;
    return $self->text($id);
} ## end sub www_ticket

sub errorMail {
    my ( $self, $email, $error ) = @_;
    my $msg   = $email->message;
    my $reply = $self->reply($msg);
    my $body  = $self->i18n->get($error) . "\n";

    if ( my $quote = $email->body ) {
        $quote =~ s/^/> /mg;
        $body .= "\n$msg->{from} wrote:\n$quote";
    }

    my $entity = $reply->getMimeEntity;
    $entity->parts( [] );
    $entity->attach(
        Type     => 'text/plain',
        Charset  => 'UTF-8',
        Encoding => 'quoted-printable',
        Data     => encode( 'utf8', $body ),
    );
    $entity->make_singlepart;

    $reply->queue;
} ## end sub errorMail

sub onMail {
    my ( $self, $message ) = @_;
    my $session = $self->session;

    $message = WebGUI::AssetCollateral::Helpdesk2::Email->new(
        session => $session,
        message => $message,
    );

    my $e = sub { $self->errorMail( $message, shift ) };

    my $body = $message->body or return $e->('onMail no content');

    my $user = $message->user;
    my $old  = $session->user;

    my $guard = guard { $session->user( { user => $old } ) };
    $session->user( { user => $user } );

    return $e->('onMail forbidden') unless $self->canReport;

    my $ticket = $self->getTicket( $message->ticketId );

    # This should be undefined if the poster is not allowed to
    # change the ticket status
    my $status;

    if ($ticket) {
        if ( $self->canStaff || $ticket->isOwner ) {
            $status = 'open';
        }
    }
    else {
        $ticket = WebGUI::AssetCollateral::Helpdesk2::Ticket->open(
            helpdesk => $self,
            title    => $message->subject,
        );
        $status = 'open';
    }

    $ticket->postComment( $body, $status, $message->storage );
} ## end sub onMail

1;
