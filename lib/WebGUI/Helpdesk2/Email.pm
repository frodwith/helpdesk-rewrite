package WebGUI::Helpdesk2::Email;

use Moose;
use WebGUI::HTML;
use WebGUI::Utility;

use namespace::clean -except => 'meta';

has session => (
    is       => 'ro',
    isa      => 'WebGUI::Session',
    required => 1,
);

has message => (
    is       => 'ro',
    isa      => 'HashRef',
    required => 1,
);

has body => (
    is         => 'ro',
    init_arg   => undef,
    isa        => 'Maybe[Str]',
    lazy_build => 1,
);

sub isBodyContent {
    my $part = shift;
    return !$part->{filename} && $part->{type} =~ m<^text/(?:plain|html)>;
}

sub _build_body {
    my $self  = shift;
	
    return join '', map { 
        my $c = $_->{content};
        $_->{type} =~ /html/ ? WebGUI::HTML::html2text($c) : $c;
    } grep { isBodyContent($_) } @{ $self->message->{parts} };
}

has user => (
    is         => 'ro',
    init_arg   => undef,
    isa        => 'WebGUI::User',
    lazy_build => 1,
);

sub _build_user {
    my $self      = shift;
    my $session   = $self->session;
    my ($address) = $self->message->{from} =~ /<(\S+\@\S+)>/;
    return WebGUI::User->newByEmail($session, $address)
        || WebGUI::User->new($session, 1);
}

has ticketId => (
    is       => 'ro',
    isa      => 'Maybe[Str]',
    init_arg => undef,
    lazy     => 1,
    default  => sub { $_[0]->message->{inReplyTo} =~ /^<(\d+)\.\d+\@/ && $1 }
);

has subject => (
    is         => 'ro',
    isa        => 'Str',
    init_arg   => undef,
    lazy       => 1,
    default    => sub { shift->message->{subject} },
);

has storage => (
    is         => 'ro',
    isa        => 'Maybe[WebGUI::Storage]',
    init_arg   => undef,
    lazy_build => 1,
);

sub _build_storage {
    my $self        = shift;
    my @attachments = grep { !isBodyContent($_) } @{ $self->message->{parts} };

    return unless @attachments;

    my $session = $self->session;
    my $storage = WebGUI::Storage->create($session);

    for my $a (@attachments) {
		my $filename = $a->{filename} || do {
            my ($type) = $a->{type} =~ m</(.*)>;
            my $id = $session->id->generate;
            "$id.$type";
        };
		$storage->addFileFromScalar($filename, $a->{content});
    }

    return $storage;
}

__PACKAGE__->meta->make_immutable;

1;
