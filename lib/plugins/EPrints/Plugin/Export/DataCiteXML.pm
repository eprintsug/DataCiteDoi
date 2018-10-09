=head1 NAME
EPrints::Plugin::Export::DataCiteXML
=cut

package EPrints::Plugin::Export::DataCiteXML;
use EPrints::Plugin::Export::Feed;

@ISA = ('EPrints::Plugin::Export::Feed');

use strict;

use Data::Dumper;
sub new
{
        my ($class, %opts) = @_;

        my $self = $class->SUPER::new(%opts);

        $self->{name} = 'Data Cite XML';
        $self->{accept} = [ 'dataobj/eprint'];
        $self->{visible} = 'all';
        $self->{suffix} = '.xml';
        $self->{mimetype} = 'application/xml; charset=utf-8';
        $self->{arguments}->{doi} = undef;

      return $self;
}

sub output_dataobj
{
    my ($self, $dataobj, %opts) = @_;

    my $repo = $self->{repository};
    my $xml = $repo->xml;

    #reference the datacite schema from config
    our $entry = $xml->create_element( "resource",
                    xmlns=> $repo->get_conf( "datacitedoi", "xmlns"),
                    "xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance",
                    "xsi:schemaLocation" => $repo->get_conf( "datacitedoi", "schemaLocation"));

    #RM We pass in the DOI from Event::DataCite... or from --args on the cmd line

    # AH my $thisdoi = $opts{doi}; always returns undefined, even when DOI exists
    # Ideally coining should NOT happen in this script but opts{doi} should have it
    # but is always blank
    my $thisdoi = $dataobj->get_value("id_number");
    #RM coin a DOI if either
            # - not come via event or
            # - no doi arg passed in via cmd_line
    # ie when someone exports DataCiteXML from the Action tab
    if(!defined $thisdoi){
            #nick the coining sub from event plugin
            my $event = $repo->plugin("Event::DataCiteEvent");
            $thisdoi = $event->coin_doi($repo, $dataobj);
            #coin_doi may return an event error code if no prefix present assume this is the case
            my $prefix = $repo->get_conf( "datacitedoi", "prefix");
            return $thisdoi if($thisdoi !~ /^$prefix/);
    }
    $entry->appendChild( $xml->create_data_element( "identifier", $thisdoi , identifierType=>"DOI" ) );
    
    my $conf_hash_reference = $repo->{config};
    foreach my $mapping_fn (keys %$conf_hash_reference){
        # If this is a datacite_mapping configuration item (aka one of our subroutines)
        if (index($mapping_fn, 'datacite_mapping_') == 0) {
            # Value of $mapping_fn matches datacite_mapping_, so is probably a helper method
            if($repo->can_call($mapping_fn)){
                    my $mapped_element = $repo->call( $mapping_fn, $xml, $dataobj, $repo );
                    $entry->appendChild( $mapped_element ) if(defined $mapped_element);
            }
        }
     }
     
####### From here on in you can redefine datacite_mapping_[fieldname] sub routines in lib/cfg.d/zzz_datacite_mapping.pl  #######################


            return '<?xml version="1.0" encoding="UTF-8"?>'."\n".$xml->to_string($entry);
}


1;
