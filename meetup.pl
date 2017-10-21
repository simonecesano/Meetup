#!/usr/bin/env perl
use Mojolicious::Lite;
use Data::Dump qw/dump/;
use MIME::Base64 qw/encode_base64url decode_base64url/;
use List::MoreUtils qw/uniq/;
use lib 'lib/perl5';
use Mojo::JSON qw(decode_json encode_json);
use DBI;

hook (before_dispatch => sub {
	  my $c = shift;
	  $c->session('user',     $ENV{EWS_USER})     unless $c->session('user');
	  $c->session('password', $ENV{EWS_PASSWORD}) unless $c->session('password');
	  app->log->info(defined $c->session('user'), defined $c->session('session')); 
	  $c;
      });

plugin 'Persist' => { dbh => DBI->connect('dbi:SQLite:dbname=./jobs.db'), id => 'user' };

get '/' => sub {
    my $c = shift;
    $c->render(template => 'index');
};



get '/people' => sub {
    my $c = shift;

    my $people = $c->persist('people');

    $c->stash('people', $people);
    app->log->info(dump $c->persist('people'));

    $c->persist('people', $people);
    $c->render(template => 'people');
};

any '/people/#email/add' => sub {
    my $c = shift;

    my $people = $c->persist('people');

    push @$people, $c->param('email');

    $people = [ uniq @$people ];

    $c->persist('people', $people);

    app->log->info(dump $c->persist('people'));

    $people = $c->persist('people');

    $c->stash('people', $people);
    $c->render(template => 'people');
};

any '/people/#email/delete' => sub {
    my $c = shift;
    app->log->info(dump $c->persist('people'));
    my $people = $c->persist('people');

    unless (grep { $_ eq $c->param('email') } @$people) {
	$c->render(json => {message => 'not found' });
    } else {
	$people = [ grep { $_ ne $c->param('email') } @$people ];
	app->log->info(dump $people);
	$c->persist('people', $people);
	$c->render(json => {message => 'done' });
    }
};

get '/search';

get '/meet/#email' => sub {
    my $c = shift;
    $c->render(template => 'meet');
};

get '/me/schedule' => sub {
    my $c = shift;
    app->log->info($c->session('email'));
    $c->stash('email', $c->session('email'));
    $c->render(template => 'meet');
};

get '/me/week' => sub {
    my $c = shift;
    app->log->info($c->session('email'));
    $c->stash('email', $c->session('email'));
    $c->render(template => 'week');
};

use DateTime::Format::Strptime;

get '/setup/#email/#start/#end' => sub {
    my $c = shift;

    my $strp = DateTime::Format::Strptime->new(pattern => '%FT%T');
    my ($start, $end) = map { my $t = $strp->parse_datetime($c->param($_)); $t->set_time_zone('UTC'); $t } qw/start end/;

    for ($start, $end) { $_->set_time_zone('Europe/Berlin') };

    my @hours = (($start->hour)..($end->hour - ($end->minute ? 0 : 1)));
    $c->stash('hours', \@hours);
    $c->stash('duration', $end->subtract_datetime($start)->in_units('minutes'));
    
    app->log->info($start);
    app->log->info($end);
    app->log->info($c->stash('duration'));
    app->log->info($c->stash('hours'));
    $c->render(template => 'setup');
};

get '/book/#email/#start/#end' => sub {
    my $c = shift;

    my $strp = DateTime::Format::Strptime->new(pattern => '%FT%T');
    my ($start, $end) = map { my $t = $strp->parse_datetime($c->param($_)); $t->set_time_zone('UTC'); $t } qw/start end/;

    for ($start, $end) { $_->set_time_zone('Europe/Berlin') };

    my @hours = (($start->hour)..($end->hour - ($end->minute ? 0 : 1)));

    $c->stash('hours', \@hours);
    $c->stash('duration', $end->subtract_datetime($start)->in_units('minutes'));

    $c->render(template => 'book');
};

get '/prefs/me' => sub {
    my $c = shift;
    $c->render(template => 'prefs');
};

app->start;

__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome';
%= include 'navbars/mail'
<div class="container-fluid">
  <div class="row">
    <div class="col-md-10 col-md-offset-1">
      <h1>Welcome to the Mojolicious real-time web framework!</h1>
      To learn more, you can browse through the documentation
      <%= link_to 'here' => '/perldoc' %>.
    </div>
  </div>
</div>
@@ layouts/default.html.ep
<!DOCTYPE html>
<html lang="en">
  <head>
    <title><%= title %></title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="stylesheet" type="text/css" href="https://cdnjs.cloudflare.com/ajax/libs/normalize/7.0.0/normalize.css" media="screen" />
    <script src="https://code.jquery.com/jquery-2.2.4.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/tether/1.4.0/js/tether.min.js"></script>
    <link rel="stylesheet" type="text/css" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css" media="screen" />
    <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/underscore.js/1.8.3/underscore-min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/handlebars.js/4.0.10/handlebars.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/moment.js/2.18.1/moment.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/moment-timezone/0.5.13/moment-timezone-with-data.min.js"></script>
    <link href="https://fonts.googleapis.com/css?family=Lato" rel="stylesheet"> 
    <style>body { margin-top: 70px; font-family: 'Lato', sans-serif; }</style>
  </head>
  <body>
    <%= content %>
  </body>
</html>
@@ navbars/mail.html.ep
<div class="col-md-10 col-md-offset-1">
  <nav class="navbar navbar-inverse navbar-fixed-top">
    <div class="container-fluid">
      <div class="navbar-header">
	<div class="navbar-text" style="display:inline-block;font-weight:bold;font-size:14pt;color:white"><%= $title %></div>
	<button class="collapsed navbar-toggle" data-target="#bs-example-navbar-collapse-2" data-toggle="collapse" type="button">
          <span class="icon-bar"></span>
          <span class="icon-bar"></span>
          <span class="icon-bar"></span>
	</button>
	<a class="navbar-brand" href="/"><i class="fa fa-crop fa-lg" aria-hidden="true"></i></a>
      </div>
      <div class="collapse navbar-collapse" id="bs-example-navbar-collapse-2">
	<ul class="nav navbar-nav">
	  <li ><a href="<%= url_for('/people') %>" >Home</a></li>
	  <li ><a href="<%= url_for('/search') %>" >Search people</a></li>
	  <li ><a href="<%= url_for('/me/schedule') %>" >My free slots</a></li>
	  <li ><a href="<%= url_for('/me/week') %>" >My weeks</a></li>
	  <li ><a href="<%= url_for('/prefs/me') %>" >Preferences</a></li>
	  <li ><a href="/u/v1/login" >Login</a></li>    
	</ul>
      </div>
    </div>
  </nav>
</div>

