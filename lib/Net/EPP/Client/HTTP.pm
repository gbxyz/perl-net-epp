package Net::EPP::Client::HTTP;
use Carp;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Cookies;
use base qw(Net::EPP::Client);
use constant EPP_MEDIA_TYPE => q{application/epp+xml};
use warnings;
use strict;

sub new {
    my ($package, %params) = @_;

    my $self = bless(\%params, $package);

    $self->{ua} = LWP::UserAgent->new;

    return $self;
}

sub _connect_tcp    { croak(q{this should never be called!}) }
sub _connect_unix   { croak(q{this should never be called!}) }
sub connected       { exists(shift->{cookies}) }
sub ua              { shift->{ua} }
sub url             { shift->{url} }
sub push            { push(@{shift->{queue}}, pop) }
sub shift           { shift(@{shift->{queue}}) }

sub connect {
    my ($self, %params) = @_;

    croak(q{already connected})         if ($self->connected);
    croak(q{missing 'url' parameter})   if (!exists($params{url}));

    $self->{url}        = $params{url};
    $self->{cookies}    = {};
    $self->{queue}      = [];

    $self->ua->cookie_jar($self->{cookies});
    $self->ua->ssl_opts(map { $_ => $params{$_} } grep { /^SSL/i } keys(%params));

    $self->push($self->ua->request(GET($self->url)));

    return 1;
}

sub disconnect {
    my $self = CORE::shift;
    $self->ua->cookie_jar(undef);
    $self->{queue} = [];
}

sub send_frame {
    my ($self, $frame) = @_;

    my $req = POST($self->url);
    $req->header(q{content-type} => EPP_MEDIA_TYPE);
    $req->content($self->_get_xml($frame));

    $self->push($self->ua->request($req));
}

sub get_frame {
    my $self = CORE::shift;

    my $response = $self->shift;

    if ($response->is_error) {
        croak($response->status_line);
    }

    return $self->parse_response($response->decoded_content);
}

1;
