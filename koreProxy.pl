#############################################################################
# koreProxy plugin by Revok/marcelothebuilder (https://github.com/marcelothebuilder)
# Supports HTTP and SOCKS4/5 Proxys
#
# This source code is licensed under the
# GNU General Public License, Version 3.
# See http://www.gnu.org/licenses/gpl.html
#############################################################################
package koreProxy;

use strict;
use Plugins;
use lib $Plugins::current_plugin_folder;
use Utils;
use Log qw( warning message error );
use Misc;
use Globals;
use IO::Socket::INET;
use MIME::Base64;
use IO::Socket::Socks;

Plugins::register("koreProxy", "proxy openkore connection through socks or http proxies", \&core_Reload);

my $myHooks = Plugins::addHooks(
	['Network::connectTo',	\&connection]
);

sub core_Reload {
	Plugins::delHooks($myHooks);
	undef $myHooks;
}

my %proxy;
sub connection {
	my ($self, $args) = @_;

	if ($config{koreProxy_protocol} =~ /http/i || !$config{koreProxy_protocol}) {
		message sprintf("Connecting to (%s:%s) via proxy (%s:%s HTTP)... \n", $args->{host}, $args->{port}, $config{'koreProxy_ip'}, $config{'koreProxy_port'}), "connection";
		${$args->{socket}} = IO::Socket::INET->new(
				PeerAddr => $config{koreProxy_ip},
				PeerPort => $config{koreProxy_port},
				Proto => 'tcp',
				Timeout => $config{koreProxy_timeout} || 20
			);
		if (${$args->{socket}} && inet_aton(${$args->{socket}}->peerhost()) eq inet_aton($config{koreProxy_ip})) {
			message ("connected to proxy server !\n"), "connection";
		} else {
			error("couldn't connect via proxy: proxy offline?\n", "connection");
			${$args->{return}} = 1;
			return ;
		}

		my $request;
		my ($host, $port) = ($args->{host}, $args->{port});

		$request = "CONNECT $host:$port HTTP/1.1\r\n";
		$request .= "Host: $host:$port\r\n";

		if ($config{koreProxy_user} ne '' && $config{koreProxy_password} ne '') {
			my $encoded = encode_base64("$config{koreProxy_user}:$config{koreProxy_password}");

			chomp($encoded);

			$request .= "Authorization: Basic $encoded\r\n";
			$request .= "Proxy-Authorization: Basic $encoded\r\n";
		}

		$request .= "User-Agent: Ragnarok\r\n\r\n";

		${$args->{socket}}->send($request);
		my $temp_data;
		${$args->{socket}}->recv($temp_data, 1024 * 32);

		if ($temp_data !~ /\s200\s/) {
			my ($errorMsg) = $temp_data =~ /(.*)\r\n/;
			my ($code, $error) = $errorMsg =~ /.* (\d+) (.*)/;
			error(sprintf("couldn't connect via proxy: %s (error code %d)\n", $error, int($code)), "connection");
			${$args->{return}} = 1;
			return ;
		}
	} else {
		message sprintf("Connecting to (%s:%s) via proxy (%s:%s SOCKS%s)... \n", $args->{host}, $args->{port}, $config{'koreProxy_ip'}, $config{'koreProxy_port'}, $config{koreProxy_password}?5:4), "connection";
		# SOCKS 4, 4a, 5
		${$args->{socket}} = new IO::Socket::Socks (
			BindAddr	=> $config{bindIp} || undef,
			ConnectAddr	=> $args->{host},
			ConnectPort	=> $args->{port},
			Timeout		=> 4,
			#Timeout		=> $config{koreProxy_timeout} || 20,
			ProxyAddr=> $config{koreProxy_ip},
			ProxyPort=> $config{koreProxy_port},
			SocksVersion => $config{koreProxy_password} ? 5 : 4,
			AuthType => $config{koreProxy_user}?'userpass':'none', # none / userpass (socks5 only)
			Username => $config{koreProxy_user},
			Password => $config{koreProxy_password},
			RequireAuth => 0,
			SocksDebug => 0,
		);

		if (${$args->{socket}}) {
			message ("connected via proxy !\n"), "connection";
		} else {
			error(sprintf("couldn't connect via proxy: %s (error code %d)\n", $SOCKS_ERROR, int($SOCKS_ERROR)), "connection");
		}
	}

	if ($net->getState() != Network::NOT_CONNECTED) {
		$incomingMessages->nextMessageMightBeAccountID();
	}

	${$args->{return}} = 1; # override default kore connection
}

1;
# i luv u mom
