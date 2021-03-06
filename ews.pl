#!/usr/bin/env perl

use lib 'lib/perl5';
use Data::Dump qw/dump/;

use Mojolicious::Lite;

use Mojo::UserAgent::LWP::NTLM;
use DateTime;
use DateTime::Format::Strptime;
use DateTime::TimeZone;


use Meeting;
use DBI;

plugin 'Config';
plugin 'Mojolicious::Plugin::ForkCall';

# plugin Minion => { SQLite => 'sqlite:./jobs.db' };
plugin 'CHI' => { default => { driver => 'DBI', dbh => DBI->connect('dbi:SQLite:dbname=./jobs.db'), global => 1, expires_in => 3600 } };

# plugin 'Persist' => { dbh => DBI->connect('dbi:SQLite:dbname=./jobs.db'), id => 'user' };


hook (before_dispatch => sub {
	  my $c = shift;
	  # $c->session('user', $ENV{EWS_USER})         ; # unless $c->session('user');
	  # $c->session('password', $ENV{EWS_PASSWORD}) ; # unless $c->session('password');
	  $c;
      });



get '/circle' => [format => ['json'] ] => sub {
    my $c = shift;

    my $ua  = Mojo::UserAgent->new();
    
    my $xml = $c->render_to_string(template => 'ews/inbox', format => 'xml');
    my $url = Mojo::URL->new(app->config->{ews});

    $url->userinfo(join ':', $c->session('user'), $c->session('password'));

    my $tx = $ua->post($url => {'Content-Type' => 'text/xml', 'Accept-Encoding' => 'None' } => $xml);

    my $dom = $tx->res->dom;
    my $circle = {};
    my @mails = ();

    $dom->find('EmailAddress')->each(sub{ $circle->{shift->all_text}++ });
    $dom->find('ItemId')->each(sub{ push @mails, shift->attr('Id') });
    for (keys %$circle) { delete $circle->{$_} unless /@/ }
    
    $c->fork_call(
		  sub {
		      my @mails = @_;
		      app->log->info(scalar @mails);

		      for my $id (@mails) {
			  my $ua  = Mojo::UserAgent->new();
			  $c->stash('id', $id);
			  
			  my $xml = $c->render_to_string(template => 'ews/finditem', format => 'xml');
			  my $url = Mojo::URL->new(app->config->{ews});
			  
			  $url->userinfo(join ':', $c->session('user'), $c->session('password'));
			  
			  my $tx = $ua->post($url => {'Content-Type' => 'text/xml', 'Accept-Encoding' => 'None' } => $xml);
			  my $dom = $tx->res->dom;
			  $dom->find('ToRecipients EmailAddress')->each(sub {
							       my $email = shift->all_text;
							       app->log->info($email);      
							       $circle->{$email}++
							   });
		      }
		  },
		  [@mails],
		  sub {
		      my ($c, @return) = @_;
		      $c->render(json => $circle);
		      app->log->info(dump $circle);      
		  }
		 );
    # return;
    $c->render(json => $circle);
};

get '/mail/requests' => sub {
    my $c = shift;
    my $ua  = Mojo::UserAgent->new();
    $c->stash('id', $c->param('item'));

    my $xml = $c->render_to_string(template => 'ews/requests', format => 'xml');
    my $url = Mojo::URL->new(app->config->{ews});

    $url->userinfo(join ':', $c->session('user'), $c->session('password'));

    my $tx = $ua->post($url => {'Content-Type' => 'text/xml', 'Accept-Encoding' => 'None' } => $xml);

    if ($c->param('f') eq 'xml') {
	$c->res->headers->content_type('text/xml');
	$c->render(text => $tx->res->dom || 'nothing found');
	return;
    }

    my @items;
    $tx->res->dom->find('MeetingRequest')
	->each(sub{
		   my $i = shift;
		   push @items, {
				 start     => $i->at('Start')->all_text,
				 end       => $i->at('End')->all_text,
				 subject   => $i->at('Subject')->all_text,
				 organizer => $i->at('Organizer')->at('Name')->all_text,
				}
	       });
    $c->render(json => \@items);
};

get '/mail/*item' => sub {
    my $c = shift;
    my $ua  = Mojo::UserAgent->new();
    $c->stash('id', $c->param('item'));

    my $xml = $c->render_to_string(template => 'ews/finditem', format => 'xml');
    my $url = Mojo::URL->new(app->config->{ews});

    $url->userinfo(join ':', $c->session('user'), $c->session('password'));

    my $tx = $ua->post($url => {'Content-Type' => 'text/xml', 'Accept-Encoding' => 'None' } => $xml);
    $c->res->headers->content_type('text/xml');
    $c->render(text => $tx->res->dom || 'nothing found');
    return;

    $c->render(json => $c->param('item'));
};

my $busy = sub {
    my $c = shift;
    my $start = shift;

    app->log->info('start ' . $start);
    app->log->info('timezone ' . $start->time_zone->name);

    my $end = $start->clone->add(days => 14);
    
    $c->stash('email', $c->param('email'));
    $c->stash('start', $start . 'Z');
    $c->stash('end', $end . 'Z');
    $c->stash('interval', '30');

    my $ua  = Mojo::UserAgent->new();
    my $url = Mojo::URL->new(app->config->{ews});

    $url->userinfo(join ':', $c->session('user'), $c->session('password'));

    my $xml = $c->render_to_string(template => 'ews/freebusy', format => 'xml');
    
    my $tx = $ua->post($url => {'Content-Type' => 'text/xml', 'Accept-Encoding' => 'None' } => $xml);
    my $fb = $tx->res->dom->at('MergedFreeBusy')->all_text;
    return $fb;
};

get '/busy/#email' => sub {
    my $c = shift;

    my $strp = DateTime::Format::Strptime->new(pattern => '%FT%T%z');
    my $start = $strp->parse_datetime($c->param('start') =~ s/z$//ri) || DateTime->now;

    app->log->info('start ' . $start);
    app->log->info('timezone ' . $start->time_zone->name);
    
    if ($start->minute >= 30) { $start->set_minute(30) } else { $start->set_minute(0) }

    $start->set_second(0);

    my $fb = $busy->($c, $start);

    app->log->info($fb);
    
    my $person = Meeting::Person->new({ email => $c->param('email'), start => $start, freebusy => $fb });

    $person->habits([
		     {  daily => { start => { hours => 9, minutes => 0 }, end => { hours => 18, minutes => 0 }, time_zone => "Europe/Berlin" } },
		     { -daily => { start => { hours => 12, minutes => 0 }, end => { hours => 13, minutes => 0 }, time_zone => "Europe/Berlin" } },
		     { -weekly => { days => [6, 7], time_zone => "Europe/Berlin" } }
		    ]);
    
    my @slots = $person->free_slots;
    # app->log->info(dump [ map { $_ } @slots ]);
    $c->render(json => { freebusy => $person->freebusy_filtered, slots => \@slots, start => $person->start });
};

my $search = sub {
    my $c = shift;
    
    if (($c->param('email')) && (my $json = $c->chi->get('person::' . $c->param('email')))) { $c->render(json => $json); return }
    
    my $ua  = Mojo::UserAgent->new();

    $c->stash('name', $c->param('email') || $c->param('q'));

    my $xml = $c->render_to_string(template => 'ews/whois', format => 'xml');

    my $url = Mojo::URL->new(app->config->{ews});
    $url->userinfo(join ':', $c->session('user'), $c->session('password'));

    my $tx = $ua->post($url => {'Content-Type' => 'text/xml', 'Accept-Encoding' => 'None' } => $xml);
    my $dom = $tx->res->dom;

    my $parse = sub {
	my $dom = shift;
	app->log->info($dom);
	my $person = {};
	
	$person->{email}    = $dom->at('EmailAddress')->all_text;
	$person->{name}     = $dom->at('GivenName')->all_text;
	$person->{surname}  = $dom->at('Surname')->all_text;
	$person->{mobile}   = $dom->at('[Key="MobilePhone"]')->all_text || $dom->at('[Key="BusinessPhone"]')->all_text;
	$person->{country}  = $dom->at('CountryOrRegion')->all_text;
	$person->{city}     = $dom->at('State')->all_text ? (join ', ', $dom->at('City')->all_text, $dom->at('State')->all_text) : $dom->at('City')->all_text;
	$person->{title}    = $dom->at('JobTitle')->all_text;
	$person->{location} = $dom->at('OfficeLocation')->all_text;

	return $person;
    };
    
    if ($c->param('email')) {
	my $person = $parse->($dom);
	$c->chi->set('person::' . $c->param('email'), $person);
	$c->render(json => $person);
    } else {
	my @people;
	$dom->find('Resolution')
	    ->each(sub { push @people, $parse->(shift) });
	$c->render(json => { results => \@people });
    }
};

get '/person/#email' => $search;

get '/person/' => $search;

get '/q/*xml' => sub {
    my $c = shift;

    my $url = Mojo::URL->new(app->config->{ews});
    app->log->info($c->param('xml'));
    
    $url->userinfo(join ':', $c->session('user'), $c->session('password'));

    $c->stash($c->req->params->to_hash);
    my $xml = $c->render_to_string(template => $c->param('xml'), format => 'xml');

    my $ua  = Mojo::UserAgent->new();
    my $tx = $ua->post($url => {'Content-Type' => 'text/xml', 'Accept-Encoding' => 'None' } => $xml);

    my $dom = $tx->res->dom;

    $c->res->headers->content_type('text/xml');
    $c->render(text => $dom);
};

any '/meeting/book' => sub {
    # start end subject notes attendees
    my $c = shift;
    my $url = Mojo::URL->new(app->config->{ews});
    $url->userinfo(join ':', $c->session('user'), $c->session('password'));

    my $h = $c->req->params->to_hash;

    for (grep { /\[\]$/} keys %$h) {
	app->log->info($_);
	my $k = $_ =~ s/\[\]$//r;
	$h->{$k} = delete $h->{$_}
    }
    $h->{attendees} = ref $h->{attendees} ? $h->{attendees} : [ $h->{attendees} ];
    $h->{attendees} = [qw/simone.cesano@adidas.com/];
    $c->stash($h);


    app->log->info(dump $h);
    app->log->info(ref app->renderer);

    my $xml = $c->render_to_string(template => 'ews/book', format => 'xml');

    app->log->info($xml);
    
    my $ua  = Mojo::UserAgent->new();
    if (1) {
	$c->render(text => 'all ok');
    } else {
	my $tx;
	$tx = $ua->post($url => {'Content-Type' => 'text/xml', 'Accept-Encoding' => 'None' } => $xml);
	
	my $dom = $tx->res->dom;
	app->log->info($tx->res->message);
	$c->res->headers->content_type('text/xml');
	$c->render(text => $dom || 'all ok');
    }
};

get '/timezones' => sub {
    my $c = shift;
    my @tz = DateTime::TimeZone->all_names;
    if ($c->param('q')) { my $re = $c->param('q'); $re =~ s /\s/_/g; @tz = grep { /$re/i } @tz };
    $c->render(json => \@tz);
    
};

app->start;

__DATA__
@@ ews/inbox.xml.ep
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages"
    xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types"
    xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Header>
    <t:RequestServerVersion Version="Exchange2013" />
  </soap:Header>
  <soap:Body>
    <m:FindItem Traversal="Shallow">
      <m:ItemShape>
        <t:BaseShape>Default</t:BaseShape>
        <t:AdditionalProperties>
          <t:FieldURI FieldURI="message:From" />
	  <t:FieldURI FieldURI="message:ToRecipients" />
        </t:AdditionalProperties>
      </m:ItemShape>
      <m:IndexedPageItemView MaxEntriesReturned="200" Offset="0" BasePoint="Beginning" />
      <m:SortOrder>
        <t:FieldOrder Order="Descending">
          <t:FieldURI FieldURI="item:DateTimeReceived" />
        </t:FieldOrder>
      </m:SortOrder>
      <m:ParentFolderIds>
	<t:DistinguishedFolderId Id="inbox" />
	<t:DistinguishedFolderId Id="sentitems" />
      </m:ParentFolderIds>
    </m:FindItem>
  </soap:Body>
</soap:Envelope>
@@ ews/freebusy.xml.ep
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages" xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Header>
    <t:RequestServerVersion Version="Exchange2010_SP1" />
    <t:TimeZoneContext>
      <t:TimeZoneDefinition Name="(UTC+01:00) Belgrade, Bratislava, Budapest, Ljubljana, Prague" Id="Central Europe Standard Time">
	<t:Periods>
	  <t:Period Bias="-PT1H" Name="Standard" Id="trule:Microsoft/Registry/Central Europe Standard Time/1-Standard" />
	  <t:Period Bias="-PT2H" Name="Daylight" Id="trule:Microsoft/Registry/Central Europe Standard Time/1-Daylight" />
	</t:Periods>
	<t:TransitionsGroups>
	  <t:TransitionsGroup Id="0">
	    <t:RecurringDayTransition>
	      <t:To Kind="Period">trule:Microsoft/Registry/Central Europe Standard Time/1-Daylight</t:To>
	      <t:TimeOffset>PT2H</t:TimeOffset>
	      <t:Month>3</t:Month>
	      <t:DayOfWeek>Sunday</t:DayOfWeek>
	      <t:Occurrence>-1</t:Occurrence>
	    </t:RecurringDayTransition>
	    <t:RecurringDayTransition>
	      <t:To Kind="Period">trule:Microsoft/Registry/Central Europe Standard Time/1-Standard</t:To>
	      <t:TimeOffset>PT3H</t:TimeOffset>
	      <t:Month>10</t:Month>
	      <t:DayOfWeek>Sunday</t:DayOfWeek>
	      <t:Occurrence>-1</t:Occurrence>
	    </t:RecurringDayTransition>
	  </t:TransitionsGroup>
	</t:TransitionsGroups>
	<t:Transitions>
	  <t:Transition>
	    <t:To Kind="Group">0</t:To>
	  </t:Transition>
	</t:Transitions>
      </t:TimeZoneDefinition>
    </t:TimeZoneContext>
  </soap:Header>
  <soap:Body>
    <m:GetUserAvailabilityRequest>
      <m:MailboxDataArray>
        <t:MailboxData>
          <t:Email>
            <t:Address><%= $email %></t:Address>
          </t:Email>
          <t:AttendeeType>Required</t:AttendeeType>
          <t:ExcludeConflicts>false</t:ExcludeConflicts>
        </t:MailboxData>
      </m:MailboxDataArray>
      <t:FreeBusyViewOptions>
        <t:TimeWindow>
          <t:StartTime><%= $start %></t:StartTime>
          <t:EndTime><%= $end %></t:EndTime>
        </t:TimeWindow>
        <t:MergedFreeBusyIntervalInMinutes><%= $interval %></t:MergedFreeBusyIntervalInMinutes>
        <t:RequestedView>MergedOnly</t:RequestedView>
      </t:FreeBusyViewOptions>
    </m:GetUserAvailabilityRequest>
  </soap:Body>
</soap:Envelope>    
@@ ews/folders.xml.ep
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
       xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages" 
       xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types" 
       xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Header>
    <t:RequestServerVersion Version="Exchange2013" />
  </soap:Header>
  <soap:Body>
    <m:GetFolder>
      <m:FolderShape>
	<t:BaseShape>Default</t:BaseShape>
      </m:FolderShape>
      <m:FolderIds>
	<t:DistinguishedFolderId Id="inbox" />
	<t:DistinguishedFolderId Id="sentitems" />
	<t:DistinguishedFolderId Id="contacts" />
        <t:DistinguishedFolderId Id="calendar" />
      </m:FolderIds>
    </m:GetFolder>
  </soap:Body>
</soap:Envelope>
@@ ews/whois.xml.ep
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
@@ ews/finditem.xml.ep
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
               xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages" 
               xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types" 
               xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Header>
    <t:RequestServerVersion Version="Exchange2013" />
  </soap:Header>
  <soap:Body>
    <m:GetItem>
      <m:ItemShape>
        <t:BaseShape>IdOnly</t:BaseShape>
        <t:AdditionalProperties>
          <t:FieldURI FieldURI="item:Subject" />
	  <t:FieldURI FieldURI="message:From" />
	  <t:FieldURI FieldURI="message:ToRecipients" />
	  <t:FieldURI FieldURI="message:CcRecipients" />
        </t:AdditionalProperties>
      </m:ItemShape>
      <m:ItemIds>
        <t:ItemId Id="<%= $id %>" />
      </m:ItemIds>
    </m:GetItem>
  </soap:Body>
</soap:Envelope>    
@@ ews/requests.xml.ep
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages"
               xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types"
               xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Header>
    <t:RequestServerVersion Version="Exchange2007_SP1" />
  </soap:Header>
  <soap:Body>
    <m:FindItem Traversal="Shallow">
      <m:ItemShape>
        <t:BaseShape>Default</t:BaseShape>
        <t:AdditionalProperties>
          <t:FieldURI FieldURI="item:Subject" />
	  <t:FieldURI FieldURI="item:ItemClass" />
	  <t:FieldURI FieldURI="calendar:Start" />
	  <t:FieldURI FieldURI="calendar:End" />
	  <t:FieldURI FieldURI="calendar:RequiredAttendees" />
        </t:AdditionalProperties>
      </m:ItemShape>
      <m:ParentFolderIds>
        <t:DistinguishedFolderId Id="inbox" />
      </m:ParentFolderIds>
      <m:Restriction>
	<t:IsEqualTo>
	  <t:FieldURI FieldURI="item:ItemClass" />
	  <t:FieldURIOrConstant>
	    <t:Constant Value="IPM.Schedule.Meeting.Request" />
	  </t:FieldURIOrConstant>
	</t:IsEqualTo>
      </m:Restriction>
    </m:FindItem>
  </soap:Body>
</soap:Envelope>
@@ layouts/default.xml.ep
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xmlns:m="http://schemas.microsoft.com/exchange/services/2006/messages"
               xmlns:t="http://schemas.microsoft.com/exchange/services/2006/types"
               xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Header>
    <t:RequestServerVersion Version="Exchange2013" />
  </soap:Header>
    <soap:Body>
<%= content %></soap:Body>
</soap:Envelope>
    
@@ ews/book.xml.ep
% layout 'default';
    <m:CreateItem SendMeetingInvitations="SendToAllAndSaveCopy">
      <m:Items>
        <t:CalendarItem>
          <t:Subject><%= $subject %></t:Subject>
          <t:Body BodyType="Text"><%= $notes %></t:Body>
          <t:Start><%= $start %></t:Start>
          <t:End><%= $end %></t:End>
	  <t:Location><%= $location %></t:Location>
	  <t:RequiredAttendees>
	    % for my $attendee (@{$attendees}) {
            <t:Attendee>
              <t:Mailbox>
                <t:EmailAddress><%= $attendee %></t:EmailAddress>
              </t:Mailbox>
            </t:Attendee>
	    % }
	  </t:RequiredAttendees>
        </t:CalendarItem>
      </m:Items>
    </m:CreateItem>
