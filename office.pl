#!/usr/bin/env perl
use lib './lib/perl5';

use Mojolicious::Lite;
use Mojo::ByteStream 'b';
use Mojo::UserAgent::Google;
use Data::Dump qw/dump/;

use Mojo::JSON qw(decode_json encode_json);

plugin "OAuth2" =>
    {
     office => {
		key    => '011318dd-e2df-4eff-87de-1b04e89d925b', 
		secret => 'Bk32Mh8EfDmcigb32JZPQSh',
		authorize_url => 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize?response_type=code',
		token_url     => 'https://login.microsoftonline.com/common/oauth2/v2.0/token',
		scope => join ' ', qw|
				       User.Read
				       Mail.Read
				     |
	       },
    };

get '/' => sub {
    my $c = shift;
    $c->redirect_to($c->url_for('connect'));
};

get '/user' => sub {
    my $c = shift;
    $c->res->headers->content_type('text/plain');
    $c->render(text => 'successful');
};

get '/mail' => sub {
    my $c = shift;
    my $ua = Mojo::UserAgent::Google->new({ token => $c->session('token') });

    app->log->info(dump $c->session('token'));
    my $url = Mojo::URL->new('https://outlook.office.com/api/v2.0/me/messages');

    my $tx = $ua->post($url);
    app->log->info($tx->res->message);
    $c->render(text => 'successful');
};


get "/connect" => sub {
    my $c = shift;
    $c->delay(
	      sub {
		  my $delay = shift;
		  my $args = { redirect_uri => $c->url_for('connect')->userinfo(undef)->to_abs };
		  $c->oauth2->get_token('office' => $args, $delay->begin);
	      },
	      sub {
		  my ($delay, $err, $data) = @_;

		  app->log->info(dump $data);
		  
		  unless ($data->{code}) {
		      app->log->info("Error " . $err);
		      $c->session('token', $data);
		      $c->redirect_to('/user');
		  } else {
		      return $c->session(token => $c->redirect_to('/u/v1'));
		  }
	      },
	     );
};

app->start;

__DATA__
@@ user.html.ep
% layout 'default';
% title 'Welcome';
<div class="container-fluid">
  <div class="row">
    <div class="col-md-offset-2 col-xs-offset-1 col-md-8 col-xs-10">
      <h1>Hi <%= $user->{given_name} %>!</h1>
      This is your user page<br />
      <%= link_to 'connect' => '/connect' %>.
    </div>
  </div>
</div>
