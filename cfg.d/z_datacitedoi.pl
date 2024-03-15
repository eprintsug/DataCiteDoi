#Enable the plugin
$c->{plugins}{"Export::DataCiteXML"}{params}{disable} = 0;
$c->{plugins}{"Event::DataCiteEvent"}{params}{disable} = 0;

# flag to indicate if this repository is able to coin dois for documents (off by default)
$c->{datacitedoi}{document_dois} = 0;

# which fields to use for the doi
$c->{datacitedoi}{eprintdoifield} = "id_number";
$c->{datacitedoi}{documentdoifield} = "id_number";

#for xml:lang attributes in XML
$c->{datacitedoi}{defaultlangtag} = "en-GB";

#When can you create/update doi info.
$c->{datacitedoi}{eprintstatus} = {inbox=>0,buffer=>0,archive=>1,deletion=>0};

#When can you reserve a DOI
$c->{datacitedoi}{reservestatus} = {inbox=>0,buffer=>1,archive=>1,deletion=>0};


# Choose which EPrint types are allowed (or denied) the ability to coin DOIs. Keys must be lower case and be eprints *types* not *type_names*.
# Entries here can be explicitly skipped by setting 0; however those not listed with a 1 are not given a Coin DOI button by default.
# To include the 'Coin DOI' button on all types leave this undefined.
# $c->{datacitedoi}{typesallowed} = {
# 				'article'=>0,                   # Article
# 				'thesis'=>1,                    # Thesis
# 				'creative_works' => 1,          # Creative Works
# 				'dataset' => 1,                 # Dataset
#                                 };

#set these (you will get the from data site)
# doi = {prefix}/{repoid}/{eprintid}
$c->{datacitedoi}{prefix} = "10.5072";
$c->{datacitedoi}{repoid} = $c->{host};
$c->{datacitedoi}{mdsurl} = "https://mds.test.datacite.org/";
$c->{datacitedoi}{apiurl} = "https://api.test.datacite.org/";
$c->{datacitedoi}{user} = "USER";
$c->{datacitedoi}{pass} = "PASS";

# Backend library used for connecting to API; defaults to LWP (configuration item unset) but can also be Curl (configuration item set).
# $c->{datacitedoi}{use_curl} = "yes";

# Priviledge required to be able to mint DOIs
# See https://wiki.eprints.org/w/User_roles.pl for role and privilege configuration
$c->{datacitedoi}{minters} = "eprint/edit:editor";

# DataCite requires a Publisher
# The name of the entity that holds, archives, publishes,
# prints, distributes, releases, issues, or produces the
# resource. This property will be used to formulate the
# citation, so consider the prominence of the role.
# eg World Data Center for Climate (WDCC);
$c->{datacitedoi}{publisher} = "EPrints Repo";

# Namespace and location for DataCite XML schema
# feel free to update, though no guarantees it'll be accepted if you do
$c->{datacitedoi}{xmlns} = "http://datacite.org/schema/kernel-4";
# Try this instead:
# $c->{datacitedoi}{schemaLocation} = $c->{datacitedoi}{xmlns}." ".$c->{datacitedoi}{xmlns}."/metadata.xsd";
$c->{datacitedoi}{schemaLocation} = $c->{datacitedoi}{xmlns}." https://schema.datacite.org/meta/kernel-4.4/metadata.xsd";

# Need to map eprint type (article, dataset etc) to DOI ResourceType
# Controlled list https://schema.datacite.org/meta/kernel-4.4/doc/DataCite-MetadataKernel_v4.4.pdf
# where v is the ResourceType and a is the resourceTypeGeneral
$c->{datacitedoi}{typemap}{article} = {v=>'Article',a=>'JournalArticle'};
$c->{datacitedoi}{typemap}{book_section} = {v=>'Book Section',a=>'BookChapter'};
$c->{datacitedoi}{typemap}{monograph} = {v=>'Monograph',a=>'Text'};
$c->{datacitedoi}{typemap}{conference_item} = {v=>'Conference Paper',a=>'ConferencePaper'};
$c->{datacitedoi}{typemap}{book} = {v=>'Book',a=>'Book'};
$c->{datacitedoi}{typemap}{thesis} = {v=>'Thesis',a=>'Dissertation'};
$c->{datacitedoi}{typemap}{patent} = {v=>'Patent',a=>'Text'};
$c->{datacitedoi}{typemap}{artefact} = {v=>'Artefact',a=>'PhysicalObject'};
$c->{datacitedoi}{typemap}{exhibition} = {v=>'Exhibition',a=>'InteractiveResource'};
$c->{datacitedoi}{typemap}{composition} = {v=>'Composition',a=>'Sound'};
$c->{datacitedoi}{typemap}{performance} = {v=>'Performance',a=>'Event'};
$c->{datacitedoi}{typemap}{image} = {v=>'Image',a=>'Image'};
$c->{datacitedoi}{typemap}{video} = {v=>'Video',a=>'Audiovisual'};
$c->{datacitedoi}{typemap}{audio} = {v=>'Audio',a=>'Sound'};
$c->{datacitedoi}{typemap}{dataset} = {v=>'Dataset',a=>'Dataset'};
$c->{datacitedoi}{typemap}{experiment} = {v=>'Experiment',a=>'Text'};
$c->{datacitedoi}{typemap}{teaching_resource} = {v=>'Teaching Resource',a=>'InteractiveResource'};
$c->{datacitedoi}{typemap}{other} = {v=>'Misc',a=>'Collection'};
#For use with recollect
$c->{datacitedoi}{typemap}{data_collection} = {v=>'Dataset',a=>'Dataset'};
$c->{datacitedoi}{typemap}{collection} = {v=>'Collection',a=>'Collection'};

# Need to map contributor type to DOI contributorType
# Controlled list https://schema.datacite.org/meta/kernel-4.3/doc/DataCite-MetadataKernel_v4.3.pdf
$c->{datacitedoi}{contributormap}{'http://www.loc.gov/loc.terms/relators/MDC'} = 'ContactPerson';
$c->{datacitedoi}{contributormap}{'http://www.loc.gov/loc.terms/relators/PRC'} = 'ContactPerson';
$c->{datacitedoi}{contributormap}{'http://www.loc.gov/loc.terms/relators/COL'} = 'DataCollector';
$c->{datacitedoi}{contributormap}{'http://www.loc.gov/loc.terms/relators/IVR'} = 'DataCollector';
$c->{datacitedoi}{contributormap}{'http://www.loc.gov/loc.terms/relators/MON'} = 'DataCollector';
$c->{datacitedoi}{contributormap}{'http://www.loc.gov/loc.terms/relators/DST'} = 'Distributor';
$c->{datacitedoi}{contributormap}{'http://www.loc.gov/loc.terms/relators/EDT'} = 'Editor';
$c->{datacitedoi}{contributormap}{'http://www.loc.gov/loc.terms/relators/HST'} = 'HostingInstitution';
$c->{datacitedoi}{contributormap}{'http://www.loc.gov/loc.terms/relators/BKP'} = 'Producer';
$c->{datacitedoi}{contributormap}{'http://www.loc.gov/loc.terms/relators/PRO'} = 'Producer';
$c->{datacitedoi}{contributormap}{'http://www.loc.gov/loc.terms/relators/RTH'} = 'ProjectLeader';
$c->{datacitedoi}{contributormap}{'http://www.loc.gov/loc.terms/relators/RTM'} = 'ProjectMember';
$c->{datacitedoi}{contributormap}{'http://www.loc.gov/loc.terms/relators/RES'} = 'Researcher';
$c->{datacitedoi}{contributormap}{'http://www.loc.gov/loc.terms/relators/CPH'} = 'RightsHolder';
$c->{datacitedoi}{contributormap}{'http://www.loc.gov/loc.terms/relators/SPN'} = 'Sponsor';

# Need to map dates date type to DOI dateType
# Controlled list https://schema.datacite.org/meta/kernel-4.3/doc/DataCite-MetadataKernel_v4.3.pdf
$c->{datacitedoi}{datemap}{accepted} = 'Accepted';
$c->{datacitedoi}{datemap}{submitted} = 'Submitted';

###########################
#### DOI syntax config ####
###########################

# Set config of DOI delimiters
# Feel free to change, but they must conform to DOI syntax
# If not set will default to prefix/repoid/id the example below gives prefix/repoid.id
$c->{datacitedoi}{delimiters} = ["/","."];

# If set, plugin will attempt to register what is found in the EP DOI field ($c->{datacitedoi}{eprintdoifield})
# Will only work if what is found adheres to DOI syntax rules (obviously)
$c->{datacitedoi}{allow_custom_doi} = 0;

#Datacite recommend digits of length 8-10 set this param to pad the id to required length
$c->{datacitedoi}{zero_padding} = 8;

##########################################
### Override which URL gets registered ###
##########################################

#Only useful for testing from "wrong" domain (eg an unregistered test server) should be undef for normal operation
$c->{datacitedoi}{override_url} = undef;

##########################
##### When to coin ? #####
##########################

#If auto_coin is set DOIs will be minted on Status change (provided all else is well)
$c->{datacitedoi}{auto_coin} = 0;
#If action_coin is set then a button will be displayed under action tab (for staff) to mint DOIs on an adhoc basis
$c->{datacitedoi}{action_coin} = 1;

# function to check if we're happy to auto-mint DOIs which are currently reserved
$c->{datacitedoi}{reserve_to_findable} = sub {
    my( $dataobj, $repo ) = @_;
    
    return 1; # returns true by default
};

# NB setting auto_coin renders action coin redundant as only published items can be registered

####### Formerly in cfg.d/datacite_core.pl #########

# Including datacite_core.pl below as we can make some useful decisions based on the above config.

## Adds the minting plugin to the EP_TRIGGER_STATUS_CHANGE
if($c->{datacitedoi}{auto_coin}){
	$c->add_dataset_trigger( "eprint", EP_TRIGGER_STATUS_CHANGE , sub {
       my ( %params ) = @_;

       my $repository = $params{repository};

       return undef if (!defined $repository);

		if (defined $params{dataobj}) {
			my $dataobj = $params{dataobj};
			my $eprint_id = $dataobj->id;
			$repository->dataset( "event_queue" )->create_dataobj({
				pluginid => "Event::DataCiteEvent",
				action => "datacite_doi",
				params => [$dataobj->internal_uri],
			});
     	}

	});
}

# Activate an action button, the plugin for which is at
# /plugins/EPrints/Plugin/Screen/EPrint/Staff/CoinDOI.pm
if($c->{datacitedoi}{action_coin}){
 	$c->{plugins}{"Screen::EPrint::Staff::CoinDOI"}{params}{disable} = 0;
}

$c->{datacitedoi}{max_results} = 5;
$c->{datacitedoi}{show_xml} = 1;

# Items with DOIs coined in DataCite that are retired should have their status changed from findable to registered
$c->add_dataset_trigger( "eprint", EP_TRIGGER_STATUS_CHANGE , sub {
    my( %params ) = @_;

    my $repository = $params{repository};
    return undef if( !defined $repository );
    
    # do we have an eprint
    return if !defined $params{dataobj};
    my $eprint = $params{dataobj};

    # do we have a DOI?
    my $eprint_doi_field = $repository->get_conf( "datacitedoi", "eprintdoifield" );
    if( $eprint->is_set( $eprint_doi_field ) )
    {
        # trigger indexer update doi event
        $repository->dataset( "event_queue" )->create_dataobj({
            pluginid => "Event::DataCiteEvent",
            action => "datacite_update_doi_state",
            params => [$eprint->internal_uri, $params{new_status}],
        });
    }

    # and now update the documents
    my $document_doi_field = $repository->get_conf( "datacitedoi", "documentdoifield" );
    foreach my $doc ( $eprint->get_all_documents )
    {
        if( $doc->is_set( $document_doi_field ) )
        {
            # trigger indexer update doi event
            $repository->dataset( "event_queue" )->create_dataobj({
                pluginid => "Event::DataCiteEvent",
                action => "datacite_update_doi_state",
                params => [$doc->internal_uri, $params{new_status}],
            });
        }
    }

});

$c->add_dataset_trigger( "eprint", EP_TRIGGER_REMOVED, \&remove_doi );
$c->add_dataset_trigger( "document", EP_TRIGGER_REMOVED, \&remove_doi );

{
    sub remove_doi
    {
        my( %params ) = @_;

        my $repository = $params{repository};
        return undef if( !defined $repository );

        # do we have a dataobj (eprint or document)
        return if !defined $params{dataobj};
        my $dataobj = $params{dataobj};

        my $datasetid = $dataobj->get_dataset_id;

        # if document_dois is turned off, we don't need to worry about removing document dois
        return if $datasetid eq "document" && !$repository->get_conf( "datacitedoi", "document_dois" );

        # do we have a DOI?
        my $doi_field = $repository->get_conf( "datacitedoi", $datasetid."doifield" );
        return if !$dataobj->is_set( $doi_field );        

        # get dataobj uri to check, when the event is called, if this DOI actually points to us
        my $dataobj_uri = $dataobj->uri;
        if( $repository->can_call( $datasetid."_landing_page" ) ) # landing page url override for documents (or eprints if needed)
        {
            $dataobj_uri = $repository->call( $datasetid."_landing_page", $dataobj, $repository );
        }

        # trigger indexer to remove doi
        $repository->dataset( "event_queue" )->create_dataobj({
            pluginid => "Event::DataCiteEvent",
            action => "datacite_remove_doi",
            params => [$datasetid, $dataobj->id, $dataobj_uri, $dataobj->value( $doi_field )],
        });
    }
};

$c->{document_landing_page} = sub
{
    my( $document, $repo ) = @_;

    return $repo->get_conf( "base_url" ) . $repo->call( "document_internal_landing_page", $document, $repo );
};

$c->{document_internal_landing_page} = sub
{
    my( $document, $repo ) = @_;

    return "/document/" . $document->id;
};
