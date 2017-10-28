use strict;
use warnings;
use lib './lib/perl5';

use Plack::Builder;
use Plack::App::File;
use Plack::App::Proxy;

use Plack::Response;
use Plack::Middleware::Cache::CHI;
use Plack::Mojo::Mount;
    
use Mojo::Server::PSGI;

builder {

    enable "Static", path => qr{^/static/}, root => './';
    mount '/' => sub {
    	my $env = shift;
    	my $cookie = $env->{HTTP_COOKIE};
    	my $res = Plack::Response->new;
    	$res->redirect('/u/v1/login',  302);
    	return $res->finalize;
    };
    
    mount_mojo './meetup.pl' => "/m/v1", [qw/uno due tre/];
    mount_mojo './auth.pl'   => "/u/v1", [qw/uno due tre/];
    mount_mojo './ews.pl'    => "/e/v1", [qw/uno due tre/];
    mount_mojo './maps.pl'   => "/g/v1", [qw/uno due tre/];
};

