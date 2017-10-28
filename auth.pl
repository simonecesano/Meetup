#!/usr/bin/env perl
use Mojolicious::Lite;
use lib './lib';

use Mojo::UserAgent::LWP::NTLM;

plugin 'Config';
plugin 'Localizer';

get '/' => sub { shift->redirect_to('login') };

get '/login' => sub { shift->render(template => 'login/form') };

get '/user' => sub { shift->render(template => 'login/welcome') };

post '/login' => sub {
    my $c = shift;

    if ($c->param('user') && $c->param('password')) {
	my $ua  = Mojo::UserAgent::LWP::NTLM->new();

	$ua->user($c->param('user')); $ua->password( $c->param('password'));

	$c->stash('name', $c->param('user'));
	my $xml = $c->render_to_string(template => 'whois', format   => 'xml');

	my $ews = app->config->{ews} || $c->param('ews_url');
	my $tx = $ua->post($ews => {'Content-Type' => 'text/xml' } => $xml);

	app->log->info($tx->res->code . ' ' . eval { $tx->res->dom->at('ResolveNamesResponseMessage')->attr('ResponseClass') });
	if (($tx->res->code == 200) && (eval { $tx->res->dom->at('ResolveNamesResponseMessage')->attr('ResponseClass') } eq 'Success')) {
	    my $dom = $tx->res->dom;

	    $c->session('given_name', $dom->at('GivenName')->all_text);
	    $c->session('email',      $dom->at('EmailAddress')->all_text);
	    $c->session('user',     $c->param('user'));
	    $c->session('password', $c->param('password'));

	    $c->session('ews', $ews);
	    app->log->info("Redirect to " . (app->config->{home} ? $c->req->url->to_abs->path(app->config->{home}) : 'user'));
	    app->log->info("Scheme is " . $c->req->url->to_abs->scheme);
	    $c->redirect_to(app->config->{home} ? $c->req->url->to_abs->path(app->config->{home})->scheme($c->req->url->to_abs->scheme) : 'user');
	} else {
	    $c->render(template => 'login/error');
	}
    } else {
	$c->render(template => 'login/form');
    }
};


app->start;
__DATA__

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title><%= title %></title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <script src="https://code.jquery.com/jquery-3.1.1.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/tether/1.4.0/js/tether.min.js"></script>
    
    <link rel="stylesheet" type="text/css" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css" media="screen" />
    <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js"></script>
  </head>
    <body><%= content %></body>
</html>
@@ login/form.html.ep
% layout 'default';
% title 'Login';
<style>
</style>
<div class="container-fluid">
  <div class="row">
    <div class="col-md-4 col-md-offset-4 col-sm-12 col-sm-offset-0">
      <form class="form-signin" method="POST">
	<h2 class="form-signin-heading">Welcome! please sign in</h2>
	<label for="user" class="sr-only">Email address</label>
	<input type="text" id="user" name="user" class="form-control" placeholder="User name" required autofocus>
	<label for="password" class="sr-only">Password</label>
	<input type="password" id="password" name="password" class="form-control" placeholder="Password" required>
	% unless (config->{ews}) {
	<label for="ews_url" class="sr-only">EWS Server</label>
	<input type="text" id="ews_url" name="ews_url" class="form-control" placeholder="EWS Server" required>
	% }
	<button class="btn btn-lg btn-primary btn-block" type="submit">Sign in</button>
      </form>
    </div>
  </div>
</div> <!-- /container -->

@@ whois.xml.ep
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	       xmlns:xsd="http://www.w3.org/2001/XMLSchema"
	       xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types">
  <soap:Header>
    <t:RequestServerVersion Version="Exchange2013_SP1" />
  </soap:Header>
  <soap:Body>
    <ResolveNames xmlns="http://schemas.microsoft.com/exchange/services/2006/messages"
                  xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types"
		  SearchScope="ActiveDirectory"
                  ReturnFullContactData="true">
      <UnresolvedEntry><%= $name %></UnresolvedEntry>
    </ResolveNames>
  </soap:Body>
</soap:Envelope>
    
@@ login/welcome.html.ep
% layout 'default';
% title 'Welcome';
<div class="container">
Welcome <%= session 'given_name' %>
</div> <!-- /container -->

@@ login/error.html.ep
% layout 'default';
% title 'Login failed';
<div class="container">
Sorry, the login failed!</p>
try again <a href="">here</a>
</div> <!-- /container -->

@@ login/howto.html.ep

This is a simple Mojo lite app for logging into an EWS based system.

It provides a basic login form, an error page, and a landing page.

It checks for a configuration file which can contain:

- ews: the EWS url
- home: the page which a successful login redirects to

And that's it
