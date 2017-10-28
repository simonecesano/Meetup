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
plugin 'Localizer';

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

get '/person/#email' => sub {
    my $c = shift;
    $c->render(template => 'person');
};

get '/me/responses' => sub {
    my $c = shift;
    $c->render(template => 'responses');
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

