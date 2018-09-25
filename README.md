DateCiteDoi - A plugin to mint DataCite DOIs to eprints
========================================================

Requirements
-------------

In order to use the DataCite API the plugin requires the following perl libraries on top of EPrints requirements.

```
use LWP;
use Crypt::SSLeay;
```

Installation
-------------

Install the plugin from the bazaar and edit the following config files.

```
z_datacitedoi.pl
```

Configuration 
-------------

z_datacitedoi.pl

This config file contains all the configurable settings for the plugin, see comments bellow:

```perl
#Enable the plugin
$c->{plugins}{"Export::DataCiteXML"}{params}{disable} = 0;
$c->{plugins}{"Event::DataCiteEvent"}{params}{disable} = 0;

# which field to use for the doi
$c->{datacitedoi}{eprintdoifield} = "id_number";

#for xml:lang attributes in XML
$c->{datacitedoi}{defaultlangtag} = "en-GB";

#When should you register/update doi info.
$c->{datacitedoi}{eprintstatus} = {inbox=>0,buffer=>1,archive=>1,deletion=>0};

#set these (you will get the from data site)
# doi = {prefix}/{repoid}/{eprintid}
$c->{datacitedoi}{prefix} = "10.5072";
$c->{datacitedoi}{repoid} = $c->{host};
$c->{datacitedoi}{apiurl} = "https://mds.test.datacite.org";
$c->{datacitedoi}{user} = "USER";
$c->{datacitedoi}{pass} = "PASS";

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
$c->{datacitedoi}{schemaLocation} = $c->{datacitedoi}{xmlns}." http://schema.datacite.org/meta/kernel-4/metadata.xsd";

# Need to map eprint type (article, dataset etc) to DOI ResourceType
# Controlled list http://schema.datacite.org/meta/kernel-4.1/doc/DataCite-MetadataKernel_v4.1.pdf
# where v is the ResourceType and a is the resourceTypeGeneral
$c->{datacitedoi}{typemap}{article} = {v=>'Article',a=>'Text'};
$c->{datacitedoi}{typemap}{book_section} = {v=>'BookSection',a=>'Text'};
$c->{datacitedoi}{typemap}{monograph} = {v=>'Monograph',a=>'Text'};
$c->{datacitedoi}{typemap}{thesis} = {v=>'Thesis',a=>'Text'};
$c->{datacitedoi}{typemap}{book} = {v=>'Book',a=>'Text'};
$c->{datacitedoi}{typemap}{patent} = {v=>'Patent',a=>'Text'};
$c->{datacitedoi}{typemap}{artefact} = {v=>'Artefact',a=>'PhysicalObject'};
$c->{datacitedoi}{typemap}{performance} = {v=>'Performance',a=>'Event'};
$c->{datacitedoi}{typemap}{composition} = {v=>'Composition',a=>'Sound'};
$c->{datacitedoi}{typemap}{image} = {v=>'Image',a=>'Image'};
$c->{datacitedoi}{typemap}{experiment} = {v=>'Experiment',a=>'Text'};
$c->{datacitedoi}{typemap}{teaching_resource} = {v=>'TeachingResourse',a=>'InteractiveResource'};
$c->{datacitedoi}{typemap}{other} = {v=>'Misc',a=>'Collection'};
$c->{datacitedoi}{typemap}{dataset} = {v=>'Dataset',a=>'Dataset'};
$c->{datacitedoi}{typemap}{audio} = {v=>'Audio',a=>'Sound'};
$c->{datacitedoi}{typemap}{video} = {v=>'Video',a=>'Audiovisual'};
$c->{datacitedoi}{typemap}{data_collection} = {v=>'Dataset',a=>'Dataset'};

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

```


If using a custom licence you must have phrases for your licences URI and typename (phrases for common licences are supplied in ``lib/lang/en/phrases/coinDOI.xml``). For example in ``archives/REPOID/cfg/lang/en/phrases/copyright.xml`` you might have these entries

```
<epp:phrase id="licenses_uri_cc_exampleorg">https://example.org/eprints/about/legal/</epp:phrase>
<epp:phrase id="licenses_typename_cc_exampleor">University of Example important licence</epp:phrase>

```

See [EPrints wiki](https://wiki.eprints.org/w/Phrase_Format) for the full phrase file format and note that variables (like ``{$config{http_url}}``) do not appear to be supported in licenses_uri_*.


How it works
-------------

``lib/plugins/EPrints/Plugin/Event/DataCiteEvent.pm`` is added to the queue and actually mints the doi.

``lib/plugins/EPrints/Plugin/Sreen/EPrint/Staff/CoinDOI.pm`` adds a button to enable staff to choose when to coin the DOI and request registration.

``lib/plugins/EPrints/Plugin/Export/DataCiteXML.pm`` exports the metadata xml required for minting, this can be used independently and through the user interface. 

By default the plugin produces the following mapping:
```xml
<?xml version="1.0"?>
<resource xmlns="http://datacite.org/schema/kernel-4" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://datacite.org/schema/kernel-4 http://schema.datacite.org/meta/kernel-4/metadata.xsd">
	<identifier identifierType="DOI">[[From Config: $c->{datacitedoi}{prefix}/$c->{datacitedoi}{repoid]]/{{Eprintid}}</identifier>
	<creators>
		<creator>
			<creatorName>[[From Eprint: Creators]]</creatorName>
		</creator>
	</creators>
	<titles>
		<title>[[From Eprint: Title]]/title>
	</titles>
	<publisher>[[From Config: $c->{datacitedoi}{publisher}]]</publisher>
	<publicationYear>[[From Eprint: Year]]</publicationYear>
	<subjects>
		<subject>[[From Eprints: Subjects]]</subject>
	</subjects>
	<resourceType resourceTypeGeneral="[[Mapped From Config: $c->{datacitedoi}{typemap}]]">[[Mapped From Config: $c->{datacitedoi}{typemap}]]</resourceType>
	<alternateIdentifiers>
		<alternateIdentifier alternateIdentifierType="URL">[[From Eprints: Subjects]]</alternateIdentifier>
	</alternateIdentifiers>
</resource>
```

