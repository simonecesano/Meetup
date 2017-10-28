use lib 'lib/perl5';
use Data::Dump qw/dump/;

use Mojolicious::Lite;
use Mojo::UserAgent;
use DateTime;
use DBI;

my $geo_key = $ENV{GOOGLE_GEO_KEY};
my $tz_key  = $ENV{GOOGLE_TZ_KEY};

plugin 'CHI' => { default => { driver => 'DBI', dbh => DBI->connect('dbi:SQLite:dbname=./jobs.db'), global => 1, expires_in => 3600 } };

get '/latlon' => sub {
    my $c = shift;

    if (my $json = $c->chi->get('latlon::' . $c->param('q'))) {
    	app->log->info(sprintf "location %s cached", $c->param('q'));
    	$c->render(json => $json->{results}->[0]->{geometry}->{location} );
    	return;
    }

    
    my $ua  = Mojo::UserAgent->new();
    my $url = Mojo::URL->new('https://maps.googleapis.com/maps/api/geocode/json');
    $url->query({ address => $c->param('q'), key => $geo_key });
    my $tx = $ua->get($url);
    app->log->info(dump $tx->res->json);
    
    $c->chi->set('latlon::' . $c->param('q'), $tx->res->json);
    $c->render(json => $tx->res->json->{results}->[0]->{geometry}->{location} );
};

get '/timezone' => sub {
    my $c = shift;
    my $timestamp = $c->param('time') || time();
    
    if (my $json = $c->chi->get((join '::', 'latlon', $c->param('location')))) {
	app->log->info(sprintf "timezone %s cached", $c->param('location'));
	$c->render(json => $json );
	return;
    }
    
    my $ua  = Mojo::UserAgent->new();
    my $url = Mojo::URL->new('https://maps.googleapis.com/maps/api/timezone/json');

    $url->query({ location => $c->param('location'), timestamp => $timestamp, key => $tz_key });

    my $tx = $ua->get($url);
    app->log->info(dump $tx->res->json);

    $c->chi->set((join '::', 'latlon', $c->param('location')), $tx->res->json);
    $c->render(json => $tx->res->json );
};


app->start;

__DATA__
