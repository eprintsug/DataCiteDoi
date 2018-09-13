#####################################################
# New architecture
# for print => datacite mapping
####################################################

# These first two both map to resourceType (and resourceTypeGeneral). The first
# is for pubs repos the second for data (but either can be used for either if
# the eprint field is there).
$c->{datacite_mapping_type} = sub {

    my($xml, $dataobj, $repo, $value) = @_;

    my $pub_resourceType = $repo->get_conf("datacitedoi", "typemap", $value);
    if (defined $pub_resourceType) {
        return $xml->create_data_element("resourceType", $pub_resourceType->{'v'}, resourceTypeGeneral=>$pub_resourceType->{'a'});
    }

    return undef;
};

$c->{datacite_mapping_data_type} = sub {

    my($xml, $dataobj, $repo, $value) = @_;

    return $xml->create_data_element("resourceType", $value, resourceTypeGeneral=>$value);
};

$c->{datacite_mapping_creators} = sub {

    my($xml, $dataobj, $repo, $value) = @_;

    my $creators = $xml->create_element("creators");

    foreach my $name(@$value) {
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
                $author->appendChild($xml->create_data_element("nameIdentifier", $orcid, schemeURI =>"http://orcid.org/", nameIdentifierScheme=>"ORCID"));
            }
        }

        $creators->appendChild($author);
    }
    return $creators
};


$c->{datacite_mapping_title} = sub {
    my($xml, $dataobj, $repo, $value) = @_;



        my $titles = $xml->create_element("titles");
        $titles->appendChild($xml->create_data_element("title", $dataobj->render_value("title"), "xml:lang"=>"en-us"));






    return $titles	# of some description
};


$c->{datacite_mapping_publisher} = sub {
    my($xml, $dataobj, $repo, $value) = @_;

return $xml->create_data_element("publisher", $dataobj->render_value("publisher"));

};



$c->{datacite_mapping_abstract} = sub {
    my($xml, $dataobj, $repo, $value) = @_;

    my $abstract = $dataobj->get_value("abstract");
    my $description = $xml->create_element("descriptions");

    $description->appendChild($xml->create_data_element("description", $abstract, "xml:lang"=>"en-us", descriptionType=>"Abstract"));

    if ($dataobj->exists_and_set("collection_method")) {
        my $collection = $dataobj->get_value("collection_method");
        $description->appendChild($xml->create_data_element("description", $collection, descriptionType =>"Methods"));
    }

    if ($dataobj->exists_and_set("provenance")) {
        my $processing = $dataobj->get_value("provenance");
        $description->appendChild($xml->create_data_element("description", $processing, descriptionType =>"Methods"));
    }




    return $description# of somedescription
};






$c->{datacite_mapping_date} = sub {
	my ( $xml, $dataobj, $repo, $value ) = @_;
  $dataobj->get_value( "date" ) =~ /^([0-9]{4})/;
  return $xml->create_data_element( "publicationYear", $1 ) if $1;

};


$c->{datacite_mapping_keywords} = sub {
    my($xml, $dataobj, $repo, $value) = @_;

    if ($dataobj->exists_and_set("keywords")) {
        my $subjects = $xml->create_element("subjects");
        my $keywords = $dataobj->get_value("keywords");
        if (ref($keywords) eq "ARRAY") {
            foreach my $keyword(@$keywords) {
                $subjects->appendChild($xml->create_data_element("subject", $keyword, "xml:lang"=>"en-us"));
            }
            return $subjects

        } else {
            $subjects->appendChild($xml->create_data_element("subject", $keywords, "xml:lang"=>"en-us"));
            return $subjects
        }
    }
};

$c->{datacite_mapping_geographic_cover} = sub {
    my($xml, $dataobj, $repo, $value) = @_;

    my $geo_locations = $xml->create_element("geoLocations");
    my $geo_location = $xml->create_element("geoLocation");
    if ($dataobj->exists_and_set("geographic_cover")) {

        #
        #Create XML elements

        # Get value of geographic_cover field and append to $geo_location XML element
        my $geographic_cover = $dataobj->get_value("geographic_cover");
        $geo_location->appendChild($xml->create_data_element("geoLocationPlace", $geographic_cover));

        #
        # Get values of bounding box
        my $west = $dataobj->get_value("bounding_box_west_edge");
        my $east = $dataobj->get_value("bounding_box_east_edge");
        my $south = $dataobj->get_value("bounding_box_south_edge");
        my $north = $dataobj->get_value("bounding_box_north_edge");

        #
        # Check to see
        # if $north, $south, $east, or $west values are defined
        if (defined $north && defined $south && defined $east && defined $west) {#
            #Created $geo_location_box XML element
            my $geo_location_box = $xml->create_element("geoLocationBox");#
            #If $long / lat is defined, created XML element with the appropriate value
            $geo_location_box->appendChild($xml->create_data_element("westBoundLongitude", $west));
            $geo_location_box->appendChild($xml->create_data_element("eastBoundLongitude", $east));
            $geo_location_box->appendChild($xml->create_data_element("southBoundLatitude", $south));
            $geo_location_box->appendChild($xml->create_data_element("northBoundLatitude", $north));#
            #Append child $geo_location_box XML element to parent $geo_location XML element
            $geo_location->appendChild($geo_location_box);
        }
        #Append child $geo_location XML element to parent $geo_locations XML element
        $geo_locations->appendChild($geo_location);
        #Append $geo_locations XML element to XML document# $entry - > appendChild($geo_locations);
    }

    return $geo_locations;
};

$c->{datacite_mapping_funders} = sub {
    my($xml, $dataobj, $repo, $value) = @_;


    #
    # if ($repo - >can_call("datacite_custom_funder")) {#
    #     return $repo - > call("datacite_custom_funder", $xml, $dataobj);#
    # }

    my $funders = $dataobj->get_value("funders");
    my $grant = $dataobj->get_value("grant");
    my $projects = $dataobj->get_value("projects");
    if ($dataobj->exists_and_set("funders")) {
        my $thefunders = $xml->create_element("fundingReferences");
        my $author = $xml->create_element("fundingReference");
        foreach my $funder(@$funders) {
            foreach my $project(@$projects) {
                $author->appendChild($xml->create_data_element("funderName", $funder));
                $author->appendChild($xml->create_data_element("awardNumber", $grant));
            }
            $thefunders->appendChild($author);
        }
        return $thefunders;
    }
};



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
