=head1 NAME
EPrints::Plugin::Export::DataCiteXML
=cut

package EPrints::Plugin::Export::DataCiteXML;
use EPrints::Plugin::Export::Feed;

use EPrints::DataCite::Utils;

@ISA = ('EPrints::Plugin::Export::Feed');

use strict;

use Data::Dumper;
sub new
{
    my ($class, %opts) = @_;

    my $self = $class->SUPER::new(%opts);

    $self->{name} = 'Data Cite XML';
    $self->{accept} = [ 'dataobj/eprint', 'dataobj/document' ];
    $self->{visible} = 'all';
    $self->{suffix} = '.xml';
    $self->{mimetype} = 'application/xml; charset=utf-8';
    $self->{arguments}->{doi} = undef;

    return $self;
}

sub output_dataobj
{
    my( $self, $dataobj, %opts ) = @_;

    my $repo = $self->{repository};
    my $xml = $repo->xml;

    my $class = $dataobj->get_dataset_id;
    my $eprint = $dataobj;
    if( $class eq "document" )
    {
        $eprint = $dataobj->get_eprint;
    }

    #reference the datacite schema from config
    our $entry = $xml->create_element( "resource",
        xmlns=> $repo->get_conf( "datacitedoi", "xmlns" ),
        "xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance",
        "xsi:schemaLocation" => $repo->get_conf( "datacitedoi", "schemaLocation" )
    );

    #RM We pass in the DOI from Event::DataCite... or from --args on the cmd line

    my $thisdoi = $opts{doi};
    $thisdoi = $dataobj->get_value( "id_number" ) unless defined $opts{doi};

    #RM coin a DOI if either
        # - not come via event or
        # - no doi arg passed in via cmd_line
        # ie when someone exports DataCiteXML from the Action tab
    if( !defined $thisdoi )
    {
        $thisdoi = EPrints::DataCite::Utils::generate_doi( $repo, $dataobj );
        #coin_doi may return an event error code if no prefix present assume this is the case
        my $prefix = $repo->get_conf( "datacitedoi", "prefix" );
        return $thisdoi if( $thisdoi !~ /^$prefix/ );
    }
    $entry->appendChild( $xml->create_data_element( "identifier", $thisdoi, identifierType=>"DOI" ) );
    
    my $conf_hash_reference = $repo->{config};
    foreach my $mapping_fn ( keys %$conf_hash_reference )
    {
        # If this is a datacite_mapping configuration item (aka one of our subroutines)
        # For both eprints and documents, most of the DataCite XML values still come from the eprint object so these functions will have either the eprint passed to them, or when coining a document DOI, the document's parent eprint
        if( index( $mapping_fn, 'datacite_mapping_' ) == 0 )
        {
            # Value of $mapping_fn matches datacite_mapping_, so is probably a helper method
            if( $repo->can_call( $mapping_fn ) )
            {
                my $mapped_element = $repo->call( $mapping_fn, $xml, $eprint, $repo );
                $entry->appendChild( $mapped_element ) if( defined $mapped_element );
            }
        }
        # Some mapping functions should only be called for eprints
        elsif( index( $mapping_fn, 'datacite_eprint_mapping_' ) == 0 && $class eq "eprint" )
        {
            if( $repo->can_call( $mapping_fn ) )
            {
                my $mapped_element = $repo->call( $mapping_fn, $xml, $eprint, $repo );
                $entry->appendChild( $mapped_element ) if( defined $mapped_element );
            }
        }

        # We also have some document specific mapping functions, used only when coining a document DOI
        elsif( index ( $mapping_fn, 'datacite_document_mapping_' ) == 0 && $class eq "document" )
        {
            if( $repo->can_call( $mapping_fn ) )
            {
                my $mapped_element = $repo->call( $mapping_fn, $xml, $dataobj, $eprint, $repo );
                $entry->appendChild( $mapped_element ) if( defined $mapped_element );
            }
        }
     }
     
####### From here on in you can redefine datacite_mapping_[fieldname] sub routines in lib/cfg.d/zzz_datacite_mapping.pl  #######################

    return '<?xml version="1.0" encoding="UTF-8"?>'."\n".$xml->to_string( $entry, indent => 1 );
}

1;
