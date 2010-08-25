package WebGUI::AssetCollateral::Helpdesk2::Email;

use Moose;
use WebGUI::HTML;
use WebGUI::Utility;

use namespace::clean -except => 'meta';

=head1 NAME

WebGUI::AssetCollateral::Helpdesk2::Email

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

=head1 METHODS

=cut

#-------------------------------------------------------------------

=head2 _build_body

=cut

sub _build_body {
    my $self  = shift;
	
    return join '', map { 
        my $c = $_->{content};
        $_->{type} =~ /html/ ? WebGUI::HTML::html2text($c) : $c;
    } grep { isBodyContent($_) } @{ $self->message->{parts} };
}

#-------------------------------------------------------------------

=head2 _build_storage

=cut

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

#-------------------------------------------------------------------

=head2 _build_user

=cut

sub _build_user {
    my $self      = shift;
    my $session   = $self->session;
    my ($address) = $self->message->{from} =~ /<(\S+\@\S+)>/;
    return WebGUI::User->newByEmail($session, $address)
        || WebGUI::User->new($session, 1);
}

=head2 body

The text of the email with html filtered out and entity encoded.

=cut

has body => (
    is         => 'ro',
    init_arg   => undef,
    isa        => 'Maybe[Str]',
    lazy_build => 1,
);

=head2 clear_body

=head2 clear_storage

=head2 clear_user

=head2 has_body

=head2 has_storage

=head2 has_user

=cut

#-------------------------------------------------------------------

sub isBodyContent {
    my $part = shift;
    return !$part->{filename} && $part->{type} =~ m<^text/(?:plain|html)>;
}

=head2 message

A hashref of the kind produced by WebGUI::Mail::Get

=cut

has message => (
    is       => 'ro',
    isa      => 'HashRef',
    required => 1,
);

=head2 meta

=head2 new

Standard Moose constructor.  Accepts the following arguments:

=head3 session

=head3 message

=head2 session

A WebGUI::Session

=cut

has session => (
    is       => 'ro',
    isa      => 'WebGUI::Session',
    required => 1,
);

=head2 storage

This will contain any attachments that came with the email.

=cut

has storage => (
    is         => 'ro',
    isa        => 'Maybe[WebGUI::Storage]',
    init_arg   => undef,
    lazy_build => 1,
);

=head2 subject

The subject of the email.

=cut

has subject => (
    is         => 'ro',
    isa        => 'Str',
    init_arg   => undef,
    lazy       => 1,
    default    => sub { shift->message->{subject} },
);

=head2 ticketId

The ticketId that the in-reply-to header indicated, if there is one.

=cut

has ticketId => (
    is       => 'ro',
    isa      => 'Maybe[Str]',
    init_arg => undef,
    lazy     => 1,
    default  => sub { $_[0]->message->{inReplyTo} =~ /^<(\d+)\.\d+\@/ && $1 }
);

=head2 user

The user that the email was from (or visitor, if an email match couldn't be
found).

=cut

has user => (
    is         => 'ro',
    init_arg   => undef,
    isa        => 'WebGUI::User',
    lazy_build => 1,
);

__PACKAGE__->meta->make_immutable;

1;
