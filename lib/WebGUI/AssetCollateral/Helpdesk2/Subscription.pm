package WebGUI::AssetCollateral::Helpdesk2::Subscription;

use warnings;
use strict;

use WebGUI::Group;

=head1 NAME

WebGUI::AssetCollateral::Helpdesk2::Subscription

=head1 DESCRIPTION

Groups that disappear when there's no one in them

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

=head1 CLASS METHODS

=cut

#-------------------------------------------------------------------

=head2 subscribe (%args)

Subscribe to a group.  Takes the following args:

=head3 session

=head3 user

A userId or user object to subscribe to the grup

=head3 group

The group (or groupId) to subscribe to.  One will be created if this is
invalid somehow.

=head3 setGroup

A callback to pass the created group to, if one was created.

=cut

sub subscribe {
    my ($class, %args) = @_;
    my ($session, $user, $group);

    $session = $args{session};
    
    $user = $args{user} || return;
    $user = $user->userId if eval { $user->can('userId') };

    if ($group = $args{group}) {
        unless (eval { $group->can('getId') }) {
            $group = WebGUI::Group->new($session, $group);
        }
    }
    else {
        $group = WebGUI::Group->new($session, 'new', undef, 1);
        $group->showInForms(0);
        $group->name($args{name});
        $group->description("Users subscribed to $args{name}");
    }

    $group->addUsers([$user]);

    my $set = $args{setGroup};
    $set && $set->($group);
}

#-------------------------------------------------------------------

=head2 unsubscribe (%args)

Subscribe to a group.  Takes the following args:

=head3 session

=head3 user

A userId or user object to unsubscribe from the grup

=head3 group

The group (or groupId) to unsubscribe from.

=head3 unsetGroup

A callback to call if the group had no more users in it and was deleted.

=cut

sub unsubscribe {
    my ($class, %args) = @_;
    my ($session, $user, $group);

    $user = $args{user} || return;
    $user = $user->userId if eval { $user->can('userId') };

    $session = $args{session};

    return unless $group = $args{group};
    unless (eval { $group->can('getId') }) {
        $group = WebGUI::Group->new($session, $group);
    }
    
    $group->deleteUsers([$user]);

    @{ $group->getGroupsIn } && return;
    @{ $group->getUsers } && return;

    $group->delete();

    my $unset = $args{unsetGroup};
    $unset && $unset->($group);
}

1;
