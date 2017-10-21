#!/usr/bin/env perl
use Mojolicious::Lite;
plugin 'ACME';

get '/' => {text => 'Hello World'};

app->start;

__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome';
<h1>Welcome to the Mojolicious real-time web framework!</h1>
To learn more, you can browse through the documentation
  ec2-34-212-141-243.us-west-2.compute.amazonaws.com

    <%= link_to 'here' => '/perldoc' %>.

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>
