package EPrints::DataCite::Utils;

use LWP::UserAgent;
use JSON;
use Encode;

use strict;

sub generate_doi
{
    my( $repository, $dataobj ) = @_;

    if( $repository->can_call( "generate_doi_override" ) )
    {
        return $repository->call( "generate_doi_override", $repository, $dataobj );
    }

    my $z_pad = $repository->get_conf( "datacitedoi", "zero_padding") || 0;

    my $id = $dataobj->id;
    $id  = sprintf( "%0" . $z_pad . "d" , $id );
   
    if( $dataobj->get_dataset_id eq "document" )
    {
        my $eprintid = $dataobj->get_eprint->id;
        $eprintid = sprintf( "%0" . $z_pad . "d" , $eprintid );
        $id = "$eprintid.$id";
    }

    my( $delim1, $delim2 ) = @{$repository->get_conf( "datacitedoi", "delimiters" )};

    # default to slash
    $delim1 = "/" if( !defined $delim1 );

    # second defaults to first
    $delim2 = $delim1 if( !defined $delim2 );

    # construct the DOI string
    my $prefix = $repository->get_conf( "datacitedoi", "prefix" );
    my $thisdoi = $prefix.$delim1.$repository->get_conf( "datacitedoi", "repoid" ).$delim2.$id;
    
    return $thisdoi;    
}

# reserve a doi, a.k.a create draft doi
sub reserve_doi
{
    my( $repo, $dataobj, $doi ) = @_;
    
    my $class = $dataobj->get_dataset_id;

    my $datacite_url = URI->new( $repo->config( 'datacitedoi', 'apiurl' ) . "/dois" );   

    my $repo_url;
    if( $repo->can_call( $class."_landing_page" ) )
    {
        $repo_url = $repo->call( $class."_landing_page", $dataobj, $repo );
    }
    else
    {
        $repo_url = $dataobj->uri();
    }

    my $user_name = $repo->get_conf( "datacitedoi", "user" );
    my $user_pw = $repo->get_conf( "datacitedoi", "pass" );

    my $xml = $dataobj->export( "DataCiteXML" );
    $xml = MIME::Base64::encode_base64( encode('utf-8', $xml ) );

    # Write JSON payload to a temp file to avoid shell escaping issues
    my $tmp = File::Temp->new( SUFFIX => '.json', UNLINK => 1 );
    print $tmp qq(
{
  "data": {
    "type": "dois",
    "attributes": {
      "doi": "$doi",
      "url": "$repo_url",
      "xml": "$xml"
    }
  }
}
);

    $tmp->flush();
    my $tmp_path = $tmp->filename();

    # Build and run the curl command
    my @cmd = (
        'curl',
        '--silent',
        '-X',       'POST',
        '-H',       '"Content-Type: application/vnd.api+json"',
        '--user',   "$user_name:$user_pw",
        '-d',       '@' . $tmp_path,
        $datacite_url,
    );

    # Capture output and HTTP status code
    my $response_body = '';	
    my $response_code = '';
    my $curl_output = `@cmd --write-out '\\n%{http_code}' 2>&1`;
    if( $curl_output =~ /\A(.*)\n(\d{3})\z/s )
    {
        $response_body = $1;
        $response_code = $2;
    }

    if( $response_code =~ /^2/ )
    {
        my $doifield = $repo->get_conf( "datacitedoi", $class."doifield" );
        $dataobj->set_value( $doifield, $doi );
        $dataobj->commit;
    }
    else
    {
        $repo->log( "Error reserving DOI. Code: " . $response_code . "; Content: " . $response_body );
    }

    return ($response_body, $response_code);    
}

# update metadata
sub update_metadata
{
    my( $repo, $dataobj, $doi, $url ) = @_;
 
    my $class = $dataobj->get_dataset_id;

    my $datacite_url = URI->new( $repo->config( 'datacitedoi', 'apiurl' ) . "/dois/$doi" );   

    my $xml = $dataobj->export( "DataCiteXML" );
    $xml = MIME::Base64::encode_base64( encode('utf-8', $xml ) );

    my $content;
    if( defined $url )
    {

        # build the content
        $content = qq(
{
  "data": {
    "attributes": {
      "url": "$url",
      "xml": "$xml"
    }
  }
}
);
    }
    else
    {
        $content = qq(
{
  "data": {
    "attributes": {
      "xml": "$xml"
    }
  }
}
);
    }

    # build request
    my $headers = HTTP::Headers->new(
        'Content-Type' => 'application/vnd.api+json',
    );
    
    my $req = HTTP::Request->new(
        PUT => $datacite_url,
        $headers, Encode::encode_utf8( $content )
    );

    my $user_name = $repo->get_conf( "datacitedoi", "user" );
    my $user_pw = $repo->get_conf( "datacitedoi", "pass" );
    $req->authorization_basic($user_name, $user_pw);

    my $ua = LWP::UserAgent->new;
    my $res = $ua->request($req);
    
    return $res;
}


# get the landing page of a single doi from the mds api
sub datacite_doi_query
{
    my( $repo, $doi ) = @_;

    my $datacite_url = URI->new( $repo->config( 'datacitedoi', 'apiurl' ) . "/dois/$doi" );

    my $ua = LWP::UserAgent->new();
    my $req = HTTP::Request->new( GET => $datacite_url );
 
    my $user_name = $repo->get_conf( "datacitedoi", "user" );
    my $user_pw = $repo->get_conf( "datacitedoi", "pass" );
    $req->authorization_basic($user_name, $user_pw);

    my $res = $ua->request($req);
    if( $res->is_success )
    {
        my $json = JSON->new->allow_nonref;
        my $doi_data =  $json->utf8->decode( $res->content );
        return $doi_data;
    }
    else
    {
        $repo->log("Error retrieving DOI from API. Response code: " . $res->code . ", content: " . $res->content );
        return undef;
    }   
}

sub datacite_api_query
{
	my( $repo, $field, $value ) = @_;

    my %response;

    my $datacite_url = URI->new( $repo->config( 'datacitedoi', 'apiurl' ) . "/dois" );
    
    my $ua = LWP::UserAgent->new();

    $datacite_url->query_form( query => "$field:$value" );

    my $accept_header = "application/json";
    my $req_headers = HTTP::Headers->new( "Accept" => $accept_header );

    my $req = HTTP::Request->new( GET => $datacite_url, $req_headers );
    my $res = $ua->request($req);

    if( $res->is_success )
    {
        my $json = new JSON;
        $json = $json->utf8->decode( $res->content );    
        my @results;
        my $count = 0;
        my $max = $repo->config( 'datacitedoi', 'max_results' ) || 5;
        foreach my $record ( @{$json->{data}} )
        {   
            my $attributes = $record->{attributes};
            push @results, {
                title => $attributes->{titles}[0]->{title},
                date => $attributes->{publicationYear},
                publisher => $attributes->{publisher},
                url => $attributes->{url},
                doi => $attributes->{doi},
            };
            $count++;
            last if $count >= $max;
        }
        $response{results} = \@results;
        return \%response;
    }
    else
    {
        $response{error} = 1;
        $response{code} = $res->code;
        return \%response;
    }
}

# when given a parent or child eprint, get the information need to construct the relatedIdentifier xml
# we'll prioritise DOI for the identifier type, but may want a hierarchy of other options later
sub create_related_identifier
{
    my( $repo, $xml, $eprint, $relationType ) = @_;

    my $doi_field = $repo->get_conf( "datacitedoi", "eprintdoifield" );

    # initialise identifier value and type
    my $idValue = undef;
    my $idType = undef;

    # does this parent have a DOI?
    if( $eprint->is_set( $doi_field ) )
    {
        # get it and check it with DataCite
        my $eprint_doi = $eprint->value( $doi_field );
        my $datacite_data = EPrints::DataCite::Utils::datacite_doi_query( $repo, $eprint_doi );
        if( defined $datacite_data )
        {
            $idValue = $eprint_doi;
            $idType = "DOI";
        }
    }

    if( !defined $idValue )
    {
        # we'll settle for the eprint uri for now - TODO expand this to look at ISSN, ISBN, etc. see https://schema.datacite.org/meta/kernel-4.4/doc/DataCite-MetadataKernel_v4.4.pdf for possible options
        if( $eprint->value( "eprint_status" ) eq "archive" )
        {
            $idValue = $eprint->uri;
            $idType = "URL";
        }
    }

    # only be creating XML if we have all the values we need
    if( defined $idValue && defined $idType )
    {
        return $xml->create_data_element( "relatedIdentifier", $idValue, relatedIdentifierType => $idType, relationType => $relationType );
    }
    else
    {
        return undef;
    }
}

1;
