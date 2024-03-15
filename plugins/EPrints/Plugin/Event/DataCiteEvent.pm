=head1 NAME

EPrints::Plugin::Event::DataCiteEvent

=cut

package EPrints::Plugin::Event::DataCiteEvent;

use EPrints::Plugin::Event;
use EPrints::DataCite::Utils;

eval "use LWP; use HTTP::Headers::Util";
eval "use WWW::Curl::Easy";

@ISA = qw( EPrints::Plugin::Event );

# updates the URL, metadata and sets as findable the DataCite record of the given DOI, 
# or generates a DOI from the dataobj if $doi not provided
sub datacite_doi
{
    my( $self, $dataobj, $doi ) = @_;

    my $repository = $self->repository();

    if( defined $repository->get_conf( "datacitedoi", "get_curl" ) )
    {
        # Try and import Curl.
        if ( eval "use WWW::Curl::Easy" ) { print STDERR "Unable to import WWW::Curl::Easy.\n"; }
    }
    else
    {
        # Fall back to LWP and rely in its library detection.
        if ( eval "use LWP" ) { print STDERR "Unable to import LWP.\n"; }
        if ( eval "use HTTP::Headers::Util" ) { print STDERR "Unable to import HTTP::Headers::Util.\n"; }
    }

    my $class = $dataobj->get_dataset_id;

    # Check object status first...
    my $eprint = $dataobj;
    if( $class eq "document" )
    {
        $eprint = $dataobj->get_eprint;

        if( !$repository->get_conf( "datacitedoi", "document_dois" ) )
        {
            $repository->log("Document DOI functionality not available on this repository");
            return EPrints::Const::HTTP_INTERNAL_SERVER_ERROR;                           
        }
    }

    my $shoulddoi = $repository->get_conf( "datacitedoi", "eprintstatus",  $eprint->value( "eprint_status" ) );
    # Check oi Status
    if( !$shoulddoi )
    {
        $repository->log("Attempt to coin DOI for item that is not in the required area (see \$c->{datacitedoi}->{eprintstatus})");
        return EPrints::Const::HTTP_INTERNAL_SERVER_ERROR;
    }

    # if we're passed a DOI, use that one, otherwise use the generated one
    my $thisdoi = $doi;
    $thisdoi = EPrints::DataCite::Utils::generate_doi( $repository, $dataobj ) unless defined $doi;

    # coin_doi may return an event error code if no prefix present assume this is the case
    my $prefix = $repository->get_conf( "datacitedoi", "prefix");
    return $thisdoi if($thisdoi !~ /^$prefix/);

    # Pass doi into Export::DataCiteXML...
    my $xml = $dataobj->export( "DataCiteXML", doi=> $thisdoi );
    return $xml if( $xml =~ /^\d+$/ ); # just a number? coin_doi has passed back an error code pass it on...

    my $url = $repository->get_conf( "datacitedoi", "mdsurl" );
    $url.="/" if( $url !~ /\/$/ ); # attach slash if config has forgotten
    my $user_name = $repository->get_conf( "datacitedoi", "user" );
    my $user_pw = $repository->get_conf( "datacitedoi", "pass" );

    # register metadata;
    my $response_content;
    my $response_code;
    # Test if we want to be using curl; if we don't run the 'old' LWP code
    if( defined $repository->get_conf( "datacitedoi", "get_curl" ) )
    {
        ( $response_content, $response_code ) =  datacite_request_curl( $url."metadata", $user_name, $user_pw, $xml, "application/xml;charset=UTF-8" );
    }
    else
    {
        ( $response_content, $response_code ) =  datacite_request( "POST", $url."metadata", $user_name, $user_pw, $xml, "application/xml;charset=UTF-8" );
    }

    if( $response_code !~ /20(1|0)/ )
    {
        $repository->log( "Metadata response from datacite api when submitting $class " . $dataobj->id . ": $response_code: $response_content" );
        $repository->log( "XML submitted was:\n$xml" );
        return EPrints::Const::HTTP_INTERNAL_SERVER_ERROR;
    }

    # register doi
    my $repo_url;
    if( $repository->can_call( $class."_landing_page" ) )
    {
        $repo_url = $repository->call( $class."_landing_page", $dataobj, $repository );
    }
    else
    {
        $repo_url = $dataobj->uri();
    }
    # RM special override to allow testing from "wrong" domain
    if( defined $repository->get_conf( "datacitedoi", "override_url" ) )
    {
        $repo_url = $repository->get_conf( "datacitedoi", "override_url" );
        if( $repository->can_call( $class."_internal_landing_page" ) )
        {
            $repo_url .= $repository->call( $class."_internal_landing_page", $dataobj, $repository );
        }
        else
        {
            $repo_url .= $dataobj->internal_uri;
        }
    }
    my $doi_reg = "doi=$thisdoi\nurl=".$repo_url; 

    # Test if we want to be using curl; if we don't run the 'old' LWP code
    if( defined $repository->get_conf( "datacitedoi", "get_curl" ) )
    {
        ( $response_content, $response_code )= datacite_request_curl( $url."doi", $user_name, $user_pw, $doi_reg, "text/plain; charset=utf8" );
    }
    else
    {
        ( $response_content, $response_code )= datacite_request("POST", $url."doi", $user_name, $user_pw, $doi_reg, "text/plain; charset=utf8" );
    }
    if( $response_code  !~ /20(1|0)/ )
    {
        $repository->log("Registration response from datacite api: $response_code: $response_content");
        $repository->log("XML submitted was:\n$xml");
        return EPrints::Const::HTTP_INTERNAL_SERVER_ERROR;
    }

    # now it is safe to set DOI value.
    my $doifield = $repository->get_conf( "datacitedoi", $class."doifield" ); 
    $dataobj->set_value( $doifield, $thisdoi );
    $dataobj->commit();

    # we should also store a record of the dataobj's mandatory datacite fields and values
    update_repository_record( $repository, $dataobj );

    # success
    return undef;
}


sub datacite_request
{
    my( $method, $url, $user_name, $user_pw, $content, $content_type ) = @_;

    # build request
    my $headers = HTTP::Headers->new(
        'Accept'  => 'application/xml',
        'Content-Type' => $content_type
    );

    my $req = HTTP::Request->new(
        $method => $url,
        $headers, Encode::encode_utf8( $content )
    );
    $req->authorization_basic($user_name, $user_pw);

    # pass request to the user agent and get a response back
    my $ua = LWP::UserAgent->new;
    my $res = $ua->request($req);

    return ($res->content(),$res->code());
}

sub datacite_request_curl
{
    my( $url, $user_name, $user_pw, $content, $content_type ) = @_;

    # build request
    my @myheaders = (
        "Accept: application/xml",
        "Content-Type: $content_type"
    );
    
    my $curl = new WWW::Curl::Easy;

    $curl->setopt(CURLOPT_FAILONERROR,1);
    # $curl->setopt(CURLOPT_HEADER,1);
    # $curl->setopt(CURLOPT_VERBOSE, 1);
    $curl->setopt(CURLOPT_POST, 1);
    $curl->setopt(CURLOPT_URL, $url);
    $curl->setopt(CURLOPT_USERNAME, $user_name);
    $curl->setopt(CURLOPT_PASSWORD, $user_pw);
    $curl->setopt(CURLOPT_POSTFIELDS, $content);
    $curl->setopt(CURLOPT_HTTPHEADER, \@myheaders);

    my $response_body;
    open( my $fileb, ">", \$response_body );
    $curl->setopt(CURLOPT_WRITEDATA,$fileb);


    # pass request and get a response back
    my $retcode = $curl->perform;

    # Use response to determine HTTP status code
    $http_retcode    = $curl->getinfo(CURLINFO_HTTP_CODE);

#   # Ensure we return a useful (well, usable) message and error response
#   if ($retcode == 0) {
#     $content = "Received response: $response_body\n";
#   } else {
#     $http_prose = $curl->strerror($retcode);
#     $content = "An error happened: $http_prose $http_retcode (Curl error code $retcode)\n";
#   }

    return ($content, $http_retcode);
}

sub datacite_update_doi_state
{
    my( $self, $dataobj, $new_status ) = @_;

    my $repo = $self->repository;

    # check to see if we're supporting documents
    my $class =  $dataobj->get_dataset_id;
    if( $class eq "document" && !$repo->get_conf( "datacitedoi", "document_dois" ) )
    {
        return EPrints::Const::HTTP_NOT_FOUND;
    }
    
    # get dataobj and doi
    my $doi_field = $repo->get_conf( "datacitedoi", $class."doifield" );
    my $dataobj_doi = $dataobj->value( $doi_field );
    my $dataobj_id = $dataobj->id;

    # get eprint id
    my $eprint_id = $dataobj_id;    
    if( $class eq "document" )
    {
        $eprint_id = $dataobj->get_eprint->id;   
    }

    # is there a record of this DOI on DataCite?
    my $datacite_doi = EPrints::DataCite::Utils::datacite_doi_query( $repo, $dataobj_doi );
    if( !defined $datacite_doi )
    {
        $repo->log( "DOI not found on DataCite, no record to update ($class: $dataobj_id, DOI: $dataobj_doi)" );
        return EPrints::Const::HTTP_NOT_FOUND;
    }

    # does this DOI point to us?
    my $datacite_ds = $repo->dataset( "datacite" );
    my $dc = $datacite_ds->dataobj_class->get_datacite_record( $repo, $class, $dataobj_id );
    my $tombstone_url = "";
    $tombstone_url = $dc->get_url if defined $dc;

    my $dataobj_uri = $dataobj->uri;
    if( $repo->can_call( $class."_landing_page" ) ) # landing page url override for documents (or eprints if needed)
    {
        $dataobj_uri = $repo->call( $class."_landing_page", $dataobj, $repo );
    }

    if( ( !defined $datacite_doi->{data}->{attributes}->{url} ) || $datacite_doi->{data}->{attributes}->{url} ne $dataobj_uri && $datacite_doi->{data}->{attributes}->{url} ne $tombstone_url )
    {
        $repo->log( "This DOI does not point to this record so we won't be updating it ($class: $dataobj_id, DOI: $dataobj_doi)" );
        return EPrints::Const::HTTP_NOT_FOUND;
    }

    # if this is a draft doi and we're moving to live... let's mint a new DOI if we can
    if( $datacite_doi->{data}->{attributes}->{state} eq "draft" && $new_status eq "archive" &&
        $repo->can_call( "datacitedoi", "reserve_to_findable" ) && $repo->call( [ "datacitedoi", "reserve_to_findable" ], $dataobj, $repo ) )
    {
        # first validate the dataobj
        my $validate_fn = "validate_datacite_$class";
        my @problems;
        if( $self->{session}->can_call( $validate_fn ) )
        {
            push @problems, $self->{session}->call(
                $validate_fn,
                $dataobj,
                $repo
            );
        }
        if( scalar @problems == 0 )
        {
            # make an event to mint the DOI
            $repo->dataset( "event_queue" )->create_dataobj({
                pluginid => "Event::DataCiteEvent",
                action => "datacite_doi",
                params => [ $dataobj->internal_uri, $dataobj_doi ],
            });
            $repo->log( "DOI minting event called for $class $dataobj_id (DOI: $dataobj_doi)" );
            return EPrints::Const::HTTP_OK;
        }
    
        # we encountered an issue on the way
        $repo->log( "Unable to mint DOI when transferring EPrint $eprint_id to live archive ($class: $dataobj_id, DOI: $dataobj_doi)" );
        return EPrints::Const::HTTP_NOT_FOUND;
    }

    # we already have a DOI in the global handle system so let's udpate it's state as appropriate
    my $user_name = $repo->get_conf( "datacitedoi", "user" );
    my $user_pw = $repo->get_conf( "datacitedoi", "pass" );
    my $datacite_url = URI->new( $repo->config( 'datacitedoi', 'mdsurl' ) . "/metadata/$dataobj_doi" );
    my $ua = LWP::UserAgent->new();
    my $req;

    # if our new status is not live and on datacite we're findable... set as registered
    if( $new_status ne "archive" && $datacite_doi->{data}->{attributes}->{state} eq "findable" )
    {
        # first set a tombstone page for the newly retired item
        apply_tombstone_url( $repo, $class, $dataobj_id ); 

        # set to registered with a DELETE request
        $req = HTTP::Request->new( DELETE => $datacite_url );       
    }

    # if our new status is archive, and we're registered... set as findable
    if( $new_status eq "archive" && $datacite_doi->{data}->{attributes}->{state} eq "registered" )
    {
        # make an event to update the DOI with any changes that have since happened
        $repo->dataset( "event_queue" )->create_dataobj({
            pluginid => "Event::DataCiteEvent",
            action => "datacite_doi",
            params => [ $dataobj->internal_uri, $dataobj_doi ],
        });
        $repo->log( "Trigger event to update DOI URL & metadata for $class $dataobj_id, after EPrint $eprint_id status updated to '$new_status' (DOI: $datoabj_doi)" );
        return EPrints::Const::HTTP_OK;
    }

    # oddly, despite our previous checks, neither of the previous two conditions were true, so nothing happens...
    if( !defined $req )
    {
        $repo->log( "No update applied to DOI (EPrint $eprint_id, Status $new_status, $class: $dataobj_id, DOI: $dataobj_doi)" );
        return EPrints::Const::HTTP_NOT_FOUND;
    }

    $req->authorization_basic( $user_name, $user_pw );
    my $res = $ua->request( $req );
    if( $res->is_success )
    {
        $repo->log( "DOI successfully updated following EPrint $eprint_id status update to '$new_status' ($class: $dataobj_id, DOI: $dataobj_doi)" );
        return EPrints::Const::HTTP_OK;
    }
    else
    {
        $repo->log("DataCite API error following EPrint $eprint_id status update to '$new_status'. Response code: " . $res->code . ", content: " . $res->content );
        return EPrints::Const::HTTP_INTERNAL_SERVER_ERROR;
    }
}

# set a doi as registered rather than findable for a dataobj that has been removed
sub datacite_remove_doi
{
    my( $self, $dataset_id, $dataobj_id, $dataobj_uri, $doi ) = @_;
    
    my $repo = $self->repository;

    # is there a record of this DOI on DataCite?
    my $datacite_doi = EPrints::DataCite::Utils::datacite_doi_query( $repo, $doi );
    if( !defined $datacite_doi )
    {
        $repo->log( "DOI not found on DataCite, no record to update ($dataset_id: $dataobj_id, DOI: $doi)" );
        return EPrints::Const::HTTP_NOT_FOUND;
    }

    if( $datacite_doi->{data}->{attributes}->{url} ne $dataobj_uri )
    {
        $repo->log( "This DOI does not point to this record so we won't be setting a tombstone URL($dataset_id: $dataobj_id, DOI: $doi)" );
        return EPrints::Const::HTTP_NOT_FOUND;
    }

    # if this is a draft or registered doi, there's no point worrying about it
    if( $datacite_doi->{data}->{attributes}->{state} eq "draft" )
    {
        $repo->log( "DOI currently in '" . $datacite_doi->{data}->{attributes}->{state} . "' state. No need to apply any changes following dataobj removal. ($dataset_id: $dataobj_id, DOI: $doi)" );
        return EPrints::Const::HTTP_NOT_FOUND;
    }

    my $user_name = $repo->get_conf( "datacitedoi", "user" );
    my $user_pw = $repo->get_conf( "datacitedoi", "pass" );
    my $datacite_url = URI->new( $repo->config( 'datacitedoi', 'mdsurl' ) . "/metadata/$doi" );
    my $ua = LWP::UserAgent->new();
    my $req;

    # update the DOI with a tombstone url
    apply_tombstone_url( $repo, $dataset_id, $dataobj_id ); 


    # if it's a findable doi in datacite, set as registered
    if( $datacite_doi->{data}->{attributes}->{state} eq "findable" )
    {
        # set to registered with a DELETE request
        $req = HTTP::Request->new( DELETE => $datacite_url );       
    }

    # we shouldn't end up here, but just in case we do...
    if( !defined $req )
    {
        $repo->log( "No update applied to DOI: $doi ($dataset_id: $dataobj_id)" );
        return EPrints::Const::HTTP_INTERNAL_SERVER_ERROR;
    }

    $req->authorization_basic( $user_name, $user_pw );
    my $res = $ua->request( $req );
    if( $res->is_success )
    {
        $repo->log( "DOI successfully updated following removal of record ($dataset_id: $dataobj_id, DOI: $doi)" );   
        return EPrints::Const::HTTP_OK;
    }
    else
    {
        $repo->log("DataCite API error following removal of $dataset_id $dataobj_id. Response code: " . $res->code . ", content: " . $res->content );
        return EPrints::Const::HTTP_INTERNAL_SERVER_ERROR;
    }
}

# update our own json representation of the mandatory fields
sub update_repository_record
{
    my( $repo, $dataobj ) = @_;

    my $class = $dataobj->get_dataset_id;
    my $doi_field = $repo->get_conf( "datacitedoi", $class."doifield" );

    # get the datacite record
    my $datacite_ds = $repo->dataset( "datacite" );
    my $dc = $datacite_ds->dataobj_class->get_datacite_record( $repo, $class, $dataobj->id );
    if( !defined $dc )
    {
        # we need to create a new audit record
        $dc = $datacite_ds->create_dataobj(
            {
                datasetid => $class,
                objectid => $dataobj->id
            }
        );
    }

    # set the doi
    $dc->set_value( "doi", $dataobj->value( $doi_field ) );

    # set the citation
    if( $class eq "eprint" )
    {
        my $citation = EPrints::XML::to_string( $dataobj->render_citation( "datacite_tombstone" ) );
        $dc->set_value( "citation", $citation );
    }
    elsif( $class eq "document" )
    {
        my $eprint = $dataobj->get_eprint;
        my $citation = EPrints::XML::to_string( $dataobj->render_citation( "datacite_tombstone", eprint => $eprint ) );
        $dc->set_value( "citation", $citation );
    }
    $dc->commit;
}

# update DataCite record with tombstone page
sub apply_tombstone_url
{
    my( $repo, $class, $dataobj_id ) = @_;

    # first get the tombstone content from the repository
    my $datacite_ds = $repo->dataset( "datacite" );
    my $dc = $datacite_ds->dataobj_class->get_datacite_record( $repo, $class, $dataobj_id );
 
    if( !defined $dc )
    {
       $repo->log( "Failed to update $class $dataobj_id with a tombstone url. No tombstone page content found." );
       return 0;  
    }

    # get the tombstone url
    my $tombstone_url = $dc->get_url;
    my $doi = $dc->value( "doi" );
 
    # update datacite
    my $success = update_datacite_url( $repo, $doi, $tombstone_url ); 
    if( $success )
    {
        $repo->log( "DOI $doi successfully updated with the following tombstone URL: $tombstone_url" );
    }
    else
    {
        $repo->log( "DOI $doi failed to update with the following tombstone URL: $tombstone_url" );
    }
}

# updates a DOI on DataCite with a new URL
sub update_datacite_url
{
    my( $repo, $doi, $url ) = @_;

    # get credentials
    my $user_name = $repo->get_conf( "datacitedoi", "user" );
    my $user_pw = $repo->get_conf( "datacitedoi", "pass" );

    # build url
    my $datacite_url = URI->new( $repo->config( 'datacitedoi', 'mdsurl' ) . "/doi/$doi" );

    # build the request
    my $headers = HTTP::Headers->new(
        'Content-Type' => 'text/plain;charset=UTF-8'
    );
    my $ua = LWP::UserAgent->new();
    my $req = HTTP::Request->new( 
        PUT => $datacite_url,
        $headers,
        Encode::encode_utf8( "doi=$doi\nurl=$url" )
    );

    # make the request
    $req->authorization_basic( $user_name, $user_pw );
    my $res = $ua->request( $req );
    if( $res->is_success )
    {
        return 1;
    }
    else
    {
        return 0;  
    }
}

# updates a DOI on DataCite with a new URL
sub datacite_updatedoi
{
    my( $self, $dataobj, $doi, $url ) = @_;

    my $repo = $self->repository();
 
    my $res = EPrints::DataCite::Utils::update_metadata( $repo, $dataobj, $doi, $url );
 
    if( $res->is_success )
    {
        # ensure the doi is set
        my $class = $dataobj->get_dataset_id;
        my $doi_field = $repo->get_conf( "datacitedoi", $class."doifield" );
        $dataobj->set_value( $doi_field, $doi );
        $dataobj->commit;

        # we should also store a record of the dataobj's mandatory datacite fields and values
        update_repository_record( $repo, $dataobj );

        if( defined $url )
        {
            $repo->log( "DOI $doi metadata and URL successfully updated" );
            return EPrints::Const::HTTP_OK;
        }
        else
        {
            $repo->log( "DOI $doi metadata successfully updated" );
            return EPrints::Const::HTTP_OK; 
        }
    }
    else
    {
        $repo->log( "Failed to update metadata for DOI $doi" );
        return EPrints::Const::HTTP_INTERNAL_SERVER_ERROR;                           
    }
}

1;
