package WebGUI::Helpdesk2::Email;

use Moose;
use WebGUI::HTML;
use HTML::Parser;
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

sub scrubText {
    WebGUI::HTML::format(WebGUI::HTML::filter(shift, 'all'), 'text');
}

# Note: This is cribbed from Helpdesk v1's GetMail workflow. I don't want to
# change the semantics and I want even less to try to comprehend it. I take no
# responsibility for anything inside the following curly braces. -frodwith

sub scrubHTML {
	my $html = shift;
	my $newHtml  = "";
	my $skip     = 0;
    my $checkTag = "";
    my @skipTags = ("html","body","meta");

	my $startTagHandler = sub {
		my($tag, $num,$attr,$text) = @_;
        #print "Start Tag: $tag   Id: ".$attr->{id}."\n";
        if($checkTag eq "" && (
            $tag eq "head"
            || $tag eq "blockquote"
            || ($tag eq "hr" && $attr->{id} eq "EC_stopSpelling")  #Hotmail / MSN
            || ($tag eq "div" && $attr->{class} eq "gmail_quote")  #Gmail
            || ($tag eq "table" && $attr->{id} eq "hd_notification") #Original Posts (responses)
            || ($tag eq "table" && $attr->{border} == 0 && $attr->{cellspacing} == 2 && $attr->{cellpadding} == 3) #From Collab Systems
            ) 
        ) {
            $skip = 1;
            $checkTag  = $tag;
            return;
        }
        #Start counting nested tags
        $skip++ if($tag eq $checkTag);
        
        return if ($skip);
        return if (isIn($tag,@skipTags));
        
        $newHtml .= $text;
	};
    
    my $endTagHandler = sub {
        my ($tag, $num, $text) = @_;
        #print "End Tag: $tag \n";
        return if (isIn($tag,@skipTags));
        if($skip == 0) {
            $newHtml .= $text;
            return;
        }
        #Decrement the nested tag counter
        $skip-- if($tag eq $checkTag);
        #Unset checktag if the counter hits zero
        $checkTag = "" if($skip == 0);
    };

	my $textHandler = sub {
        my $text = shift;
		return if($skip);
        if ($text =~ /\S+/) {
            $newHtml .= $text;
		}
	};

	HTML::Parser->new(
        api_version     => 3,
		handlers        => [
            start => [$startTagHandler, "tagname, '+1', attr, text"],
			end   => [$endTagHandler, "tagname, '-1', text"],
			text  => [$textHandler, "text"],
		],
		marked_sections => 1,
	)->parse($html);
    
    $newHtml = WebGUI::HTML::cleanSegment($newHtml);    
	return $newHtml;
}

sub isBodyContent {
    my $part = shift;
    return !$part->{filename} && $part->{type} =~ m<^text/(?:plain|html)>;
}

sub _build_body {
    my $self  = shift;
	
    return join '', map { 
        my ($type, $text) = @{$_}{'type', 'content'};
        $type =~ /plain/ ? scrubText($text) : scrubHTML($text);
    } grep { isBodyContent($_) } @{ $self->message->{parts} }
}

has user => (
    is         => 'ro',
    init_arg   => undef,
    isa        => 'WebGUI:User',
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
    default  => sub { shift->message->{inReplyTo} =~ /^(\d+)!/ && $1 }
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
