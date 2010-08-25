package WebGUI::AssetCollateral::Helpdesk2::Subscription;

use warnings;
use strict;

use WebGUI::Group;

sub subscribe {
    my ($class, %args) = @_;
    my ($session, $user, $group);

    $session = $args{session};
    use Data::Dumper;
    $session->log->error(Dumper \%args);
    
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
