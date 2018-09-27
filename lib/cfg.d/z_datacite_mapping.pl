#####################################################
# New architecture
# for Eprint => datacite mapping
#####################################################

####################################
# Mandatory fields for Datacite 4.0
# - identifier
# - resourceType
# - creators
# - titles
# - publisher
# - publicationYear
# #################################

# identifer this is the DOI and is automatically generated see EPrints::Plugin::Event::DataCiteEvent::coin_doi

##################################################
# resourceType this is derived from the eprint.type and the datacitedoi->{typemap} in cfg/cfg.d/z_datacite.pl
# https://schema.datacite.org/meta/kernel-4.0/metadata.xsd#resourceType

$c->{datacite_mapping_type} = sub {

    my($xml, $dataobj, $repo) = @_;

    my $resourceTypeGeneral_opts = [ qw/ 
        Audiovisual
        Collection
        Dataset
        Event
        Image
        InteractiveResource
        Model
        PhysicalObject
        Service
        Software
        Sound
        Text15
        Workflow
        Other
    /];

    my $resourceType = undef;
    if($dataobj->exists_and_set("type")){
        my $pub_resourceType = $repo->get_conf("datacitedoi", "typemap", $dataobj->value("type"));
        if (defined $pub_resourceType) {
                if(grep $pub_resourceType->{'a'} eq $_, @$resourceTypeGeneral_opts){
                    $resourceType = $xml->create_data_element("resourceType", $pub_resourceType->{'v'}, 
                        resourceTypeGeneral=>$pub_resourceType->{'a'});
                }
        }
    }
    # We have the recollect plugin in play, so let's use the data_type if set
    if(defined $repo->get_conf("recollect") && $dataobj->exists_and_set("data_type")){
        if(grep $dataobj->value("data_type") eq $_, @$resourceTypeGeneral_opts){
                $resourceType = $xml->create_data_element("resourceType", "Dataset", 
                    resourceTypeGeneral=>$dataobj->value("data_type"));
        }
    }
    return $resourceType;
};

###############################################################
# creators this is derived from creators and/or corp_creators
# https://schema.datacite.org/meta/kernel-4.0/metadata.xsd#creators

$c->{datacite_mapping_creators} = sub {

    my($xml, $dataobj, $repo) = @_;

    my $creators = undef;
    
    if($dataobj->exists_and_set("creators")){

        $creators = $xml->create_element("creators");

        foreach my $name(@{$dataobj->value("creators")}) {
            my $author = $xml->create_element("creator");

            my $name_str = EPrints::Utils::make_name_string($name->{name});

            my $family = $name->{name}->{family};
            my $given = $name->{name}->{given};
            my $orcid = $name->{orcid};

            if ($family eq '' && $given eq '') {
                $creators->appendChild($author);
            } else {
                $author->appendChild($xml->create_data_element("creatorName", $name_str));
            }
            if ($given eq '') {
                $creators->appendChild($author);
            } else {
                $author->appendChild($xml->create_data_element("givenName", $given));
            }
            if ($family eq '') {
                $creators->appendChild($author);
            } else {
                $author->appendChild($xml->create_data_element("familyName", $family));
            }
            if ($dataobj->exists_and_set("creators_orcid")) {

                if ($orcid eq '') {
                    $creators->appendChild($author);
                } else {
                    $author->appendChild($xml->create_data_element("nameIdentifier", $orcid, 
                            schemeURI =>"http://orcid.org/", 
                            nameIdentifierScheme=>"ORCID"));
                }
            }

            $creators->appendChild($author);
        }
    }
    if($dataobj->exists_and_set("corp_creators")){

        $creators = $xml->create_element("creators") if (!defined $creators);
        $creators->appendChild(my $creator = $xml->create_element("creator"));
        $creator->appendChild($xml->create_data_element("creatorName", $dataobj->value("corp_creators")));

    }
    return $creators
};

##################################################
# titles this is derived from the eprint.title
# https://schema.datacite.org/meta/kernel-4.0/metadata.xsd#titles

$c->{datacite_mapping_title} = sub {
    my($xml, $dataobj, $repo) = @_;

    my $titles = undef;
    if($dataobj->exists_and_set("title")){
        $titles = $xml->create_element("titles");
        $titles->appendChild($xml->create_data_element("title", $dataobj->render_value("title"), 
                "xml:lang"=>$repo->get_language->get_id));
    }
    return $titles
};

#####################################################
# publisher this is derived from the eprint.publisher
# https://schema.datacite.org/meta/kernel-4.0/metadata.xsd#publisher

$c->{datacite_mapping_publisher} = sub {

    my($xml, $dataobj, $repo) = @_;

    my $publisher = $repo->get_conf("datacitedoi","publisher");
    if($dataobj->exists_and_set("publisher")){
        $publisher = $dataobj->render_value("publisher");
    }
    return $xml->create_data_element("publisher", $publisher);

};

##################################################
# publicationYear this is derived from the eprint.date (this will have the pub date if datesdatesdates is in play)
# https://schema.datacite.org/meta/kernel-4.0/metadata.xsd#publicationYear
# Year when the data is made publicly available. 
# If an embargo period has been in effect, use the date when the embargo period ends.


$c->{datacite_mapping_date} = sub {

    my ( $xml, $dataobj, $repo ) = @_;

    my $publicationYear = undef;
    my $pub_year = undef;
    if($dataobj->exists_and_set("date") && $dataobj->value("date_type") eq "published"){
        $dataobj->get_value( "date" ) =~ /^([0-9]{4})/;
        $pub_year = $1;
    }
     
    for my $doc ( $dataobj->get_all_documents() ) {
        if($doc->exists_and_set("date_embargo")){
            $doc->get_value( "date_embargo" ) =~ /^([0-9]{4})/;
            $pub_year = $1 if $1 > $pub_year; #highest available pub_year value
        }
    }

    $publicationYear = $xml->create_data_element( "publicationYear", $pub_year ) if defined $pub_year;

    return $publicationYear;
};

#################################################################
# descriptions this is derived from the eprint.abstract
# If recollect is in place from eprint.collection_method, eprint.provenance too
# https://schema.datacite.org/meta/kernel-4.0/metadata.xsd#descriptions

#####################
# descriptionTypes:
#
# Abstract
# Methods
# SeriesInformation
# TableOfContents
# TechnicalInfo
# Other
#
#####################

$c->{datacite_mapping_abstract} = sub {
    my($xml, $dataobj, $repo) = @_;

    my $descriptions = undef;
    
    if($dataobj->exists_and_set("abstract")){

        $descriptions = $xml->create_element("descriptions");
        $descriptions->appendChild($xml->create_data_element("description", $dataobj->get_value("abstract"), 
                "xml:lang"=>$repo->get_language->get_id, 
                descriptionType=>"Abstract"));
    }

    if ($dataobj->exists_and_set("collection_method")) {
        $descriptions = $xml->create_element("descriptions") if(!defined $descriptions);
        $descriptions->appendChild($xml->create_data_element("description", $dataobj->get_value("collection_method"),
                "xml:lang"=>$repo->get_language->get_id, 
                descriptionType =>"Methods"));
    }

    if ($dataobj->exists_and_set("provenance")) {
        $descriptions = $xml->create_element("descriptions") if(!defined $descriptions);
        $descriptions->appendChild($xml->create_data_element("description", $dataobj->get_value("provenance"),
                "xml:lang"=>$repo->get_language->get_id, 
                descriptionType =>"TechnicalInfo"));
    }

    return $descriptions;
};

#################################################################
# subjects this is derived from the eprint.keywords
# https://schema.datacite.org/meta/kernel-4.0/metadata.xsd#subjects

$c->{datacite_mapping_keywords} = sub {
    my($xml, $dataobj, $repo) = @_;

    my $subjects = undef; 
    if ($dataobj->exists_and_set("keywords")) {
        my $subjects = $xml->create_element("subjects");
        my $keywords = $dataobj->get_value("keywords");
        # keyswords as a multiple field
        if (ref($keywords) eq "ARRAY") {
            foreach my $keyword(@$keywords) {
                $subjects->appendChild($xml->create_data_element("subject", $keyword,
                        "xml:lang"=>$repo->get_language->get_id));
            }
        #or a block of text
        }else{
            $subjects->appendChild($xml->create_data_element("subject", $keywords,
                    "xml:lang"=>$repo->get_language->get_id));
        }
    }
    return $subjects
};

#################################################################
# geoLocations this is derived from the eprint.geographic_cover 
# and/or eprint.bounding_box (requires recollect)
# https://schema.datacite.org/meta/kernel-4.0/metadata.xsd#subjects

$c->{datacite_mapping_geographic_cover} = sub {
    my($xml, $dataobj, $repo) = @_;

    my $geo_locations = undef;

    if ($dataobj->exists_and_set("geographic_cover")) {
        $geo_locations = $xml->create_element("geoLocations");
        $geo_locations->appendChild(my $geo_location = $xml->create_element("geoLocation"));

        # Get value of geographic_cover field and append to $geo_location XML element
        my $geographic_cover = $dataobj->get_value("geographic_cover");
        $geo_location->appendChild($xml->create_data_element("geoLocationPlace", $geographic_cover));

    }

    if($dataobj->exists_and_set("bounding_box")){
        if(!defined $geo_locations){
            $geo_locations = $xml->create_element("geoLocations");
            $geo_locations->appendChild(my $geo_location = $xml->create_element("geoLocation"));
        }

        # Get values of bounding box
        my $west = $dataobj->get_value("bounding_box_west_edge");
        my $east = $dataobj->get_value("bounding_box_east_edge");
        my $south = $dataobj->get_value("bounding_box_south_edge");
        my $north = $dataobj->get_value("bounding_box_north_edge");

        # Check to see
        # if $north, $south, $east, and $west values are defined
        if (defined $north && defined $south && defined $east && defined $west) {
            #Created $geo_location_box XML element
            my $geo_location_box = $xml->create_element("geoLocationBox");
            #If $long / lat is defined, created XML element with the appropriate value
            $geo_location_box->appendChild($xml->create_data_element("westBoundLongitude", $west));
            $geo_location_box->appendChild($xml->create_data_element("eastBoundLongitude", $east));
            $geo_location_box->appendChild($xml->create_data_element("southBoundLatitude", $south));
            $geo_location_box->appendChild($xml->create_data_element("northBoundLatitude", $north));
            #Append child $geo_location_box XML element to parent $geo_location XML element
            if(!defined $geo_locations){
                $geo_locations = $xml->create_element("geoLocations");
            }
            $geo_locations->appendChild(my $geo_location = $xml->create_element("geoLocation"));
            $geo_location->appendChild($geo_location_box);
        }
    }

    return $geo_locations;
};

#################################################################
# fundingReferences this is derived from the eprint.funders and eprint.projects
# Possibly also eprint.grant (recollect) or a compound eprint.project (rioxx2)
# https://schema.datacite.org/meta/kernel-4.0/metadata.xsd#fundingReferences

$c->{datacite_mapping_funders} = sub {
    my($xml, $dataobj, $repo) = @_;

    ##############################
    # If at all possible we do this:
    #
    # funders => funderName [mandatory]
    # projects => awardTitle
    # grant -> awardNumber
    # funder_id => funderIdentifier

    #Funders and projects are default eprints field, both are multiple
    my $funders = $dataobj->get_value("funders");
    my $projects = $dataobj->get_value("projects");

    my $fundingReferences = undef;
    if ($dataobj->exists_and_set("funders")) {
        my $i=0;
        $fundingReferences = $xml->create_element("fundingReferences");
        foreach my $funderName(@$funders) {
            $fundingReferences->appendChild(my $fundingReference = $xml->create_element("fundingReference"));
            $fundingReference->appendChild($xml->create_data_element("funderName", $funderName));
            if($dataobj->exists_and_set("projects")){
                if(ref($projects) =~ /ARRAY/) {
                    my $project = $projects->[scalar(@$projects)-1];
                    if(defined $projects->[$i]){
                        $project = $projects->[$i];
                    }
                    $fundingReference->appendChild($xml->create_data_element("awardTitle", $project));
                }else{
                    $fundingReference->appendChild($xml->create_data_element("awardTitle", $projects));
                }
            }

            #grants is added by recollect if present
            if($dataobj->exists_and_set("grant")) {
                my $grants = $dataobj->get_value("grant");
                #Just in case it has been configured as multiple
                if(ref($grants) =~ /ARRAY/) {
                    my $grant = $grants->[scalar(@$grants)-1];
                    if(defined $grants->[$i]){
                        $grant = $grants->[$i];
                    }
                    $fundingReference->appendChild($xml->create_data_element("awardNumber", $grant));
                }else{
                    $fundingReference->appendChild($xml->create_data_element("awardNumber", $grants));
                }
            }
        }
    } 

    #If we have the funder data in the ioxx2 format. 
    #This will be preferred if present (as should have been derived from the thers anyway
    #TODO keep grant if present?
    if ($dataobj->exists_and_set("rioxx2_project_input")) {
        my $i=0;
        $fundingReferences = $xml->create_element("fundingReferences");
        foreach my $project(@{$dataobj->value("rioxx2_project_input")}) {
            $fundingReferences->appendChild(my $fundingReference = $xml->create_element("fundingReference"));
            $fundingReference->appendChild($xml->create_data_element("funderName", $project->{funder_name}));
            $fundingReference->appendChild($xml->create_data_element("awardTitle", $project->{project}));
            $fundingReference->appendChild($xml->create_data_element("funderId", $project->{funder_id}));
        }
    } 

    return $fundingReferences;
};

# TODO sort this one out too

$c->{datacite_mapping_rights_from_docs} = sub {
    my ( $xml, $dataobj, $repo ) = @_;
    
    my $rightsList   = $xml->create_element("rightsList");
    my $previous = {};
    my $attached_licence = undef;

    for my $doc ( $dataobj->get_all_documents() ) {

        my $license = $doc->get_value("license");
        my $content = $doc->get_value("content");

	    # This doc is the license (for docs that have license == attached
	    if($content eq "licence"){
		    $attached_licence = $doc->url;
		    next;
	    }

        if(EPrints::Utils::is_set($license) && $license ne "attached") {

                    my $licenseuri = $repo->phrase("licenses_uri_$license");
                    my $licensephrase = $repo->phrase("licenses_typename_$license");

                    if($doc->exists_and_set("date_embargo")){
                            $licensephrase .= $repo->phrase("embargoed_until", embargo_date=>$doc->value("date_embargo"));
                    }

                    $rightsList->appendChild($xml->create_data_element("rights", $licensephrase, rightsURI => $licenseuri));

        }
    }
    
    #second pass now that we know what the attached license doc ur is
    for my $doc ( $dataobj->get_all_documents() ) {
        my $license = $doc->get_value("license");
    	if(EPrints::Utils::is_set($license) && $license eq "attached") {
        	$rightsList->appendChild($xml->create_data_element("rights", $repo->phrase("licenses_typename_attached"), rightsURI => $attached_licence));

	    }
    }

    return $rightsList;
};






$c->{datacite_mapping_repo_link} = sub {

    my($xml, $entry, $dataobj) = @_;

    my $relatedIdentifiers = undef;
    #default codein plugin (for reference)
    #    my $theurls = $dataobj->get_value( "repo_link" );
    #    my $relatedIdentifiers = $xml->create_element( "relatedIdentifiers" );
    #    foreach my $theurl ( @$theurls ) {
    #        my $linkk = $theurl->{link};
    #        if (!$linkk eq ''){
    #            $relatedIdentifiers->appendChild(  $xml->create_data_element( "relatedIdentifier", $linkk, relatedIdentifierType=>"URL", relationType=>"IsReferencedBy" ) );
    #        }
    #    }


    return $relatedIdentifiers;

};


$c->{validate_datacite} = sub
{
	my( $eprint, $repository ) = @_;

	my $xml = $repository->xml();

	my @problems = ();

	# If this host is not production it should probably use a test endpoint.
	# To prevent this check change the test_host_regex regex not to match hostname
	# or ensure test_host_regex is undefined (as is the default)

	my $test_regex = $repository->get_conf("datacitedoi", "test_host_regex");
	if (defined $test_regex){
		use Sys::Hostname;
		my $doi_prefix = $repository->get_conf("datacitedoi", "prefix");

		# Does this host match the regex? Is it using the test DOI prefix?
		if ((hostname =~ $test_regex) && ("10.5072" != $doi_prefix)) {
			push @problems, $repository->html_phrase(
				"datacite_validate:doi_prefix_mismatch",
				match_regexp=> $xml->create_text_node("$test_regex"),
				configured_doi_prefix=> $xml->create_text_node("$doi_prefix"),
			);
		}
	}

    #NEED CREATORS
	if( !$eprint->is_set( "creators" ) && 
		!$eprint->is_set( "corp_creators" ) )
	{
		my $creators = $xml->create_element( "span", class=>"ep_problem_field:creators" );
		my $corp_creators = $xml->create_element( "span", class=>"ep_problem_field:corp_creators" );

		push @problems, $repository->html_phrase( 
				"datacite_validate:need_creators_or_corp_creators",
				creators=>$creators,
				corp_creators=>$corp_creators );
	}

    #NEED TITLE
	if( !$eprint->is_set( "title" ) )
	{
		my $title = $xml->create_element( "span", class=>"ep_problem_field:title" );

		push @problems, $repository->html_phrase( 
				"datacite_validate:need_title",
				title=>$title );
	}

	if( !$eprint->is_set( "publisher" ) )
	{
		my $publisher = $xml->create_element( "span", class=>"ep_problem_field:publisher" );
        my $default_publisher = $repository->make_text( $repository->get_conf("datacitedoi","publisher") );
		push @problems, $repository->html_phrase( 
				"datacite_validate:need_publisher",
				publisher=>$publisher,
                default_publisher => $default_publisher);
	}

	if( !$eprint->is_set( "date" ) && (!$eprint->is_set( "date_type" ) || $eprint->value( "date_type" ) eq "published") )
	{
		my $dates = $xml->create_element( "span", class=>"ep_problem_field:dates" );

		push @problems, $repository->html_phrase( 
				"datacite_validate:need_published_year",
				dates=>$dates );
	}

	return( @problems );
};

