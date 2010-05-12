# Copyright (c) 2010 CentralNic Ltd. All rights reserved. This program is
# free software; you can redistribute it and/or modify it under the same
# terms as Perl itself.
# 
# $Id: Simple.pm,v 1.10 2008/04/08 12:57:11 gavin Exp $
package Net::EPP::Simple;
use Carp;
use Digest::SHA1 qw(sha1_hex);
use Net::EPP::Frame;
use Net::EPP::ResponseCodes;
use Time::HiRes qw(time);
use UNIVERSAL qw(isa);
use base qw(Net::EPP::Client);
use constant EPP_XMLNS	=> 'urn:ietf:params:xml:ns:epp-1.0';
use vars qw($Error $Code $Message);
use strict;
use warnings;

our $Error	= '';
our $Code	= OK;
our $Message	= '';

=pod

=head1 NAME

Net::EPP::Simple - a simple EPP client interface for the most common jobs

=head1 SYNOPSIS

	#!/usr/bin/perl
	use Net::EPP::Simple;
	use strict;

	my $epp = Net::EPP::Simple->new(
		host	=> 'epp.nic.tld',
		user	=> 'my-id',
		pass	=> 'my-password',
	);

	my $domain = 'example.tld';

	if ($epp->check_domain($domain) == 1) {
		print "Domain is available\n" ;

	} else {
		my $info = $epp->domain_info($domain);
		printf("Domain was registered on %s by %s\n", $info->{crDate}, $info->{crID});

	}

=head1 DESCRIPTION

EPP is the Extensible Provisioning Protocol. EPP (defined in RFC 4930) is an
application layer client-server protocol for the provisioning and management of
objects stored in a shared central repository. Specified in XML, the protocol
defines generic object management operations and an extensible framework that
maps protocol operations to objects. As of writing, its only well-developed
application is the provisioning of Internet domain names, hosts, and related
contact details.

This module provides a high level interface to the EPP protocol. It hides all
the boilerplate of connecting, logging in, building request frames and parsing
response frames behind a simple, Perlish interface.

It is based on the C<Net::EPP::Client> module and uses C<Net::EPP::Frame>
to build request frames.

=head1 CONSTRUCTOR

The constructor for C<Net::EPP::Simple> has the same general form as the
one for C<Net::EPP::Client>, but with the following exceptions:

=over

=item * Unless otherwise set, C<port> defaults to 700

=item * Unless the C<no_ssl> parameter is set, SSL is always on

=item * You can use the C<user> and C<pass> parameters to supply authentication information.

=item * The C<timeout> parameter controls how long the client waits for a response from the server before returning an error.

=back

The constructor will establish a connection to the server and retrieve the
greeting (which is available via C<$epp-E<gt>{greeting}>) and then send a
C<E<lt>loginE<gt>> request.

If the login fails, the constructor will return C<undef> and set
C<$Net::EPP::Simple::Error> and C<$Net::EPP::Simple::Code>.

=cut

sub new {
	my ($package, %params) = @_;
	$params{dom}		= 1;

	eval 'use Config::Simple';
	if (!$@) {
		# we have Config::Simple, so let's try to parse the RC file:
		my $rcfile = $ENV{'HOME'}.'/.net-epp-simple-rc';
		if (-e $rcfile) {
			my $config = Config::Simple->new($rcfile);

			# if no host was defined in the constructor, use the default (if specified):
			if (!defined($params{'host'}) && $config->param('default.default')) {
				$params{'host'} = $config->param('default.default');
			}

			# if no debug level was defined in the constructor, use the default (if specified):
			if (!defined($params{'debug'}) && $config->param('default.debug')) {
				$params{'debug'} = $config->param('default.debug');
			}

			# grep through the file's values for settings for the selected host:
			my %vars = $config->vars;
			foreach my $key (grep { /^$params{'host'}\./ } keys(%vars)) {
				my $value = $vars{$key};
				$key =~ s/^$params{'host'}\.//;
				$params{$key} = $value unless (defined($params{$key}));
			}
		}
	}

	$params{port}		= (defined($params{port}) && int($params{port}) > 0 ? $params{port} : 700);
	$params{ssl}		= ($params{no_ssl} ? undef : 1);

	my $self = $package->SUPER::new(%params);

	$self->{user}		= $params{user};
	$self->{pass}		= $params{pass};
	$self->{debug} 		= (defined($params{debug}) ? int($params{debug}) : undef);
	$self->{timeout}	= (defined($params{timeout}) && int($params{timeout}) > 0 ? $params{timeout} : 5);
	$self->{reconnect}	= (defined($params{reconnect}) ? int($params{reconnect}) : 3);
	$self->{connected}	= undef;
	$self->{authenticated}	= undef;
	$self->{connect}	= (exists($params{connect}) ? $params{connect} : 1);
	$self->{login}		= (exists($params{login}) ? $params{login} : 1);

	bless($self, $package);

	if ($self->{connect}) {
		return ($self->_connect($self->{login}) ? $self : undef);

	} else {
		return $self;

	}
}

sub _connect {
	my ($self, $login) = @_;

	$self->debug(sprintf('Attempting to connect to %s:%d', $self->{host}, $self->{port}));
	eval {
		$self->{greeting} = $self->connect;
	};
	if ($@ ne '' || ref($self->{greeting}) ne 'Net::EPP::Frame::Response') {
		chomp($@);
		$@ =~ s/ at .+ line .+$//;
		$self->debug($@);
		$Code = COMMAND_FAILED;
		$Error = $Message = $@;
		return undef;
	}

	$self->{connected} = 1;

	map { $self->debug('S: '.$_) } split(/\n/, $self->{greeting}->toString(1));

	$self->debug('Connected OK');

	if ($login) {
		return $self->_login;

	} else {
		return 1;

	}
}

sub _login {
	my $self = shift;

	$self->debug('preparing login frame');
	my $login = Net::EPP::Frame::Command::Login->new;

	$login->clID->appendText($self->{user});
	$login->pw->appendText($self->{pass});
	$login->version->appendText($self->{greeting}->getElementsByTagNameNS(EPP_XMLNS, 'version')->shift->firstChild->data);
	$login->lang->appendText($self->{greeting}->getElementsByTagNameNS(EPP_XMLNS, 'lang')->shift->firstChild->data);

	my $objects = $self->{greeting}->getElementsByTagNameNS(EPP_XMLNS, 'objURI');
	while (my $object = $objects->shift) {
		my $el = $login->createElement('objURI');
		$el->appendText($object->firstChild->data);
		$login->svcs->appendChild($el);
	}
	$objects = $self->{greeting}->getElementsByTagNameNS(EPP_XMLNS, 'extURI');
	while (my $object = $objects->shift) {
		my $el = $login->createElement('objURI');
		$el->appendText($object->firstChild->data);
		$login->svcs->appendChild($el);
	}

	$self->debug(sprintf("Attempting to login as client ID '%s'", $self->{user}));
	my $response = $self->request($login);

	$Code = $self->_get_response_code($response);
	$Message = $self->_get_message($response);

	$self->debug(sprintf('%04d: %s', $Code, $Message));

	if ($Code > 1999) {
		$Error = "Error logging in (response code $Code)";
		return undef;

	} else {
		$self->{authenticated} = 1;

	}

	return 1;
}

=pod

=head1 Availability Checks

You can do a simple C<E<lt>checkE<gt>> request for an object like so:

	my $result = $epp->check_domain($domain);

	my $result = $epp->check_host($host);

	my $result = $epp->check_contact($contact);

Each of these methods has the same profile. They will return one of the
following:

=over

=item * C<undef> in the case of an error (check C<$Net::EPP::Simple::Error> and C<$Net::EPP::Simple::Code>).

=item * C<0> if the object is already provisioned.

=item * C<1> if the object is available.

=cut

sub check_domain {
	my ($self, $domain) = @_;
	return $self->_check('domain', $domain);
}

sub check_host {
	my ($self, $host) = @_;
	return $self->_check('host', $host);
}

sub check_contact {
	my ($self, $contact) = @_;
	return $self->_check('contact', $contact);
}

sub _check {
	my ($self, $type, $identifier) = @_;
	my $frame;
	if ($type eq 'domain') {
		$frame = Net::EPP::Frame::Command::Check::Domain->new;
		$frame->addDomain($identifier);

	} elsif ($type eq 'contact') {
		$frame = Net::EPP::Frame::Command::Check::Contact->new;
		$frame->addContact($identifier);

	} elsif ($type eq 'host') {
		$frame = Net::EPP::Frame::Command::Check::Host->new;
		$frame->addHost($identifier);

	} else {
		$Error = "Unknown object type '$type'";
		return undef;
	}

	my $response = $self->_request($frame);

	if (!$response) {
		return undef;

	} else {
		$Code = $self->_get_response_code($response);
		$Message = $self->_get_message($response);

		if ($Code > 1999) {
			$Error = sprintf("Server returned a %d code", $Code);
			return undef;

		} else {
			my $xmlns = (Net::EPP::Frame::ObjectSpec->spec($type))[1];
			my $key;
			if ($type eq 'domain' || $type eq 'host') {
				$key = 'name';

			} elsif ($type eq 'contact') {
				$key = 'id';

			}
			return $response->getNode($xmlns, $key)->getAttribute('avail');

		}
	}
}

=pod

=head1 Retrieving Object Information

You can retrieve information about an object by using one of the following:

	my $info = $epp->domain_info($domain, $authInfo, $follow);

	my $info = $epp->host_info($host);

	my $info = $epp->contact_info($contact, $authInfo);

C<Net::EPP::Simple> will construct an C<E<lt>infoE<gt>> frame and send
it to the server, then parse the response into a simple hash ref. The
layout of the hash ref depends on the object in question. If there is an
error, these methods will return C<undef>, and you can then check
C<$Net::EPP::Simple::Error> and C<$Net::EPP::Simple::Code>.

If C<$authInfo> is defined, it will be sent to the server as per RFC
4931, Section 3.1.2 and RRC 4933, Section 3.1.2. If the supplied
authInfo code is validated by the registry, additional information will
appear in the response. If it is invalid, you should get an error.

If the C<$follow> parameter is true, then C<Net::EPP::Simple> will also
retrieve the relevant host and contact details for a domain: instead of
returning an object name or ID for the domain's registrant, contact
associations, DNS servers or subordinate hosts, the values will be
replaced with the return value from the appropriate C<host_info()> or
C<contact_info()> command (unless there was an error, in which case the
original object ID will be used instead).

=cut

sub domain_info {
	my ($self, $domain, $authInfo, $follow) = @_;
	my $result = $self->_info('domain', $domain, $authInfo);
	return $result if (ref($result) ne 'HASH' || !$follow);

	if (defined($result->{'ns'}) && ref($result->{'ns'}) eq 'ARRAY') {
		for (my $i = 0 ; $i < scalar(@{$result->{'ns'}}) ; $i++) {
			my $info = $self->host_info($result->{'ns'}->[$i]);
			$result->{'ns'}->[$i] = $info if (ref($info) eq 'HASH');
		}
	}

	if (defined($result->{'hosts'}) && ref($result->{'hosts'}) eq 'ARRAY') {
		for (my $i = 0 ; $i < scalar(@{$result->{'hosts'}}) ; $i++) {
			my $info = $self->host_info($result->{'hosts'}->[$i]);
			$result->{'hosts'}->[$i] = $info if (ref($info) eq 'HASH');
		}
	}

	my $info = $self->contact_info($result->{'registrant'});
	$result->{'registrant'} = $info if (ref($info) eq 'HASH');

	foreach my $type (keys(%{$result->{'contacts'}})) {
		my $info = $self->contact_info($result->{'contacts'}->{$type});
		$result->{'contacts'}->{$type} = $info if (ref($info) eq 'HASH');
	}

	return $result;
}

sub host_info {
	my ($self, $host) = @_;
	return $self->_info('host', $host);
}

sub contact_info {
	my ($self, $contact, $authInfo) = @_;
	return $self->_info('contact', $contact, $authInfo);
}

sub _info {
	my ($self, $type, $identifier, $authInfo) = @_;
	my $frame;
	if ($type eq 'domain') {
		$frame = Net::EPP::Frame::Command::Info::Domain->new;
		$frame->setDomain($identifier);

	} elsif ($type eq 'contact') {
		$frame = Net::EPP::Frame::Command::Info::Contact->new;
		$frame->setContact($identifier);

	} elsif ($type eq 'host') {
		$frame = Net::EPP::Frame::Command::Info::Host->new;
		$frame->setHost($identifier);

	} else {
		$Error = "Unknown object type '$type'";
		return undef;

	}

	if (defined($authInfo) && $authInfo ne '') {
		$self->debug('adding authInfo element to request frame');
		my $el = $frame->createElement((Net::EPP::Frame::ObjectSpec->spec($type))[0].':authInfo');
		my $pw = $frame->createElement((Net::EPP::Frame::ObjectSpec->spec($type))[0].':pw');
		$pw->appendChild($frame->createTextNode($authInfo));
		$el->appendChild($pw);
		$frame->getNode((Net::EPP::Frame::ObjectSpec->spec($type))[1], 'info')->appendChild($el);
	}

	my $response = $self->_request($frame);

	if (!$response) {
		return undef;

	} else {
		$Code = $self->_get_response_code($response);
		$Message = $self->_get_message($response);

		if ($Code > 1999) {
			$Error = sprintf("Server returned a %d code", $Code);
			return undef;

		} else {
			my $infData = $response->getNode((Net::EPP::Frame::ObjectSpec->spec($type))[1], 'infData');

			if ($type eq 'domain') {
				return $self->_domain_infData_to_hash($infData);

			} elsif ($type eq 'contact') {
				return $self->_contact_infData_to_hash($infData);

			} elsif ($type eq 'host') {
				return $self->_host_infData_to_hash($infData);

			}
		}
	}
}

sub _get_common_properties_from_infData {
	my ($self, $infData, @extra) = @_;
	my $hash = {};

	my @default = qw(roid clID crID crDate upID upDate trDate);

	foreach my $name (@default, @extra) {
		my $els = $infData->getElementsByLocalName($name);
		$hash->{$name} = $els->shift->textContent if ($els->size > 0);
	}

	my $codes = $infData->getElementsByLocalName('status');
	while (my $code = $codes->shift) {
		push(@{$hash->{status}}, $code->getAttribute('s'));
	}

	return $hash;
}

=pod

=head2 Domain Information

The hash ref returned by C<domain_info()> will usually look something
like this:

	$info = {
	  'contacts' => {
	    'admin' => 'contact-id'
	    'tech' => 'contact-id'
	    'billing' => 'contact-id'
	  },
	  'registrant' => 'contact-id',
	  'clID' => 'registrar-id',
	  'roid' => 'tld-12345',
	  'status' => [
	    'ok'
	  ],
	  'authInfo' => 'abc-12345',
	  'name' => 'example.tld',
	  'trDate' => '2007-01-18T11:08:03.0Z',
	  'ns' => [
	    'ns0.example.com',
	    'ns1.example.com',
	  ],
	  'crDate' => '2001-02-16T12:06:31.0Z',
	  'exDate' => '2009-02-16T12:06:31.0Z',
	  'crID' => 'registrar-id',
	  'upDate' => '2007-08-29T04:02:12.0Z',
	  hosts => [
	    'ns0.example.tld',
	    'ns1.example.tld',
	  ],
	};

Members of the C<contacts> hash ref may be strings or, if there are
multiple associations of the same type, an anonymous array of strings.
If the server uses the "hostAttr" model instead of "hostObj", then the
C<ns> member will look like this:

	$info->{ns} = [
	  {
	    name => 'ns0.example.com',
	    addrs => [
	      type => 'v4',
	      addr => '10.0.0.1',
	    ],
	  },
	  {
	    name => 'ns1.example.com',
	    addrs => [
	      type => 'v4',
	      addr => '10.0.0.2',
	    ],
	  },
	];

Note that there may be multiple members in the C<addrs> section and that
the C<type> attribute is optional.

=cut

sub _domain_infData_to_hash {
	my ($self, $infData) = @_;

	my $hash = $self->_get_common_properties_from_infData($infData, 'registrant', 'name', 'exDate');

	my $contacts = $infData->getElementsByLocalName('contact');
	while (my $contact = $contacts->shift) {
		my $type	= $contact->getAttribute('type');
		my $id		= $contact->textContent;

		if (ref($hash->{contacts}->{$type}) eq 'STRING') {
			$hash->{contacts}->{$type} = [ $hash->{contacts}->{$type}, $id ];

		} elsif (ref($hash->{contacts}->{$type}) eq 'ARRAY') {
			push(@{$hash->{contacts}->{$type}}, $id);

		} else {
			$hash->{contacts}->{$type} = $id;

		}

	}

	my $ns = $infData->getElementsByLocalName('ns');
	if ($ns->size == 1) {
		my $el = $ns->shift;
		my $hostObjs = $el->getElementsByLocalName('hostObj');
		while (my $hostObj = $hostObjs->shift) {
			push(@{$hash->{ns}}, $hostObj->textContent);
		}

		my $hostAttrs = $el->getElementsByLocalName('hostAttr');
		while (my $hostAttr = $hostAttrs->shift) {
			my $host = {};
			$host->{name} = $hostAttr->getElementsByLocalName('hostName')->shift->textContent;
			my $addrs = $hostAttr->getElementsByLocalName('hostAddr');
			while (my $addr = $addrs->shift) {
				push(@{$host->{addrs}}, { version => $addr->getAttribute('ip'), addr => $addr->textContent });
			}
			push(@{$hash->{ns}}, $host);
		}
	}

	my $hosts = $infData->getElementsByLocalName('host');
	while (my $host = $hosts->shift) {
		push(@{$hash->{hosts}}, $host->textContent);
	}

	my $auths = $infData->getElementsByLocalName('authInfo');
	if ($auths->size == 1) {
		my $authInfo = $auths->shift;
		my $pw = $authInfo->getElementsByLocalName('pw');
		$hash->{authInfo} = $pw->shift->textContent if ($pw->size == 1);
	}

	return $hash;
}


=pod

=head2 Host Information

The hash ref returned by C<host_info()> will usually look something like
this:

	$info = {
	  'crDate' => '2007-09-17T15:38:56.0Z',
	  'clID' => 'registrar-id',
	  'crID' => 'registrar-id',
	  'roid' => 'tld-12345',
	  'status' => [
	    'linked',
	    'serverDeleteProhibited',    
	  ],
	  'name' => 'ns0.example.tld',
	  'addrs' => [
	    {
	      'version' => 'v4',
	      'addr' => '10.0.0.1'
	    }
	  ]
	};

Note that hosts may have multiple addresses, and that C<version> is
optional.

=cut

sub _host_infData_to_hash {
	my ($self, $infData) = @_;

	my $hash = $self->_get_common_properties_from_infData($infData, 'name');

	my $addrs = $infData->getElementsByLocalName('addr');
	while (my $addr = $addrs->shift) {
		push(@{$hash->{addrs}}, { version => $addr->getAttribute('ip'), addr => $addr->textContent });
	}

	return $hash;
}

=pod

=head2 Contact Information

The hash ref returned by C<contact_info()> will usually look something
like this:

	$VAR1 = {
	  'id' => 'contact-id',
	  'postalInfo' => {
	    'int' => {
	      'name' => 'John Doe',
	      'org' => 'Example Inc.',
	      'addr' => {
	        'street' => [
	          '123 Example Dr.'
	          'Suite 100'
	        ],
	        'city' => 'Dulles',
	        'sp' => 'VA',
	        'pc' => '20166-6503'
	        'cc' => 'US',
	      }
	    }
	  },
	  'clID' => 'registrar-id',
	  'roid' => 'CNIC-HA321983',
	  'status' => [
	    'linked',
	    'serverDeleteProhibited'
	  ],
	  'voice' => '+1.7035555555x1234',
	  'fax' => '+1.7035555556',
	  'email' => 'jdoe@example.com',
	  'crDate' => '2007-09-23T03:51:29.0Z',
	  'upDate' => '1999-11-30T00:00:00.0Z'
	};

There may be up to two members of the C<postalInfo> hash, corresponding
to the C<int> and C<loc> internationalised and localised types.

=cut

sub _contact_infData_to_hash {
	my ($self, $infData) = @_;

	my $hash = $self->_get_common_properties_from_infData($infData, 'email', 'id');

	# remove this as it gets in the way:
	my $els = $infData->getElementsByLocalName('disclose');
	if ($els->size > 0) {
		while (my $el = $els->shift) {
			$el->parentNode->removeChild($el);
		}
	}

	foreach my $name ('voice', 'fax') {
		my $els = $infData->getElementsByLocalName($name);
		if (defined($els) && $els->size == 1) {
			my $el = $els->shift;
			if (defined($el)) {
				$hash->{$name} = $el->textContent;
				$hash->{$name} .= 'x'.$el->getAttribute('x') if (defined($el->getAttribute('x')) && $el->getAttribute('x') ne '');
			}
		}
	}

	my $postalInfo = $infData->getElementsByLocalName('postalInfo');
	while (my $info = $postalInfo->shift) {
		my $ref = {};

		foreach my $name (qw(name org)) {
			my $els = $info->getElementsByLocalName($name);
			$ref->{$name} = $els->shift->textContent if ($els->size == 1);
		}

		my $addrs = $info->getElementsByLocalName('addr');
		if ($addrs->size == 1) {
			my $addr = $addrs->shift;
			foreach my $child ($addr->childNodes) {
				if ($child->localName eq 'street') {
					push(@{$ref->{addr}->{$child->localName}}, $child->textContent);

				} else {
					$ref->{addr}->{$child->localName} = $child->textContent;

				}
			}
		}

		$hash->{postalInfo}->{$info->getAttribute('type')} = $ref;
	}

	my $auths = $infData->getElementsByLocalName('authInfo');
	if ($auths->size == 1) {
		my $authInfo = $auths->shift;
		my $pw = $authInfo->getElementsByLocalName('pw');
		$hash->{authInfo} = $pw->shift->textContent if ($pw->size == 1);
	}

	return $hash;
}

=pod

=head1 Object Transfers

The EPP C<E<lt>transferE<gt>> command suppots five different operations:
query, request, cancel, approve, and reject. C<Net::EPP::Simple> makes
these available using the following methods:

	# For domain objects:

	$epp->domain_transfer_query($domain);
	$epp->domain_transfer_cancel($domain);
	$epp->domain_transfer_request($domain, $authInfo, $period);
	$epp->domain_transfer_approve($domain);
	$epp->domain_transfer_reject($domain);

	# For contact objects:

	$epp->contact_transfer_query($contact);
	$epp->contact_transfer_cancel($contact);
	$epp->contact_transfer_request($contact, $authInfo);
	$epp->contact_transfer_approve($contact);
	$epp->contact_transfer_reject($contact);

Most of these methods will just set the value of C<$Net::EPP::Simple::Code>
and return either true or false. However, the C<domain_transfer_request()>,
C<domain_transfer_query()>, C<contact_transfer_request()> and C<contact_transfer_query()>
methods will return a hash ref that looks like this:

	my $trnData = {
	  'name' => 'example.tld',
	  'reID' => 'losing-registrar',
	  'acDate' => '2007-12-04T12:24:53.0Z',
	  'acID' => 'gaining-registrar',
	  'reDate' => '2007-11-29T12:24:53.0Z',
	  'trStatus' => 'pending'
	};

=cut

sub _transfer_request {
	my ($self, $op, $type, $identifier, $authInfo, $period) = @_;

	my $class = sprintf('Net::EPP::Frame::Command::Transfer::%s', ucfirst(lc($type)));

	my $frame;
	eval("\$frame = $class->new");
	if ($@ || ref($frame) ne $class) {
		$Error = "Error building request frame: $@";
		$Code = COMMAND_FAILED;
		return undef;

	} else {
		$frame->setOp($op);
		if ($type eq 'domain') {
			$frame->setDomain($identifier);

		} elsif ($type eq 'contact') {
			$frame->setContact($identifier);

		}

		if ($op eq 'request' || $op eq 'query') {
			$frame->setAuthInfo($authInfo) if ($authInfo ne '');
		}

		$frame->setPeriod(int($period)) if ($op eq 'request');
	}

	my $response = $self->_request($frame);


	if (!$response) {
		return undef;

	} else {
		$Code = $self->_get_response_code($response);
		$Message = $self->_get_message($response);

		if ($Code > 1999) {
			$Error = $response->msg;
			return undef;

		} elsif ($op eq 'query' || $op eq 'request') {
			my $trnData = $response->getElementsByLocalName('trnData')->shift;
			my $hash = {};
			foreach my $child ($trnData->childNodes) {
				$hash->{$child->localName} = $child->textContent;
			}

			return $hash;

		} else {
			return 1;

		}
	}
}

sub domain_transfer_query {
	return $_[0]->_transfer_request('query', 'domain', $_[1]);
}

sub domain_transfer_cancel {
	return $_[0]->_transfer_request('cancel', 'domain', $_[1]);
}

sub domain_transfer_request {
	return $_[0]->_transfer_request('request', 'domain', $_[1], $_[2], $_[3]);
}

sub domain_transfer_approve {
	return $_[0]->_transfer_request('approve', 'domain', $_[1]);
}

sub domain_transfer_reject {
	return $_[0]->_transfer_request('reject', 'domain', $_[1]);
}

sub contact_transfer_query {
	return $_[0]->_transfer_request('query', 'contact', $_[1]);
}

sub contact_transfer_cancel {
	return $_[0]->_transfer_request('cancel', 'contact', $_[1]);
}

sub contact_transfer_request {
	return $_[0]->_transfer_request('request', 'contact', $_[1], $_[2]);
}

sub contact_transfer_approve {
	return $_[0]->_transfer_request('approve', 'contact', $_[1]);
}

sub contact_transfer_reject {
	return $_[0]->_transfer_request('reject', 'contact', $_[1]);
}

=pod

=head1 Creating Objects

The following methods can be used to create a new object at the server:

	$epp->create_domain($domain);
	$epp->create_host($host);
	$epp->create_contact($contact);

The argument for these methods is a hash ref of the same format as that
returned by the info methods above. As a result, cloning an existing
object is as simple as the following:

	my $info = $epp->contact_info($contact);

	# set a new contact ID to avoid clashing with the existing object
	$info->{id} = $new_contact;

	# randomize authInfo:
	$info->{authInfo} = $random_string;

	$epp->create_contact($info);

C<Net::EPP::Simple> will ignore object properties that it does not recognise,
and those properties (such as server-managed status codes) that clients are
not permitted to set.

=head2 Creating New Domains

When creating a new domain object, you may also specify a C<period> key, like so:

	my $domain = {
	  'name' => 'example.tld',
	  'period' => 2,
	  'registrant' => 'contact-id',
	  'contacts' => {
	    'tech' => 'contact-id',
	    'admin' => 'contact-id',
	    'billing' => 'contact-id',
	  },
	  'status' => {
	    'clientTransferProhibited',
	  }
	  'ns' => {
	    'ns0.example.com',
	    'ns1.example.com',
	  },
	};

	$epp->create_domain($domain);

The C<period> key is assumed to be in years rather than months. C<Net::EPP::Simple>
assumes the registry uses the host object model rather than the host attribute model.

=cut

sub create_domain {
	my ($self, $domain) = @_;

	print Data::Dumper::Dumper($domain);

	my $frame = Net::EPP::Frame::Command::Create::Domain->new;
	$frame->setDomain($domain->{'name'});
	$frame->setPeriod($domain->{'period'});
	$frame->setRegistrant($domain->{'registrant'});
	$frame->setContacts($domain->{'contacts'});
	$frame->setNS(@{$domain->{'ns'}});

	$frame->setAuthInfo($domain->{authInfo}) if ($domain->{authInfo} ne '');

	my $response = $self->_request($frame);


	if (!$response) {
		return undef;

	} else {
		$Code = $self->_get_response_code($response);
		$Message = $self->_get_message($response);

		if ($Code > 1999) {
			$Error = $response->msg;
			return undef;

		} else {
			return 1;

		}
	}
}

sub create_host {
	my ($self, $host) = @_;
	croak("Unfinished method create_host()");
}

sub create_contact {
	my ($self, $contact) = @_;
	my $frame = Net::EPP::Frame::Command::Create::Contact->new;

	$frame->setContact($contact->{id});
	$frame->setEmail($contact->{email});
	$frame->setVoice($contact->{voice}) if ($contact->{voice} ne '');
	$frame->setFax($contact->{fax}) if ($contact->{fax} ne '');
	$frame->setAuthInfo($contact->{authInfo}) if ($contact->{authInfo} ne '');

	if (ref($contact->{postalInfo}) eq 'HASH') {
		foreach my $type (keys(%{$contact->{postalInfo}})) {
			$frame->addPostalInfo(
				$type,
				$contact->{postalInfo}->{$type}->{name},
				$contact->{postalInfo}->{$type}->{org},
				$contact->{postalInfo}->{$type}->{addr}
			);
		}
	}

	if (ref($contact->{status}) eq 'ARRAY') {
		foreach my $status (grep { /^client/ } @{$contact->{status}}) {
			$frame->appendStatus($status);
		}
	}

	my $response = $self->_request($frame);

	if (!$response) {
		return undef;

	} else {
		$Code = $self->_get_response_code($response);
		$Message = $self->_get_message($response);

		if ($Code > 1999) {
			$Error = $response->msg;
			return undef;

		} else {
			return 1;

		}
	}
}

sub update_domain {
	my ($self, $domain) = @_;
	croak("Unfinished method update_domain()");
}

sub update_host {
	my ($self, $domain) = @_;
	croak("Unfinished method update_host()");
}

sub update_contact {
	my ($self, $domain) = @_;
	croak("Unfinished method update_contact()");
}

=pod

=head1 Deleting Objects

The following methods can be used to delete an object at the server:

	$epp->delete_domain($domain);
	$epp->delete_host($host);
	$epp->delete_contact($contact);

Each of these methods has the same profile. They will return one of the following:

=over

=item * undef in the case of an error (check C<$Net::EPP::Simple::Error> and C<$Net::EPP::Simple::Code>).

=item * 1 if the deletion request was accepted.

=back

You may wish to check the value of $Net::EPP::Simple::Code to determine whether the response code was 1000 (OK) or 1001 (action pending).

=cut

sub delete_domain {
	my ($self, $domain) = @_;
	return $self->_delete('domain', $domain);
}

sub delete_host {
	my ($self, $host) = @_;
	return $self->_delete('host', $host);
}

sub delete_contact {
	my ($self, $contact) = @_;
	return $self->_delete('contact', $contact);
}

sub _delete {
	my ($self, $type, $identifier) = @_;
	my $frame;
	if ($type eq 'domain') {
		$frame = Net::EPP::Frame::Command::Delete::Domain->new;
		$frame->setDomain($identifier);

	} elsif ($type eq 'contact') {
		$frame = Net::EPP::Frame::Command::Delete::Contact->new;
		$frame->setContact($identifier);

	} elsif ($type eq 'host') {
		$frame = Net::EPP::Frame::Command::Delete::Host->new;
		$frame->setHost($identifier);

	} else {
		$Error = "Unknown object type '$type'";
		return undef;

	}

	my $response = $self->_request($frame);


	if (!$response) {
		return undef;

	} else {
		$Code = $self->_get_response_code($response);
		$Message = $self->_get_message($response);

		if ($Code > 1999) {
			$Error = sprintf("Server returned a %d code", $Code);
			return undef;

		} else {
			return 1;

		}
	}
}

=pod

=head1 Miscellaneous Methods

=cut

sub error { $Error }

sub code { $Code }

sub message { $Message }

=pod

	my $greeting = $epp->greeting;

Returns the a C<Net::EPP::Frame::Greeting> object representing the greeting returned by the server.

=cut

sub greeting { $_[0]->{greeting} }

sub ping {
	my $self = shift;
	my $hello = Net::EPP::Frame::Hello->new;
	my $response = $self->request($hello);

	return (isa($response, 'XML::LibXML::Document') ? 1 : undef);
}

sub _request {
	my ($self, $frame) = @_;

	if ($self->{reconnect} > 0) {
		if (!$self->ping) {
			$self->debug('connection seems dead, trying to reconnect');
			for (1..$self->{reconnect}) {
				$self->debug("attempt #$_");
				if ($self->_connect) {
					$self->debug("attempt #$_ succeeded");
					return $self->request($frame);

				} else {
					$self->debug("attempt #$_ failed, sleeping");
					sleep($self->{timeout});

				}
			}
			$self->debug('unable to reconnect!');
			return undef;

		} else {
			return $self->request($frame);

		}

	} else {
		return $self->request($frame);

	}
}

=pod

=head1 Overridden Methods From C<Net::EPP::Client>

C<Net::EPP::Simple> overrides some methods inherited from
C<Net::EPP::Client>. These are described below:

=head2 The C<request()> Method

C<Net::EPP::Simple> overrides this method so it can automatically populate
the C<E<lt>clTRIDE<gt>> element with a unique string. It then passes the
frame back up to C<Net::EPP::Client>.

=cut

sub request {
	my ($self, $frame) = @_;
	# Make sure we start with blank variables
	$Code		= undef;
	$Error		= '';
	$Message	= '';

	$frame->clTRID->appendText(sha1_hex(ref($self).time().$$)) if (isa($frame, 'Net::EPP::Frame::Command'));

	$self->debug(sprintf('sending a %s to the server', ref($frame)));
	if (isa($frame, 'XML::LibXML::Document')) {
		map { $self->debug('C: '.$_) } split(/\n/, $frame->toString(1));

	} else {
		map { $self->debug('C: '.$_) } split(/\n/, $frame);

	}

	my $response = $self->SUPER::request($frame);

	map { $self->debug('S: '.$_) } split(/\n/, $response->toString(1)) if (isa($response, 'XML::LibXML::Document'));

	return $response;
}

=pod

=head2 The C<get_frame()> Method

C<Net::EPP::Simple> overrides this method so it can catch timeouts and
network errors. If such an error occurs it will return C<undef>.

=cut

sub get_frame {
	my $self = shift;
	my $frame;
	$self->debug(sprintf('reading frame, waiting %d seconds before timeout', $self->{timeout}));
	eval {
		local $SIG{ALRM} = sub { die "alarm\n" };
		$self->debug('setting timeout alarm for receiving frame');
		alarm($self->{timeout});
		$frame = $self->SUPER::get_frame();
		$self->debug('unsetting timeout alarm after successful receive');
		alarm(0);
	};
	if ($@ ne '') {
		$self->debug('unsetting timeout alarm after alarm was triggered');
		alarm(0);
		$Code = COMMAND_FAILED;
		$Error = $Message = "get_frame() timed out\n";
		return undef;

	} else {
		return bless($frame, 'Net::EPP::Frame::Response');

	}
}

sub _get_response_code {
	my ($self, $doc) = @_;
	my $els = $doc->getElementsByTagNameNS(EPP_XMLNS, 'result');
	if (defined($els)) {
		my $el = $els->shift;
		if (defined($el)) {
			return $el->getAttribute('code');
		}
	}
	return 2400;
}

sub _get_message {
	my ($self, $doc) = @_;
	my $msgs = $doc->getElementsByTagNameNS(EPP_XMLNS, 'msg');
	if (defined($msgs)) {
		my $msg = $msgs->shift;
		if (defined($msg)) {
			return $msg->textContent;
		}
	}
	return '';
}

sub logout {
	my $self = shift;
	if (defined($self->{authenticated}) && 1 == $self->{authenticated}) {
		$self->debug('logging out');
		my $response = $self->request(Net::EPP::Frame::Command::Logout->new);
		return undef if (!$response);
	}
	$self->debug('disconnecting from server');
	$self->disconnect;
	$self->{connected} = 0;
	return 1;
}

sub DESTROY {
	my $self = shift;
	$self->debug('DESTROY() method called');
	$self->logout if (defined($self->{connected}) && 1 == $self->{connected});
}

sub debug {
	my ($self, $msg) = @_;
	printf(STDERR "%s (%d): %s\n", scalar(localtime()), $$, $msg) if (defined($self->{debug}) && $self->{debug} == 1);
}

=pod

=head1 Package Variables

=head2 $Net::EPP::Simple::Error

This variable contains an english text message explaining the last error
to occur. This is may be due to invalid parameters being passed to a
method, a network error, or an error response being returned by the
server.

=head2 $Net::EPP::Simple::Message

This variable contains the contains the text content of the
C<E<lt>msgE<gt>> element in the response frame for the last transaction.

=head2 $Net::EPP::Simple::Code

This variable contains the integer result code returned by the server
for the last transaction. A successful transaction will always return an
error code of 1999 or lower, for an unsuccessful transaction it will be
2000 or more. If there is an internal client error (due to invalid
parameters being passed to a method, or a network error) then this will
be set to 2400 (C<COMMAND_FAILED>). See L<Net::EPP::ResponseCodes> for
more information about thes codes.

=head1 AUTHOR

CentralNic Ltd (L<http://www.centralnic.com/>).

=head1 COPYRIGHT

This module is (c) 2007 CentralNic Ltd. This module is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

=over

=item * L<Net::EPP::Client>

=item * L<Net::EPP::Frame>

=item * L<Net::EPP::Proxy>

=item * RFCs 4930 and RFC 4934, available from L<http://www.ietf.org/>.

=item * The CentralNic EPP site at L<http://www.centralnic.com/resellers/epp>.

=back

=cut

1;
