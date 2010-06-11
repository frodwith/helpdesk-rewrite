package Helpdesk::App;

use Helpdesk::Ticket;
use DateTime;
use Dancer qw(:syntax);
use Data::UUID;
use File::Path qw(make_path);
use File::Copy qw(mv);
use Encode;
use URI::Escape;

my %tickets;
my $max_id = 0;
sub next_id { ++$max_id }

sub charset {
    request->content_type =~ /; charset=(.*)$/;
    $1;
}

sub decode_param {
    decode(charset, params->{$_[0]});
}

sub ticket_from_json {
    my $hash         = from_json(shift);
    $hash->{baseUrl} = '/tickets';
    $hash->{public}  = delete $hash->{visibility} eq 'public';
    Helpdesk::Ticket->new($hash);
}

sub ticket_to_json {
    to_json(shift->to_hash);
}

sub read_ticket {
    my $id = shift;
    use autodie;
    open my $fh, '<', "tickets/$id.json";
    binmode($fh, ':utf8');
    my $ticket = ticket_from_json(do { local $/; <$fh> });
    close $fh;
    die "$id has mismatching id in file." if $ticket->id ne $id;
    return $ticket;
}

sub write_ticket {
    my $t  = shift;
    my $id = $t->id;
    use autodie;
    open my $fh, '>', "tickets/$id.json";
    binmode($fh, ':utf8');
    print $fh ticket_to_json($t);
    close $fh;
}

sub init {
    my ($class, $dir) = @_;
    opendir(my $dh, $dir);
    while (my $entry = readdir($dh)) {
        my ($id) = $entry =~ /(.*).json$/;
        next unless $id;
        $tickets{$id} = read_ticket($id);
        $max_id = $id if $id > $max_id;
    }
    closedir($dh);
}

get '/' => sub {
    send_file('/index.html');
};

get '/tickets/:id' => sub {
    if (my $ticket = $tickets{params->{id}}) {
        return to_json($ticket->to_hash);
    }
    else {
        send_error('Not found', 404);
    }
};

post '/tickets/:id/comment' => sub {
    my $id     = params->{id};
    my $status = params->{status};
    my $body   = params->{body};
    my $ticket = $tickets{$id};

    unless ($ticket) {
        send_error('Not found', 404);
        return;
    }

    my @attachments;
    if (my $uploads = request->uploads->{attachment}) {
        $uploads = [$uploads] unless ref $uploads eq 'ARRAY';
        my $random  = Data::UUID->new->create_b64;
        $random =~ s/==$//;
        my $urldir  = "uploads/$random";
        my $filedir = "public/$urldir";
        make_path($filedir);
        for my $u (grep { $_->filename } @$uploads) {
            my $name = $u->filename;
            my $path = "$filedir/$name";
            mv($u->tempname, $path);
            push @attachments, Helpdesk::Attachment->new(
                url  => uri_escape("$urldir/$name"),
                name => $name,
                size => (stat $path)[7],
            );
        }
    }
    $ticket->add_comment(Helpdesk::Comment->new(
        author      => 'dbell',
        body        => $body,
        status      => $status,
        attachments => \@attachments,
    ));
    $ticket->lastReply(DateTime->now);
    $ticket->status($status);
    write_ticket($ticket);
    'ok';
};

post '/tickets/:id' => sub {
    my $id = params->{id};
    my $ticket;
    if ($id eq 'new') {
        $ticket = Helpdesk::Ticket->new(
            openedBy => 'xtopher',
            baseUrl  => '/tickets',
            id       => next_id,
        );
        $id = $ticket->id;
        $tickets{$id} = $ticket;
    }
    else {
        $ticket = $tickets{$id};
    }

    unless ($ticket) {
        send_error('Not found', 404);
        return;
    }

    my @edit    = qw(title severity keywords webgui wre os);
    my $charset = charset;
    for my $f (@edit) {
        $ticket->$f(decode($charset, params->{$f}));
    }

    $ticket->assign('vrby', params->{assignedTo});

    $ticket->public(params->{visibility} eq 'public');
    write_ticket($ticket);
    $id;
};

my %sorts = (
    id         => sub { $a->id         <=> $b->id         },
    title      => sub { $a->title      cmp $b->title      },
    openedBy   => sub { $a->openedBy   cmp $b->openedBy   },
    openedOn   => sub { $a->openedOn   <=> $b->openedOn   },
    assignedTo => sub { $a->assignedTo cmp $b->assignedTo },
    status     => sub { $a->status     cmp $b->status     },
    lastReply  => sub { $a->lastReply  <=> $b->lastReply  },
);

get '/datasource' => sub {
    my $size    = params->{results};
    my $start   = params->{startIndex};
    $size       = 25 unless $size > 0;
    $start      = 0 unless $start > 0;
    my $sort    = params->{sort};
    $sort       = 'id' unless exists $sorts{$sort};
    my @records = map  { $_->to_hash }
                  sort { $sorts{$sort}->() }
                  values %tickets;
    my $count   = @records;
    
    @records = reverse @records if (params->{dir} eq 'desc');
    my @return  = grep { defined } @records[$start..$start+$size];
    
    to_json({ records => \@return, total => $count });
};

1;

# vim:ft=perl
