use DateTime;
use Data::UUID;
use File::Spec;
use File::Path qw(make_path);
use File::Copy qw(mv);
use Encode;
use URI::Escape;
use JSON;
use Plack::Builder;
use Flea;

use warnings;
use strict;

use lib 'lib';
use Helpdesk::Ticket;

my %tickets;
my $max_id = 0;
sub next_id { ++$max_id }

sub charset {
    my $r = shift;
    $r->content_type =~ /; charset=(.*)$/;
    $1;
}

sub ticket_from_json {
    my $hash         = JSON::decode_json(shift);
    $hash->{baseUrl} = '/tickets';
    $hash->{public}  = delete $hash->{visibility} eq 'public';
    Helpdesk::Ticket->new($hash);
}

sub ticket_to_json {
    JSON::encode_json(shift->to_hash);
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

{
    opendir(my $dh, 'tickets');
    while (my $entry = readdir($dh)) {
        my ($id) = $entry =~ /(.*).json$/;
        next unless $id;
        $tickets{$id} = read_ticket($id);
        $max_id = $id if $id > $max_id;
    }
    closedir($dh);
}

builder {
    enable 'StackTrace';
    enable 'Static', path => qr{^/uploads};
    enable 'Static', path => qr{\.\w+$}, root => 'public/';
    bite {
        my %sorts = (
            id         => sub { $a->id         <=> $b->id         },
            title      => sub { $a->title      cmp $b->title      },
            openedBy   => sub { $a->openedBy   cmp $b->openedBy   },
            openedOn   => sub { $a->openedOn   <=> $b->openedOn   },
            assignedTo => sub { $a->assignedTo cmp $b->assignedTo },
            status     => sub { $a->status     cmp $b->status     },
            lastReply  => sub { $a->lastReply  <=> $b->lastReply  },
        );

        get '^/$' {
            file 'public/index.html';
        }

        get '^/tickets/(\d+)$' {
            my ($env, $id) = @_;
            my $ticket  = $tickets{$id} or http 404;
            json $ticket->to_hash;
        }

        post '^/tickets/(new|\d+)$' {
            my $request = request(shift);
            my $id      = shift;
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

            http 404 unless $ticket;

            my @edit    = qw(title severity keywords webgui wre os);
            my $charset = charset($request);
            for my $f (@edit) {
                $ticket->$f(decode($charset, $request->param($f)));
            }

            $ticket->assign('vrby', $request->param('assignedTo'));

            $ticket->public($request->param('visibility') eq 'public');
            write_ticket($ticket);
            text $id;
        }

        post '^/tickets/(\d+)/comment$' {
            my $request = request(shift);
            my $id      = shift;
            my $ticket  = $tickets{$id} or http 404;
            my $status  = $request->param('status');
            my $body    = $request->param('body');

            my @attachments;
            if (my @uploads = $request->uploads->get_all('attachment')) {
                my $random  = Data::UUID->new->create_b64;
                $random =~ s/==$//;
                my @parts = ('uploads', $random);
                make_path(File::Spec->catdir(@parts)) or http 500;
                for my $u (grep { $_->filename } @uploads) {
                    my $name = $u->filename;
                    my $path = File::Spec->catdir(@parts, $name);
                    mv($u->path, $path) or http 500;
                    push @attachments, Helpdesk::Attachment->new(
                        url  => uri_escape($path),
                        name => $name,
                        size => $u->size,
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
            response($request);
        }

        get '^/datasource$' {
            my $request = request(shift);
            my ($size, $start, $sort, $dir) 
                = map { scalar $request->param($_) } 
                qw(size start sort dir);

            $size  = 25 unless $size > 0;
            $start = 0 unless $start > 0;
            $sort  = 'id' unless exists $sorts{$sort};

            my @records = map  { $_->to_hash }
                          sort { $sorts{$sort}->() }
                          values %tickets;

            my $count   = @records;
            
            @records = reverse @records if ($dir eq 'desc');
            my @return  = grep { defined } @records[$start..$start+$size];
            
            json { records => \@return, total => $count };
        }
    }
}

# vim:ft=perl
