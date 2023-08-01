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

# identifer this is the DOI and is automatically generated see EPrints::DataCite::Utils::generate_doi

##################################################
# resourceType this is derived from the eprint.type and the datacitedoi->{typemap} in cfg/cfg.d/z_datacite.pl
# https://schema.datacite.org/meta/kernel-4.0/metadata.xsd#resourceType

$c->{datacite_mapping_type} = sub {

    my($xml, $dataobj, $repo) = @_;

    my $resourceTypeGeneral_opts = [ qw/
        Audiovisual
        Book
        BookChapter
        Collection
        ComputationalNotebook
        ConferencePaper
        ConferenceProceeding
        DataPaper
        Dataset
        Dissertation
        Event
        Image
        InteractiveResource
        Journal
        JournalArticle
        Model
        OutputManagementPlan
        PeerReview
        PhysicalObject
        Preprint
        Report
        Service
        Software
        Sound
        Standard
        Text
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
        # Corp creator is a multiple
        foreach my $corp ( @{ $dataobj->get_value( 'corp_creators' ) } ) {
           my $corp_creator = $xml->create_element('creator');
            $corp_creator->appendChild($xml->create_data_element("creatorName", $corp));
            $creators->appendChild($corp_creator);
        }
    }

    return $creators
};

###############################################################
# contributors this is derived from contributors
# https://schema.datacite.org/meta/kernel-4.0/metadata.xsd#creators

$c->{datacite_mapping_contributors} = sub {

    my($xml, $dataobj, $repo) = @_;

    my $contributorType_opts = [ qw/
        ContactPerson
        DataCollector
        DataCurator
        DataManager
        Distributor
        Editor
        HostingInstitution
        Producer
        ProjectLeader
        ProjectManager
        ProjectMember
        RegistrationAgency
        RegistrationAuthority
        RelatedPerson
        Researcher
        ResearchGroup
        RightsHolder
        Sponsor
        Supervisor
        WorkPackageLeader
        Other
    /];

    my $contributors = undef;
    
    if($dataobj->exists_and_set("contributors")){

        $contributors = $xml->create_element("contributors");

        foreach my $c ( @{$dataobj->value("contributors")} )
        {
            my $contributor_type = "Other";
            if( defined $c->{type} )
            {
                $contributor_type = $repo->get_conf( "datacitedoi", "contributormap", $c->{type} );
                unless( grep $contributor_type eq $_, @$contributorType_opts )
                {
                    $contributor_type = "Other"; # LOC types don't line up nicely with DataCite types, so we'll default to Other
                }
            }           

            my $contributor = $xml->create_data_element( "contributor", undef, contributorType => $contributor_type );

            my $name_str = EPrints::Utils::make_name_string($c->{name});
            my $family = $c->{name}->{family};
            my $given = $c->{name}->{given};
            my $orcid = $c->{orcid};

            if ($family eq '' && $given eq '') {
                $contributors->appendChild($contributor);
            } else {
                $contributor->appendChild($xml->create_data_element("contributorName", $name_str));
            }
            if ($given eq '') {
                $contributors->appendChild($contributor);
            } else {
                $contributor->appendChild($xml->create_data_element("givenName", $given));
            }
            if ($family eq '') {
                $contributors->appendChild($contributor);
            } else {
                $contributor->appendChild($xml->create_data_element("familyName", $family));
            }
            $contributors->appendChild($contributor);
        }
    }

    return $contributors;
};


##################################################
# titles this is derived from the eprint.title
# https://schema.datacite.org/meta/kernel-4.0/metadata.xsd#titles

$c->{datacite_eprint_mapping_title} = sub {
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

$c->{datacite_mapping_publication_year} = sub {

    my ( $xml, $dataobj, $repo ) = @_;

    my $publicationYear = undef;
    my $pub_year = undef;
    if( $dataobj->exists_and_set( "date" ) && $dataobj->exists_and_set( "date_type" ) && $repo->call(["datacitedoi", "validate_date_type"], $repo, $dataobj ) )
    {
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



##################################################
# resourceType this is derived from the eprint.type and the datacitedoi->{typemap} in cfg/cfg.d/z_datacite.pl
# https://schema.datacite.org/meta/kernel-4.0/metadata.xsd#resourceType

$c->{datacite_mapping_dates} = sub {

    my($xml, $dataobj, $repo) = @_;

    my $dateType_opts = [ qw/ 
        Accepted
        Available
        Copyrighted
        Collected
        Created
        Issued
        Submitted
        Updated
        Valid
        Withdrawn
        Other
    /];

    my $dates_added = 0;
    my $dates;
    if( $dataobj->exists_and_set( "dates" ) )
    {
        $dates = $xml->create_element( "dates" );
        foreach my $d ( @{$dataobj->value( "dates" )} )
        {
            next unless defined $d->{date_type};
            my $date_type = $repo->get_conf( "datacitedoi", "datemap", $d->{date_type} );
            if( defined $d->{date} && defined $date_type && grep $date_type eq $_, @$dateType_opts )
            {
                my $date= $xml->create_data_element( "date", $d->{date}, dateType => $date_type );
                $dates->appendChild( $date );
                $dates_added++;
            }
        }
    }

    return $dates if( $dates_added > 0 ); # we can only return a dates element if we have successfully added dates to it
    return undef;
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

$c->{datacite_eprint_mapping_abstract} = sub {
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
    my $funders = undef;
    my $projects = undef;

    my $fundingReferences = undef;
    if ($dataobj->exists_and_set("funders")) {
        $funders = $dataobj->get_value("funders");
        my $i=0;
        $fundingReferences = $xml->create_element("fundingReferences");
        foreach my $funderName(@$funders) {
            $fundingReferences->appendChild(my $fundingReference = $xml->create_element("fundingReference"));
            $fundingReference->appendChild($xml->create_data_element("funderName", $funderName));
            if($dataobj->exists_and_set("projects")){
	        $projects = $dataobj->get_value("projects");
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

    if ($dataobj->exists_and_set("funders_advanced")) {
        $funders = $dataobj->get_value("funders_advanced");
        my $i=-1;

        $fundingReferences = $xml->create_element("fundingReferences");
        foreach my $funder(@$funders) {
            $i++;    
            next if !defined $funder->{name};
            $fundingReferences->appendChild(my $fundingReference = $xml->create_element("fundingReference"));
            $fundingReference->appendChild($xml->create_data_element("funderName", $funder->{name}));

            if( defined $funder->{id} )
            {
                $fundingReference->appendChild($xml->create_data_element("funderIdentifier", $funder->{id}, funderIdentifierType=>"Crossref Funder ID"));
            }

            if($dataobj->exists_and_set("projects")){
	        $projects = $dataobj->get_value("projects");
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


    #If we have the funder data in the rioxx2 format. 
    #This will be preferred if present (as should have been derived from the thers anyway
    #TODO keep grant if present?
    if ($dataobj->exists_and_set("rioxx2_project_input")) {
        my $i=0;
        $fundingReferences = $xml->create_element("fundingReferences");
        foreach my $project(@{$dataobj->value("rioxx2_project_input")}) {
            $fundingReferences->appendChild(my $fundingReference = $xml->create_element("fundingReference"));
            $fundingReference->appendChild($xml->create_data_element("funderName", $project->{funder_name}));
            $fundingReference->appendChild($xml->create_data_element("awardTitle", $project->{project}));
            $fundingReference->appendChild($xml->create_data_element("funderIdentifier", $project->{funder_id}, funderIdentifierType=>"Crossref Funder ID"));
        }
    } 

    return $fundingReferences;
};

# TODO sort this one out too

$c->{datacite_mapping_rights_from_docs} = sub {
    my ( $xml, $dataobj, $repo ) = @_;
    
    my $rightsList = undef;
    my $previous = {};
    my $attached_licence = undef;

    my $seen = {};

    for my $doc ( $dataobj->get_all_documents() ) {

    my $license = $doc->get_value("license");
    my $content = $doc->get_value("content");
	my ($license_uri,$license_phrase);
    	# This doc is the license (for docs that have license == attached
	if ((defined $content) && ($content eq "licence")){
        	$license_uri = $doc->uri;
		$license_phrase = $repo->phrase("licenses_typename_attached");
	}elsif(defined $license){
	        $license_uri = $repo->phrase("licenses_uri_$license");
        	$license_phrase = $repo->phrase("licenses_typename_$license");
	}else{ #do not attempt to add rights tag if no license is set for a file
        next;
    }
	#no dupes
	next if $seen->{$license_uri};

        if($doc->exists_and_set("date_embargo")){
		$license_phrase .= $repo->phrase("embargoed_until", embargo_date=>$doc->value("date_embargo"));
        }
	$seen->{$license_uri} = 1;
        $rightsList = $xml->create_element("rightsList") if !defined $rightsList;

        $rightsList->appendChild($xml->create_data_element("rights", $license_phrase, rightsURI => $license_uri));
    }


    return $rightsList;
};


##################################################
# relatedIdentifier relates eprints to previous versions, or - if available - to eprints
# in another repository
# https://schema.datacite.org/meta/kernel-4.3/doc/DataCite-MetadataKernel_v4.3.pdf

$c->{datacite_eprint_mapping_relatedIdentifiers} = sub {

    my( $xml, $dataobj, $repo ) = @_;

    my $relatedIdentifiers = undef;

    # we're only concerned with eprint objects here
    my $class = $dataobj->get_dataset_id;
    return unless $class eq "eprint";

    # get dataset and relevant field
    my $ds = $dataobj->dataset;
    my $doi_field = $repo->get_conf( "datacitedoi", "eprintdoifield" );

    # are we a later version of something
    if( $dataobj->is_set( "succeeds" ) )
    {
        # relation type
        my $relationType = "IsVersionOf";
 
        # get our parent      
        my $parent = $ds->dataobj( $dataobj->value( "succeeds" ) );
        
        if( defined $parent ) # check out parent still exists (it may have since been retired)
        {
            my $relatedIdentifier = EPrints::DataCite::Utils::create_related_identifier( $repo, $xml, $parent, $relationType );
            if( defined $relatedIdentifier )
            {
                $relatedIdentifiers = $xml->create_element( "relatedIdentifiers" ) if (!defined $relatedIdentifiers);
                $relatedIdentifiers->appendChild( $relatedIdentifier );
            }
        }
    }
    
    # are we an early version of something
    my $succeeds = $ds->field( "succeeds" );
    my $children =  $dataobj->later_in_thread( $succeeds );
    if( $children->count > 0 )
    {   
        $children->map(sub
        {
            my( undef, undef, $child ) = @_;
          
            # relation type
            my $relationType = "HasVersion";

            my $relatedIdentifier = EPrints::DataCite::Utils::create_related_identifier( $repo, $xml, $child, $relationType );
            if( defined $relatedIdentifier )
            {
                $relatedIdentifiers = $xml->create_element( "relatedIdentifiers" ) if (!defined $relatedIdentifiers);
                $relatedIdentifiers->appendChild( $relatedIdentifier );
            }
        });
    }
    
    # RepoLink
    #default codein plugin (for reference)
    #    my $theurls = $dataobj->get_value( "repo_link" );
    #    my $relatedIdentifiers = $xml->create_element( "relatedIdentifiers" ) if (!defined $relatedIdentifiers);
    #    foreach my $theurl ( @$theurls ) {
    #        my $linkk = $theurl->{link};
    #        if (!$linkk eq ''){
    #            $relatedIdentifiers->appendChild(  $xml->create_data_element( "relatedIdentifier", $linkk, relatedIdentifierType=>"URL", relationType=>"IsReferencedBy" ) );
    #        }
    #    }


    return $relatedIdentifiers;

};

##################################################
# titles this is derived from the eprint.title
# https://schema.datacite.org/meta/kernel-4.0/metadata.xsd#titles

$c->{datacite_document_mapping_title} = sub {
    my( $xml, $dataobj, $eprint, $repo ) = @_;
    my $titles = undef;
    if( $eprint->exists_and_set( "title" ) )
    {
        my $title = $eprint->value( "title" );

        # append content if available
        if( $dataobj->exists_and_set( "content" ) )
        {
            $title .= " (" . $dataobj->value( "content" ) . ")";
        }

        $titles = $xml->create_element( "titles" );
        $titles->appendChild( $xml->create_data_element( "title", $title, 
                "xml:lang" => $repo->get_language->get_id ) );
    }
    return $titles
};


##################################################
# language this is derived from the document language field 
# https://schema.datacite.org/meta/kernel-4.3/doc/DataCite-MetadataKernel_v4.3.pdf

$c->{datacite_document_mapping_language} = sub {

    my( $xml, $dataobj, $eprint, $repo ) = @_;

    my $language = undef;
    if( $dataobj->exists_and_set( "language" ) )
    {
        $language = $xml->create_data_element( "language", $dataobj->value( "language" ) );   
    }
    
    return $language;
};

##################################################
# relatedIdentifier for documents relates it to the parent eprint 
# https://schema.datacite.org/meta/kernel-4.3/doc/DataCite-MetadataKernel_v4.3.pdf

$c->{datacite_document_mapping_relatedIdentifiers} = sub {

    my( $xml, $dataobj, $eprint, $repo ) = @_;

    my $relatedIdentifiers = undef;

    if( defined $eprint )
    {   
        $relatedIdentifiers = $xml->create_element( "relatedIdentifiers" );
        $relatedIdentifiers->appendChild( $xml->create_data_element( "relatedIdentifier", $eprint->uri, relatedIdentifierType => "URL", relationType => "HasMetadata" ) );   
    }
    
    return $relatedIdentifiers;
};

##################################################
# size of document
# https://schema.datacite.org/meta/kernel-4.3/doc/DataCite-MetadataKernel_v4.3.pdf

$c->{datacite_document_mapping_size} = sub {

    my( $xml, $dataobj, $eprint, $repo ) = @_;

    my $sizes = undef;

    if( $dataobj->is_set( "main" ) )
    {   
        $sizes = $xml->create_element( "sizes" );
        my $size = $sizes->appendChild( $xml->create_element( "size" ) );

        my %files = $dataobj->files;       
        
        $size->appendChild( $repo->make_text( EPrints::Utils::human_filesize( $files{$dataobj->get_main} ) ) );   
    }
    
    return $sizes;
};

##################################################
# format of document, i.e. mime_type
# https://schema.datacite.org/meta/kernel-4.3/doc/DataCite-MetadataKernel_v4.3.pdf

$c->{datacite_document_mapping_format} = sub {

    my( $xml, $dataobj, $eprint, $repo ) = @_;

    my $formats = undef;

    if( $dataobj->is_set( "mime_type" ) )
    {   
        $formats = $xml->create_element( "formats" );
        my $format = $formats->appendChild( $xml->create_element( "format" ) );      
        $format->appendChild( $dataobj->render_value( "mime_type" ) );   
    }
    
    return $formats;
};

##################################################
# document description, i.e. the version of the document
# https://schema.datacite.org/meta/kernel-4.3/doc/DataCite-MetadataKernel_v4.3.pdf

$c->{datacite_document_mapping_descriptions} = sub {

    my( $xml, $dataobj, $eprint, $repo ) = @_;

    my $descriptions = undef;

    # first get the eprint description content
    $descriptions = $repo->call( "datacite_eprint_mapping_abstract", $xml, $eprint, $repo );

    if( $dataobj->is_set( "content" ) )
    {   
        $descriptions = $xml->create_element( "descriptions" ) unless defined $descriptions;
        $descriptions->appendChild( $xml->create_data_element( "description", $dataobj->render_value( "content" ),
            "xml:lang"=>$repo->get_language->get_id, 
            descriptionType =>"Other" ) );
    }
    
    return $descriptions;
};


$c->{validate_datacite_eprint} = sub
{
	my( $eprint, $repository ) = @_;

	my $xml = $repository->xml();

	my @problems = ();

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
    #we will accept the publisher set in config... as long as it has been set to something other than the default
	if( !$eprint->is_set( "publisher" ) && (!EPrints::Utils::is_set($repository->get_conf("datacitedoi","publisher")) ||
        $repository->get_conf("datacitedoi","publisher") eq "EPrints Repo" ) )
	{
		my $publisher = $xml->create_element( "span", class=>"ep_problem_field:publisher" );
        my $default_publisher = $repository->make_text( $repository->get_conf("datacitedoi","publisher") );
		push @problems, $repository->html_phrase( 
				"datacite_validate:need_publisher",
				publisher=>$publisher,
                default_publisher => $default_publisher);
	}

    my $no_pub_year = 1;
    if( $eprint->exists_and_set( "date" ) && $eprint->exists_and_set( "date_type" ) && $repository->call(["datacitedoi", "validate_date_type"], $repository, $eprint ) )
    {            
        $no_pub_year = 0;
    }

    for my $doc ( $eprint->get_all_documents() )
    {
        if($doc->exists_and_set("date_embargo"))
        {
            $no_pub_year = 0;
        }
    }

    if( $no_pub_year )
    {
		my $dates = $xml->create_element( "span", class=>"ep_problem_field:dates" );
		push @problems, $repository->html_phrase( 
	        "datacite_validate:need_published_year",
		    dates=>$dates
        );
	}

	# If we don't have a type or its not in our mapping, thats bad
	if ( !$eprint->exists_and_set("type") || !$repository->get_conf("datacitedoi", "typemap", $eprint->value("type")))
	{
		my $types = $xml->create_element( "span", class=>"ep_problem_field:type" );

		push @problems, $repository->html_phrase(
				"datacite_validate:need_mapped_type",
				types=>$types );
	}

	return( @problems );
};

$c->{validate_datacite_document} = sub
{
	my( $document, $repository ) = @_;

    # some (most, all?) of our properties are still going to come from the eprint object
    my $eprint = $document->get_eprint;

	my $xml = $repository->xml();

	my @problems = ();

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
    #we will accept the publisher set in config... as long as it has been set to something other than the default
	if( !$eprint->is_set( "publisher" ) && (!EPrints::Utils::is_set($repository->get_conf("datacitedoi","publisher")) ||
        $repository->get_conf("datacitedoi","publisher") eq "EPrints Repo" ) )
	{
		my $publisher = $xml->create_element( "span", class=>"ep_problem_field:publisher" );
        my $default_publisher = $repository->make_text( $repository->get_conf("datacitedoi","publisher") );
		push @problems, $repository->html_phrase( 
				"datacite_validate:need_publisher",
				publisher=>$publisher,
                default_publisher => $default_publisher);
	}
 
    my $no_pub_year = 1;
    if( $eprint->exists_and_set( "date" ) && $eprint->exists_and_set( "date_type" ) && $eprint->value( "date_type" ) eq "published" )
    {            
        $no_pub_year = 0;
    }

    for my $doc ( $eprint->get_all_documents() )
    {
        if($doc->exists_and_set("date_embargo"))
        {
            $no_pub_year = 0;
        }
    }

    if( $no_pub_year )
    {
		my $dates = $xml->create_element( "span", class=>"ep_problem_field:dates" );
		push @problems, $repository->html_phrase( 
	        "datacite_validate:need_published_year",
		    dates=>$dates
        );
	}

	# If we don't have a type or its not in our mapping, thats bad
	if ( !$eprint->exists_and_set("type") || !$repository->get_conf("datacitedoi", "typemap", $eprint->value("type")))
	{
		my $types = $xml->create_element( "span", class=>"ep_problem_field:type" );

		push @problems, $repository->html_phrase(
				"datacite_validate:need_mapped_type",
				types=>$types );
	}

	return( @problems );
};

$c->{datacitedoi}->{validate_date_type} = sub {

    my( $repo, $eprint ) = @_;

    return 1 if $eprint->value( "date_type" ) eq "published";
    return 1 if $eprint->value( "date_type" ) eq "published_online";

    # if this is a thesis, we might not have a published date
    # but an awarded or completed date will do in most cases

    my $thesis_date_types = $repo->get_conf( "datacitedoi", "thesis_date_types" );
    if( defined $thesis_date_types )
    {
        if( $eprint->value( "type" ) eq "thesis" && 
            ( grep $eprint->value( "date_type")  eq $_, @$thesis_date_types ) ) 
        {
            return 1; # we have date type acceptable for a thesis
        }
    }

    return 0;
};
