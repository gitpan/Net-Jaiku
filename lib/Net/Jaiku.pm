package Net::Jaiku;

$VERSION ="0.0100";
use warnings;
use strict;

use LWP::UserAgent;
use JSON::Any;

sub new {
    my $class = shift;
    my %conf = @_;

    $conf{ua} = LWP::UserAgent->new();
    $conf{ua}->env_proxy();

	$conf{username} ||= '';
	$conf{userkey}  ||= '';

    return bless {%conf}, $class;
}


sub username {
	my $self = shift;
	my $username = shift;
	if ($username){
		$self->{username} = $username;
	}
	return $self->{username};
}

sub userkey {
	my $self = shift;
	my $userkey = shift;
	if ($userkey){
		$self->{userkey} = $userkey;
	}
	return $self->{userkey};
}

sub auth {
	my $self = shift;
	if ($self->username() && $self->userkey()){
		return {
			user => $self->username,
			personal_key => $self->userkey,
		}
	}
	return {};
}


sub getMyFeed {
	my $self = shift;
	return $self->getFeed( user => $self->username );
}
sub getUserFeed {
	my $self = shift;
	my %arg = @_;
	return $self->getFeed( user => $arg{user} || $self->username );
}
sub getFeed {
	my $self = shift;
	my %arg = @_;

	return undef if $arg{user} && ! $self->auth;

    my $req = $self->{ua}->get(
		'http://'.(($arg{user}) ? "$arg{user}." : '').'jaiku.com/feed/json',
		$self->auth,
	);
    return ($req->is_success) ?  HashInflator->new( JSON::Any->jsonToObj($req->content) ) : undef;
}

sub getMyPresence {
	my $self = shift;
	return $self->getUserPresence( user => $self->username );
}
sub getUserPresence {
	my $self = shift;
	my %arg = @_;

	$arg{user} ||= $self->username;

    my $req = $self->{ua}->get(
		'http://'.$arg{user}.'.jaiku.com/presence/json',
		$self->auth,
	);
    return ($req->is_success) ?  HashInflator->new( JSON::Any->jsonToObj($req->content) ) : undef;
}

sub getMyInfo {
	my $self = shift;
	return $self->getUserInfo( user => $self->username );
}
sub getUserInfo {
	my $self = shift;
	my %arg = @_;

	$arg{user} ||= $self->username;

    my $req = $self->{ua}->get(
		'http://'.$arg{user}.'.jaiku.com/json',
		$self->auth,
	);
	if ($req->is_success){
		my $content = $req->content;
		$content =~ s/^.*?(\{.+\}).*?$/$1/s;
		return HashInflator->new( JSON::Any->jsonToObj($content) );
	}
	return undef;
}

sub setPresence {
	my $self = shift;
	my %arg = @_;
    my $req = $self->{ua}->post(
		'http://api.jaiku.com/json',
		{
			user => $self->username,
			personal_key => $self->userkey,
			method => 'presence.send',
			%arg
		}
	);
    if ($req->is_success) {
    	my $rv = JSON::Any->jsonToObj($req->content);
    	return lc($rv->{status}) eq 'ok'
    }
    return undef;
}

package HashInflator;

use Data::Dumper;

sub new {
	my $class = shift;
	my %hash = (@_ > 1) ? @_ : %{$_[0]};

	foreach my $key (keys %hash){
		if (ref $hash{$key} eq 'HASH'){
			$hash{$key} = new HashInflator($hash{$key});
		}
		elsif(ref $hash{$key} eq 'ARRAY'){
			foreach( @{$hash{$key}} ) {
				$_ = new HashInflator($_);
			}
		}
	}

	return bless \%hash, $class;
}

sub AUTOLOAD {
	my $self = shift;
	our $AUTOLOAD;
	$AUTOLOAD =~ s/.+:://;
	return if $AUTOLOAD =~ /^[A-Z]+$/;
	return $self->{$AUTOLOAD};
}

1;

__END__

=head1 NAME

Net::Jaiku - A perl interface to jaiku.com's API

=head1 SYNOPSIS

	use Net::Jaiku;

	my $jaiku = new Net::Jaiku(
		username => 'Example',
		userkey  => 'API Key'
	);

	my $p = $jaiku->getMyPresence;
	print $p->user->url;

	my $rv = $jaiku->setPresence('Reading a book');

=head1 ABSTRACT

This module allows easy access to Feeds, Presences and Users at
jaiku.com. It requires an API key retreivable from http://api.jaiku.com/
for each username you wish to authenticate.

=head1 CONSTRUCTOR

This module has a single constructor:

=over 4

=item * C<new( ... )>

The C<new> constructor takes the following attributes:

=over 4

=item * C<<username => $string>>

This is a jaiku.com username. I<this bit>.jaiku.com

=item * C<<userkey => $string>>

The user's key can be obtained by visiting http://api.jaiku.com when
logged in as the user.

=back

=back

=head1 METHODS

L<Net::Jaiku> has the following methods:

=head2 Feeds

=over 4

=item * C<getFeed()>

Returns the public feed as seen on the front page.

=item * C<getUserFeed( user => $string )>

Returns a hashref of the feed for the given user. If no user is
specified, it will return the feed for the current user. If no
user is logged it, it will return undef.

=item * C<getMyFeed()>

A shortcut to the above method for the logged in user. If no
user is logged it, it will return undef.

=item * B<RETURN VALUE>

Feed methods return an object representing the feed. The following
keys are available:

=over 4

=item * title

=item * url

=item * stream[n]->icon

=item * stream[n]->content

=item * stream[n]->created_at

=item * stream[n]->created_at_relative

=item * stream[n]->comments

=item * stream[n]->url

=item * stream[n]->id

=item * stream[n]->title

=back

=back


=head2 Presences

=over 4

=item * C<getUserPresence( user => $string )>

Returns the 'presence' for the given user. If no user is
specified, it will return the feed for the current user. If no
user is logged it, it will return undef.

=item * C<getMyPresence()>

A shortcut to the above method for the logged in user. If no
user is logged it, it will return undef.

=item * B<RETURN VALUE>

Presence methods return an object representing the presence. The
following keys are available:

=over 4

=item * line

=item * user->avatar

=item * user->url

=item * user->nick

=item * user->first_name

=item * user->last_name

=back

=back


=head2 User Info

=over 4

=item * C<getUserInfo( user => $string )>

Returns information for the given user. If no user is
specified, it will return the feed for the current user. If no
user is logged it, it will return undef.

=item * C<getMyInfo()>

A shortcut to the above method for the logged in user. If no
user is logged it, it will return undef.

=item * B<RETURN VALUE>

Info methods return an object representing the information. The
following keys are available:

=over 4

=item * avatar

=item * url

=item * nick

=item * first_name

=item * last_name

=item * contacts[n]->avatar

=item * contacts[n]->url

=item * contacts[n]->nick

=item * contacts[n]->first_name

=item * contacts[n]->last_name

=back

=back


=head1 SETTERS AND GETTERS

=over 4

=item * C<username( $optional_new_username )>

Returns the current username (after optionally setting)

=item * C<userkey( $optional_new_userkey )>

Returns the current username (after optionally setting)

=back

=head1 NOTES

=head2 Objects

This module returns a custom object called 'HashInflator'. This is used
so you can do $rv->user->id rather than the more cumbersome $rv->{user}->{id}

Once the API settles down, I will investigate creating proper objects that
will auto-inflate when they need to.

=head1 AUTHOR

Rick Measham <rickm@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2007 Rick Measham.  All rights reserved.  This program
is free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

The full text of the license can be found in the LICENSE file included
with this module.

=head1 SEE ALSO

irc://freenode.net/##jaiku

=cut



