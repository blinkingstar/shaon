package shaon;
use Dancer;

use DBIx::Simple;
use SQL::Abstract;

my $db = DBIx::Simple->connect('dbi:SQLite:dbname=' . path(dirname(__FILE__), 'data/wiki.db'));
$db->abstract = SQL::Abstract->new();

use Text::Xatena;

# create table wiki (id integer PRIMARY KEY, wikiname text not null, rev int NOT NULL, date integer NOT NULL, wikidata text);
# create table uploads (id int primary key, filename text unique);

before sub {
	#my $latests = $db->query('select wikiname, date, wikidata from wiki group by wikiname order by date desc limit 10');
	my $latests = $db->query('select wikiname, date, wikidata from wiki group by wikiname order by date desc');
	var list => $latests;
	layout 'main';
};

get '/' => sub {
	if (request->{'user_agent'} =~ m{iPhone|iPod}i){
    	my $wiki = {wikiname => 'Page list'};
    	layout 'iphone';
    	template 'iphone/index', { wiki => $wiki, latests => vars->{list} };
	}
	else {
		redirect '/Front';
	}
};

get '/new' => sub {
	my $wiki = {wikiname => 'New'};
	if (request->{'user_agent'} =~ m{iPhone|iPod}i){
		layout 'iphone';
		template 'iphone/edit', { wiki => $wiki, latests => vars->{list} };
	}
	else {
		template 'edit', { wiki => $wiki, latests => vars->{list} };
	}
};

post '/update' => sub {
	my $wikiname = params->{'wikiname'};
	my $wikidata = params->{'wikidata'};
	$wikidata =~ s{(\r\n|\r)}{\n}g;
	my $trivial = params->{'trivial'};
	if (!$wikiname || !$wikidata) {
		redirect '/';
	}
	my $wikis = $db->select('wiki', ['rev','date'], {'wikiname' => $wikiname},{-desc => 'rev'});
	my $wiki = $wikis->hash || {rev => 0, date => time()};
	my $rev = $wiki->{'rev'} + 1;
	my $date = $trivial ? $wiki->{'date'} : time();
	$db->insert('wiki',{wikiname => $wikiname, rev => $rev, date => $date, wikidata => $wikidata});
	redirect '/' . $wikiname;
};

post '/upload' => sub {
	my $upload = upload('file_upload');
	my $exist_file = $db->select('uploads','count()',{'filename' => $upload->filename})->list;
	if ($exist_file){
		redirect '/upload?message=error';
	}
	$upload->copy_to(path(dirname(__FILE__), 'public/uploads/', $upload->filename));
	$db->insert('uploads',{'filename' => $upload->filename});
	redirect '/upload';
};

get '/upload' => sub {
	my $uploads = $db->select('uploads','*');
	my $wiki = {wikiname => 'uploads'};
	template 'upload', { wiki => $wiki, uploads => $uploads, latests => vars->{list} };
};

get '/:wikiname' => sub {
	my $wikiname = params->{'wikiname'};
	my $wikis = $db->select('wiki', '*', {'wikiname' => $wikiname},{-desc => 'rev'});
	my $wiki = $wikis->hash;
	my $hatena = Text::Xatena->new();
	$wiki->{'wikidata'} = $hatena->format($wiki->{'wikidata'} || 'Content is empty.',inline => MyInline->new);
	#return Dumper(vars->{list});
	$wiki->{'wikiname'} ||= $wikiname;
	if (request->{'user_agent'} =~ m{iPhone|iPod}i){
		layout 'iphone';
		template 'iphone/page', { wiki => $wiki, latests => vars->{list} };
	}
	else {
		template 'page', { wiki => $wiki, latests => vars->{list} };
	}
};

get '/:wikiname/edit' => sub {
	my $wikiname = params->{wikiname};
	my $wikis = $db->select('wiki', '*', {'wikiname' => $wikiname},{-desc => 'rev'});
	my $wiki = $wikis->hash;
	$wiki->{'wikiname'} ||= $wikiname;
	if (request->{'user_agent'} =~ m{iPhone|iPod}i){
		layout 'iphone';
		template 'iphone/edit', { wiki => $wiki, latests => vars->{list} };
	}
	else {
		template 'edit', { wiki => $wiki, latests => vars->{list} };
	}
};

true;

package MyInline;

use URI::Escape;
use LWP::UserAgent;
use HTML::Entities;
use Text::Xatena::Inline::Base -Base;
use Cache::MemoryCache;

sub cache { Cache::MemoryCache->new }

match qr<\[((?:https?|ftp)://[^\s:]+(?::\d+)?[^\s:]+)(:(?:title(?:=([^[]+))?|barcode))?\]>i => sub {
    my ($self, $uri, $opt, $title) = @_;

    if ($opt) {
        if ($opt =~ /^:barcode$/) {
            return sprintf('<img src="http://chart.apis.google.com/chart?chs=150x150&cht=qr&chl=%s" title="%s"/>',
                uri_escape($uri),
                $uri,
            );
        }
        if ($opt =~ /^:title/) {
            if (!$title) {
                $title = $self->cache->get($uri);
                if (not defined $title) {
                    eval {
                    	my $ua = LWP::UserAgent->new;
                        my $res = $ua->get($uri);
                        ($title) = ($res->decoded_content =~ qr|<title[^>]*>([^<]*)</title>|is);
                        $title ||= $uri;
                        $title =~ s{\n}{}g;
                        utf8::encode($title);
                        #encode_entities(decode_entities($title))
                        $self->cache->set($uri, $title, "30 days");
                    };
                    if ($@) {
                        warn $@;
                    }
                }
            }
            $title ||= $uri;
            return sprintf('<a href="%s">%s</a>',
                $uri,
                $title
            );
        }
    } else {
        return sprintf('<a href="%s">%s</a>',
            $uri,
            $uri
        );
    }

};

match qr<\[\[(.*?)\]\]>i => sub {
	my ($self, $wikiname) = @_;
	return sprintf('<a href="/%s">%s</a>',
		uri_escape($wikiname),
		$wikiname
	);
};

match qr<\[map:(.*?)\]>i => sub {
	my ($self, $args) = @_;
	
	return sprintf('<div class="map">%s</div>',
		$args
	);
};