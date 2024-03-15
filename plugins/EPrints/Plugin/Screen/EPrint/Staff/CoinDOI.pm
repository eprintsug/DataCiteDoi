package EPrints::Plugin::Screen::EPrint::Staff::CoinDOI;

#use EPrints::Plugin::Screen::EPrint;

use EPrints::DataCite::Utils;
use Data::Dumper;

@ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
    my( $class, %params ) = @_;

    my $self = $class->SUPER::new(%params);

    # $self->{priv} = # no specific priv - one per action

    $self->{actions} = [qw/ mintdoi claimdoi reservedoi updatedoi updateurl /];

    $self->{appears} = [ {
        place => "eprint_editor_actions",
        position => 1977,
    }, ];

    return $self;
}

sub obtain_lock
{
    my( $self ) = @_;

    return $self->could_obtain_eprint_lock;
}

sub can_be_viewed
{
    my( $self ) = @_;

    return 0 unless $self->could_obtain_eprint_lock;

    my $repo = $self->repository;
    my $eprint = $self->{processor}->{eprint};

    if( defined $repo->get_conf( "datacitedoi", "typesallowed" ) )
    {
        # Is this type of eprint allowed/denied minting?
        return 0 unless $repo->get_conf( "datacitedoi", "typesallowed",  $eprint->get_type );
    }

    # eprint has to be in a state where DOIs can be created or reserved
    if( !$repo->get_conf( "datacitedoi", "eprintstatus",  $eprint->value( "eprint_status" ) )
        && !$repo->get_conf( "datacitedoi", "reservestatus",  $eprint->value( "eprint_status" ) ) )
    {
        return 0;
    }

    return $self->allow( $repo->get_conf( "datacitedoi", "minters" ) );
}

sub properties_from
{
    my( $self ) = @_;
    
    my $repo = $self->repository;
    $self->SUPER::properties_from;

    my $eprint = $self->{processor}->{eprint};
    my $eprint_id = $eprint->id;

    # get the fields where we would store dois
    my $eprint_doi_field = $repo->get_conf( "datacitedoi", "eprintdoifield" );
    my $document_doi_field = $repo->get_conf( "datacitedoi", "documentdoifield" );

    $self->{processor}->{eprint_field} = $eprint_doi_field;
    $self->{processor}->{document_field} = $document_doi_field;

    ## EPrint DOI data
    $self->{processor}->{dois}->{eprint}->{$eprint_id} = $self->get_doi_info( $repo, $eprint, $eprint_doi_field );

    # check to see if this eprint is a later version of an existing eprint
    if( $eprint->is_set( "succeeds" ) )
    {
        my $ds = $repo->dataset( $eprint->get_dataset_id );
        my $parent = $ds->dataobj( $eprint->value( "succeeds" ) );
        if( defined $parent )
        {
            my $parent_id = $parent->id;
            $self->{processor}->{dois}->{eprint}->{$parent_id} = $self->get_doi_info( $repo, $parent, $eprint_doi_field );

            if( $self->{processor}->{dois}->{eprint}->{$eprint_id}->{current_doi}->{url} eq $parent->uri )
            {
                $self->{processor}->{dois}->{eprint}->{$eprint_id}->{current_doi}->{redirects_to_parent} = 1;
            }

        }
    }

    ## Document DOI data
    # only check for existing document dois if this repository can mint doc dois and present landing pages for them
    if( $repo->get_conf( "datacitedoi", "document_dois" ) )
    {
        foreach my $doc ( $eprint->get_all_documents )
        {
            my $doc_id = $doc->id;
            $self->{processor}->{dois}->{document}->{$doc_id} = $self->get_doi_info( $repo, $doc, $document_doi_field ); 
        }
    }

    # DataCite title query to look for any DOIs that might already represent this record
    if( !$eprint->is_set( $eprint_doi_field ) )
    {
        $self->{processor}->{datacite_response} = EPrints::DataCite::Utils::datacite_api_query( $repo, "titles.title", $eprint->value( "title" ) );
    }
}

sub get_doi_info
{
    my( $self, $repo, $dataobj, $doi_field ) = @_;

    my $data = {};

    # get the DOI that would be generated for this eprint
    my $generated_doi = EPrints::DataCite::Utils::generate_doi( $repo, $dataobj );

    # Does the DOI that would be generated for this record already exist, either in draft form of some other form
    my $datacite_data = EPrints::DataCite::Utils::datacite_doi_query( $repo, $generated_doi );

    # store state
    if( defined $datacite_data )
    {
        $data->{generated_doi} = $self->process_datacite_response( $repo, $dataobj, $datacite_data );
    }
    else
    {
         $data->{generated_doi}->{state} = "available"; # not an official DataCite state, used to say we can mint
    }

    # finally, store the generated DOI
    $data->{generated_doi}->{doi} = $generated_doi;

    # store the current DOI
    if( $dataobj->is_set( $doi_field ) )
    {        
        my $current_doi = $dataobj->value( $doi_field );
     
        # check the DOI with DataCite       
        my $datacite_data = EPrints::DataCite::Utils::datacite_doi_query( $repo, $current_doi );

        # we have a response from DataCite for our stored DOI
        if( defined $datacite_data )
        {
             $data->{current_doi} = $self->process_datacite_response( $repo, $dataobj, $datacite_data );
        }
        # no response from DataCite, but this DOI is the same as the one we would mint
        elsif( lc( $current_doi ) eq lc( $generated_doi ) ) 
        {
            $data->{current_doi}->{state} = "available"; # not an official DataCite state, used to say we can mint
        }
        # no response and we don't know what to do with the DOI, probably not one of ours
        else
        {
            $data->{current_doi}->{state} = "unavailable"; # not an official DataCite state, used to say nothing we can do
        }

        # finally, store the current DOI
        $data->{current_doi}->{doi} = $current_doi;
    }
    return $data;
}

# gets all the data we might need from a datacite DOI query response
sub process_datacite_response
{
    my( $self, $repo, $dataobj, $datacite_data ) = @_;
    my $data = {};

    # first get the state
    my $state = $datacite_data->{data}->{attributes}->{state};
    $data->{state} = $state;

    # get timestamps
    $data->{created} = $datacite_data->{data}->{attributes}->{created} if defined $datacite_data->{data}->{attributes}->{created};
    $data->{registered} = $datacite_data->{data}->{attributes}->{registered};
    $data->{updated} = $datacite_data->{data}->{attributes}->{updated};

    # get the url
    if( defined $datacite_data->{data}->{attributes}->{url} )
    {
        $data->{url} = $datacite_data->{data}->{attributes}->{url};   
 
        # does it point to us?
        my $datacite_ds = $repo->dataset( "datacite" );
        my $dc = $datacite_ds->dataobj_class->get_datacite_record( $repo, $dataobj->get_dataset_id, $dataobj->id );
        my $tombstone_url = "";
        if( defined $dc )
        {
            $tombstone_url = $dc->get_url if defined $dc;
            $data->{tombstone_url} = $tombstone_url;
        }

        my $class = $dataobj->get_dataset_id;
        my $dataobj_uri = $dataobj->uri;
        if( $repo->can_call( $class."_landing_page" ) ) # landing page url override for documents (or eprints if needed)
        {
            $dataobj_uri = $repo->call( $class."_landing_page", $dataobj, $repo );
        }
        $data->{dataobj_url} = $dataobj_uri;

        if( $datacite_data->{data}->{attributes}->{url} eq $dataobj_uri || $datacite_data->{data}->{attributes}->{url} eq $tombstone_url )
        {
            $data->{redirects_to_dataobj} = 1;   
        }
    }

    # can the repository update it?
    my $username = $repo->get_conf( "datacitedoi", "user" );
    if( lc( $datacite_data->{data}->{relationships}->{client}->{data}->{id} ) eq lc( $username ) )
    {
        $data->{repo_doi} = 1;   
    }
    
    return $data;
}

sub render
{
    my( $self ) = @_;

    my $repo = $self->{session};
    my $eprint = $self->{processor}->{eprint};

    my $frag = $repo->make_doc_fragment;

    # present datacite info and options for the eprint and its documents
    $frag->appendChild( $self->render_dataobj( $eprint ) );

    # present a collapsible box for each document (if we can mint dois for documents)
    if( $repo->get_conf( "datacitedoi", "document_dois" ) )
    {   
        foreach my $doc ( $eprint->get_all_documents )
        {
            $frag->appendChild( $self->render_dataobj( $doc ) );
        }
    }
    
    return $frag;
}

sub render_dataobj
{
    my( $self, $dataobj ) = @_;

    my $repo = $self->{repository};

    ### initialise with data we may need
    my $class = $dataobj->get_dataset_id;
    my $dataobj_id = $dataobj->id;

    my $doi_field = $self->{processor}->{$class.'_field'};
    my $generated_doi = EPrints::DataCite::Utils::generate_doi( $repo, $dataobj );

    my $datacite_data;
    $datacite_data = $self->{processor}->{$class}->{$dataobj_id}->{datacite_data} if exists $self->{processor}->{$class}->{$dataobj_id};

    ### start rendering
    my $div = $repo->make_element( "div", class => "datacite_object datacite_$class" );

    ## display basic info about the dataobj
    my $info_div = $div->appendChild( $repo->make_element( "div", class => "datacite_dataobj_info datacite_section" ) );

    # dataobj citation
    my $citation_div = $info_div->appendChild( $repo->make_element( "div", class => "datacite_citation" ) );
    if( $class eq "eprint" )
    {
        $citation_div->appendChild( $dataobj->render_citation_link );
    }
    elsif( $class eq "document" )
    {
        $citation_div->appendChild( $self->render_document_citation( $dataobj ) );
    }

    ## Potential problems
    my $problems = $self->validate( $dataobj );
    my $no_problems = scalar @{$problems};
    if( $no_problems > 0 )
    {
        my $coin_problems = $repo->make_element( "div", class => "coin_problems" );
        $coin_problems->appendChild( $self->html_phrase( "coin_doi:problems" ) );

        my $coin_problems_list = $coin_problems->appendChild( $repo->make_element( "ul" ) );
        foreach my $problem_xhtml ( @{$problems} )
        {
            my $li = $coin_problems_list->appendChild( $repo->make_element( "li", class => "coin_warning" ) );
            $li->appendChild( $problem_xhtml );            
        }
        $div->appendChild( $coin_problems );
    }

    ## DOI options
    if( $dataobj->is_set( $doi_field ) )
    {
        $div->appendChild( $self->render_current_doi( $dataobj, $doi_field, $self->{processor}->{dois}->{$class}->{$dataobj_id}, $no_problems ) );
    }

    if( !$dataobj->is_set( $doi_field ) || lc( $dataobj->value( $doi_field ) ) ne lc( $generated_doi ) )
    {
        $div->appendChild( $self->render_available_doi( $dataobj, $doi_field, $self->{processor}->{dois}->{$class}->{$dataobj_id}, $no_problems ) );

    }

    # if we're an eprint we might be able to find potential dois in datacite
    if( $class eq "eprint" && !$dataobj->is_set( $doi_field ) )
    {
        $div->appendChild( $self->render_datacite_dois( $dataobj ) );
    }

    # DataCite XML
    if( $repo->get_conf( "datacitedoi", "show_xml" ) )
    {
        my $box = $repo->make_element( "div", class => "datacite_xml" );
        $box->appendChild( EPrints::Box::render(
            id => "datacite_xml_".$class."_".$dataobj_id,
            title => $self->html_phrase( "data:title" ),
            content => $self->render_xml( $dataobj ),
            collapsed => 1,
            session => $repo,
        ) );
        $div->appendChild( $box );
    }

    return $div;
}

sub render_document_citation
{
    my( $self, $doc ) = @_;

    my $repo = $self->{repository};
  
    my $div = $repo->make_element( "div", class => "datacite_doc_citation" );
    
    my $table = $div->appendChild( $repo->make_element( "div", class => "ep_table" ) );
    my $tr = $table->appendChild( $repo->make_element( "div", class => "ep_table_row" ) );

    my $icon = $tr->appendChild( $repo->make_element( "div", class => "ep_table_cell" ) );
    $icon->appendChild( $doc->render_icon_link );

    my $citation = $tr->appendChild( $repo->make_element( "div", class => "ep_table_cell" ) );
    $citation->appendChild( $doc->render_citation_link );

    return $div;
}

# Display information and options about the DOI currently associated with the record
sub render_current_doi
{
    my( $self, $dataobj, $doi_field, $doi_info, $no_problems ) = @_;

    my $repo = $self->{repository};
    my $eprint = $self->{processor}->{eprint};

    my $div = $repo->make_element( "div", class => "current_doi datacite_section" );
 
    ## title
    my $title_div = $div->appendChild( $repo->make_element( "h2", class => "datacite_title" ) );
    $title_div->appendChild( $self->html_phrase( "current_doi:title" ) );

    my $doi_table = $div->appendChild( $repo->make_element( "div", class => "ep_table" ) );

    ## DOI    
    my $doi_row = $doi_table->appendChild( $repo->make_element( "div", class => "ep_table_row" ) );
    my $doi_title = $doi_row->appendChild( $repo->make_element( "div", class => "ep_table_cell" ) );
    $doi_title->appendChild( $self->html_phrase( "current_doi:doi" ) );
    my $doi_value = $doi_row->appendChild( $repo->make_element( "div", class => "ep_table_cell" ) );
    $doi_value->appendChild( $dataobj->render_value( $doi_field ) );

    ## Redirects to
    my $redirect_row = $doi_table->appendChild( $repo->make_element( "div", class => "ep_table_row" ) );
    my $redirect_title = $redirect_row->appendChild( $repo->make_element( "div", class => "ep_table_cell" ) );
    $redirect_title->appendChild( $self->html_phrase( "current_doi:redirect" ) );
    my $redirect_value = $redirect_row->appendChild( $repo->make_element( "div", class => "ep_table_cell" ) );

    # Redirect options...
    # Redirects to self
    if( defined $doi_info->{current_doi}->{redirects_to_dataobj} )
    {
        my $link = $repo->make_element( "a", href => $doi_info->{current_doi}->{url}, target => "_blank" );
        $link->appendChild( $repo->make_text( $doi_info->{current_doi}->{url} ) );
        $redirect_value->appendChild( $self->html_phrase( "current_doi:redirect:self", url => $link ) );
    }
    # Redirects to known DataCite URL
    elsif( defined $doi_info->{current_doi}->{url} )
    {
        my $link = $repo->make_element( "a", href => $doi_info->{current_doi}->{url}, target => "_blank" );
        $link->appendChild( $repo->make_text( $doi_info->{current_doi}->{url} ) );
     
        # Redirects to parent EPrint
        if( defined $doi_info->{current_doi}->{redirects_to_parent} )
        {
            $redirect_value->appendChild( $self->html_phrase( "current_doi:redirect:parent", url => $link ) );
        }
        else
        {             
            $redirect_value->appendChild( $link );
        }
    }
    else
    {
        $redirect_value->appendChild( $dataobj->render_value( $doi_field ) );
    }

    # Options to update a current DOI in registered/findable state
    if( $doi_info->{current_doi}->{state} ne "draft" && $no_problems == 0 )
    {
        # We can update and it already points to us => Just update metadata
        if( $self->check_update_only( $doi_info ) )
        {
            $doi_table->appendChild( $self->render_update_row(
                $repo,
                $dataobj,
                $doi_info->{current_doi}->{doi},
                $doi_info->{current_doi}->{registered},
                $doi_info->{current_doi}->{updated},
            ) );
        }
        elsif( $self->check_update_metadata_and_url( $dataobj, $doi_info->{current_doi} ) )
        {
            $doi_table->appendChild( $self->render_update_url_row(
                $repo,
                $dataobj,
                $doi_info->{current_doi}->{doi},
                "current_doi",
                $doi_info->{current_doi}->{registered},
                $doi_info->{current_doi}->{updated},
            ) );
        }
    }

    # Option to update draft doi or coin an available doi
    if( $doi_info->{current_doi}->{state} eq "available" || $doi_info->{current_doi}->{state} eq "draft" )
    {
        ## Reserve
        if( $self->allow_reservedoi )
        {
            $doi_table->appendChild( $self->render_reserve_row(
                $repo,
                $dataobj,
                $doi_info->{current_doi},
            ) );
        }

        ## Mint
        if( $no_problems == 0 && $self->allow_mintdoi )
        {
            $doi_table->appendChild( $self->render_mint_row( 
                $repo,
                $dataobj,
            ) );
        }        
    }
    return $div;
}

# Display information and options about a DOI that is available/reserved for this record
sub render_available_doi
{
    my( $self, $dataobj, $doi_field, $doi_info, $no_problems ) = @_;
    
    my $repo = $self->{repository};

    my $div = $repo->make_element( "div", class => "available_doi datacite_section" );
 
    ## title
    my $title_div = $div->appendChild( $repo->make_element( "h2", class => "datacite_title" ) );
    $title_div->appendChild( $self->html_phrase( "available_doi:title" ) );

    ## show alert if dataobj already has a DOI (we don't want to mint an unnecessary one just because we can)
    if( $dataobj->is_set( $doi_field ) )
    {
        my $alert_div = $div->appendChild( $repo->make_element( "div", class => "datacite_alert" ) );
        $alert_div->appendChild( $self->html_phrase( "available_doi:alert" ) );
    }

    my $doi_table = $div->appendChild( $repo->make_element( "div", class => "ep_table" ) );

    ## DOI    
    my $doi_row = $doi_table->appendChild( $repo->make_element( "div", class => "ep_table_row" ) );
    my $doi_title = $doi_row->appendChild( $repo->make_element( "div", class => "ep_table_cell" ) );
    $doi_title->appendChild( $self->html_phrase( "available_doi:doi" ) );
    my $doi_value = $doi_row->appendChild( $repo->make_element( "div", class => "ep_table_cell" ) );
    $doi_value->appendChild( $repo->make_text( $doi_info->{generated_doi}->{doi} ) );

    ## Redirects to
    if( defined $doi_info->{generated_doi}->{url} )
    {
        my $redirect_row = $doi_table->appendChild( $repo->make_element( "div", class => "ep_table_row" ) );
        my $redirect_title = $redirect_row->appendChild( $repo->make_element( "div", class => "ep_table_cell" ) );
        $redirect_title->appendChild( $self->html_phrase( "generated_doi:redirect" ) );
        my $redirect_value = $redirect_row->appendChild( $repo->make_element( "div", class => "ep_table_cell" ) );

        # Redirect options...
        # Redirects to self
        if( defined $doi_info->{generated_doi}->{redirects_to_dataobj} )
        {
            my $link = $repo->make_element( "a", href => $doi_info->{generated_doi}->{url}, target => "_blank" );
            $link->appendChild( $repo->make_text( $doi_info->{generated_doi}->{url} ) );
            $redirect_value->appendChild( $self->html_phrase( "generated_doi:redirect:self", url => $link ) );
        }
        else
        {                
            my $link = $repo->make_element( "a", href => $doi_info->{generated_doi}->{url}, target => "_blank" );
            $link->appendChild( $repo->make_text( $doi_info->{generated_doi}->{url} ) );
     
            # Redirects to parent EPrint
            if( defined $doi_info->{generated_doi}->{redirects_to_parent} )
            {
                $redirect_value->appendChild( $self->html_phrase( "generated_doi:redirect:parent", url => $link ) );
            }
            else
            {             
                $redirect_value->appendChild( $link );
            }
        }
    }

    ## Reserve
    if( ( $doi_info->{generated_doi}->{state} eq "available" || $doi_info->{generated_doi}->{state} eq "draft" ) &&
        ( $self->allow_reservedoi ) )
    {
        $doi_table->appendChild( $self->render_reserve_row(
            $repo,
            $dataobj,
            $doi_info->{generated_doi},
        ) );
    }

    if( $no_problems == 0 )
    {
        ## Mint
        if( ( $doi_info->{generated_doi}->{state} eq "available" || $doi_info->{generated_doi}->{state} eq "draft" ) &&
            ( $self->allow_mintdoi ) )
        {
            $doi_table->appendChild( $self->render_mint_row( 
                $repo,
                $dataobj,
            ) );
        }

        ## Claim - for DOIs already minted
        if( $doi_info->{generated_doi}->{state} eq "findable" || $doi_info->{generated_doi}->{state} eq "registered" )
        {           

            my $claim;
            $claim = "claim" if( defined $doi_info->{generated_doi}->{url} ); # this generated DOI already exists, we're going to update it's metadata and URL to point to us, i.e. claim it as ours

            $claim = "reclaim" if( defined $doi_info->{generated_doi}->{redirects_to_dataobj} ); # this already points to us!

            $doi_table->appendChild( $self->render_update_url_row( 
                $repo,
                $dataobj,
                $doi_info->{generated_doi}->{doi},
                "generated_doi",
                $doi_info->{generated_doi}->{registered},
                $doi_info->{generated_doi}->{updated},
                $claim
            ) );
        }
    }

    return $div;
}

# Form and details for minting a brand new DOI
sub render_mint_row
{
    my( $self, $repo, $dataobj ) = @_;

    my $mint_row = $repo->make_element( "div", class => "ep_table_row" );
    my $mint_title = $mint_row->appendChild( $repo->make_element( "div", class => "ep_table_cell" ) );
    $mint_title->appendChild( $self->html_phrase( "mint_doi" ) );
    my $mint_value = $mint_row->appendChild( $repo->make_element( "div", class => "ep_table_cell" ) );
  
    my $form = $mint_value->appendChild( $self->render_form( "get" ) );
    $form->appendChild( $repo->render_hidden_field( "class", $dataobj->get_dataset_id ) );
    $form->appendChild( $repo->render_hidden_field( "dataobj", $dataobj->id ) );

    $form->appendChild( $repo->render_action_buttons(
        _order => [ "mintdoi" ],
        mintdoi => $repo->phrase( "Plugin/Screen/EPrint/Staff/CoinDOI:action:mintdoi:title" ) )
    );

    return $mint_row;
}


# Form and details for updating the metadata for a DOI
sub render_update_row
{
    my( $self, $repo, $dataobj, $doi, $registered, $updated ) = @_;

    my $update_row = $repo->make_element( "div", class => "ep_table_row" );
    my $update_title = $update_row->appendChild( $repo->make_element( "div", class => "ep_table_cell" ) );
    $update_title->appendChild( $self->html_phrase( "update_doi" ) );
    my $update_value = $update_row->appendChild( $repo->make_element( "div", class => "ep_table_cell" ) );

    # details on when the DOI was registered and updated
    if( defined $registered && defined $updated )
    {
        $update_value->appendChild( $self->html_phrase( "update_doi:timestamps",
            registered => EPrints::Time::render_date( $repo, $registered ),
            updated => EPrints::Time::render_date( $repo, $updated ),
        ) );
    }   
   
    my $form = $update_value->appendChild( $self->render_form( "get" ) );
    $form->appendChild( $repo->render_hidden_field( "class", $dataobj->get_dataset_id ) );
    $form->appendChild( $repo->render_hidden_field( "dataobj", $dataobj->id ) );

    # include the DOI if we're updating an existing DOI
    $form->appendChild( $repo->render_hidden_field( "doi", $doi ) ) if( defined $doi );

    $form->appendChild( $repo->render_action_buttons(
        _order => [ "updatedoi" ],
        updatedoi => $repo->phrase( "Plugin/Screen/EPrint/Staff/CoinDOI:action:updatedoi:title" ) )
    );

    return $update_row;
}

# Form and details for updating the metadata and URL of an existing DOI
sub render_update_url_row
{
    my( $self, $repo, $dataobj, $doi, $doi_type, $registered, $updated, $claim ) = @_;

    my $update_row = $repo->make_element( "div", class => "ep_table_row" );
    my $update_title = $update_row->appendChild( $repo->make_element( "div", class => "ep_table_cell" ) );
    $update_title->appendChild( $self->html_phrase( "update_doi" ) );
    my $update_value = $update_row->appendChild( $repo->make_element( "div", class => "ep_table_cell" ) );

    # details on when the DOI was registered and updated
    if( defined $registered && defined $updated )
    {
        $update_value->appendChild( $self->html_phrase( "update_doi:timestamps",
            registered => EPrints::Time::render_date( $repo, $registered ),
            updated => EPrints::Time::render_date( $repo, $updated ),
        ) );
    }   
   
    my $form = $update_value->appendChild( $self->render_form( "get" ) );
    $form->appendChild( $repo->render_hidden_field( "class", $dataobj->get_dataset_id ) );
    $form->appendChild( $repo->render_hidden_field( "dataobj", $dataobj->id ) );
    $form->appendChild( $repo->render_hidden_field( "doi_type", $doi_type ) );

    # include the DOI if we're updating an existing DOI
    $form->appendChild( $repo->render_hidden_field( "doi", $doi ) ) if( defined $doi );

    if( defined $claim )
    {
        $form->appendChild( $repo->render_action_buttons(
            _order => [ "updateurl" ],
            updateurl => $repo->phrase( "Plugin/Screen/EPrint/Staff/CoinDOI:action:$claim:title" ) )
);
    }
    else
    {
        $form->appendChild( $repo->render_action_buttons(
            _order => [ "updateurl" ],
            updateurl => $repo->phrase( "Plugin/Screen/EPrint/Staff/CoinDOI:action:updateurl:title" ) )
        );
    }

    return $update_row;
}


# Render Reserve options or details
sub render_reserve_row
{
    my( $self, $repo, $dataobj, $doi_info ) = @_;

    # get the url this reserved DOI would point to
    my $class = $dataobj->get_dataset_id;
    my $dataobj_uri = $dataobj->uri;
    if( $repo->can_call( $class."_landing_page" ) ) # landing page url override for documents (or eprints if needed)
    {
        $dataobj_uri = $repo->call( $class."_landing_page", $dataobj, $repo );
    }

    my $reserve_row = $repo->make_element( "div", class => "ep_table_row" );
    my $reserve_title = $reserve_row->appendChild( $repo->make_element( "div", class => "ep_table_cell" ) );
    $reserve_title->appendChild( $self->html_phrase( "reserve_doi:title" ) );
    my $reserve_value = $reserve_row->appendChild( $repo->make_element( "div", class => "ep_table_cell" ) );
    if( defined $doi_info->{created} )
    {
        $reserve_value->appendChild( $self->html_phrase( "reserve_doi:reserved",
            reserved => EPrints::Time::render_date( $repo, $doi_info->{created} ),
            updated => EPrints::Time::render_date( $repo, $doi_info->{updated} )
        ) );

        # update reserved item form
        my $form = $reserve_value->appendChild( $self->render_form( "get" ) );
        $form->appendChild( $repo->render_hidden_field( "dataobj", $dataobj->id ) );
        $form->appendChild( $repo->render_hidden_field( "class", $dataobj->get_dataset_id ) );
        $form->appendChild( $repo->render_hidden_field( "doi", $doi_info->{doi} ) );
        $form->appendChild( $repo->render_hidden_field( "url", $dataobj_uri ) );

        if( defined $doi_info->{redirects_to_dataobj} )
        {
            $form->appendChild( $repo->render_action_buttons(
                _order => [ "updatedoi" ],
                updatedoi => $self->phrase( "action:updatedoi:title" ) )
            );    
        }
        else
        {
            $form->appendChild( $repo->render_action_buttons(
                _order => [ "updateurl" ],
                updateurl => $self->phrase( "action:updateurl:title" ) )
            );    
        }
    }
    else
    {
        $reserve_value->appendChild( $self->html_phrase( "reserve_doi:desc" ) );

        my $form = $reserve_value->appendChild( $self->render_form( "get" ) );
        $form->appendChild( $repo->render_hidden_field( "dataobj", $dataobj->id ) );
        $form->appendChild( $repo->render_hidden_field( "class", $dataobj->get_dataset_id ) );
        $form->appendChild( $repo->render_hidden_field( "doi", $doi_info->{doi} ) );
        $form->appendChild( $repo->render_action_buttons(
            _order => [ "reservedoi" ],
            reservedoi => $self->phrase( "action:reservedoi:title" ) )
        );
    }
    return $reserve_row;
}

# show the results of looking up this eprint's title on datacite
sub render_datacite_dois
{
    my( $self, $dataobj ) = @_;

    my $repo = $self->{repository};

    my $div = $repo->make_element( "div", class => "datacite_dois datacite_section" );

    # title
    my $title_div = $div->appendChild( $repo->make_element( "div", class => "datacite_title" ) );
    $title_div->appendChild( $self->html_phrase( "datacite_dois:title" ) );

    my $datacite_response = $self->{processor}->{datacite_response};
    if( exists $datacite_response->{results} && scalar @{$datacite_response->{results}} > 0 ) # success, show results
    {
        my $results_div = $div->appendChild( $repo->make_element( "div", class => "datacite_results" ) );

        foreach my $result ( @{$datacite_response->{results}} )
        {
            $results_div->appendChild( $self->render_datacite_result( $dataobj, $result ) );
        }
    }
    elsif( exists $datacite_response->{error} ) # an actual error from the api
    {
        $div->appendChild( $self->html_phrase( "datacite_dois:error_message", code => $repo->make_text( $datacite_response->{code} ) ) );
    }
    else # no results... :(
    {
        $div->appendChild( $self->html_phrase( "datacite_dois:no_results", title => $dataobj->render_value( "title" ) ) );
    }

    return $div;
}

# show a datacite record, with a button allowing the user to select this doi for their eprint
sub render_datacite_result
{
    my( $self, $dataobj, $result ) = @_;

    my $repo = $self->{repository};

    my $div = $repo->make_element( "div", class => "datacite_result" );

    # datacite info
    my $datacite_div = $div->appendChild( $repo->make_element( "div", class => "datacite_info" ) );
    my $link = $repo->make_element( "a", href => $result->{url}, target => "_blank" );
    $link->appendChild( $repo->make_text( $result->{title} ) );

    $datacite_div->appendChild( $self->html_phrase( "datacite_dois:datacite_result",
        title => $link,
        date => $repo->make_text( $result->{date} ),
        publisher => $repo->make_text( $result->{publisher} ),
        doi => $repo->make_text( $result->{doi} ),
    ) );

    # claim button
    my $claim_div = $div->appendChild( $repo->make_element( "div", class => "datacite_claim" ) );
 
    my $form = $self->render_form;
    $form->appendChild( $repo->render_hidden_field( "doi", $result->{doi} ) );
    $form->appendChild( $repo->render_hidden_field( "class", $dataobj->get_dataset_id ) );
    $form->appendChild( $repo->render_hidden_field( "dataobj", $dataobj->id ) );
    $form->appendChild( $self->{session}->render_action_buttons(
        claimdoi => $self->{session}->phrase( "datacite_dois:claim_doi" ),
    ) );
    $claim_div->appendChild( $form );

    return $div;
}

# show the xml that the datacite export plugin produces and would send off to datacite when coining
sub render_xml
{
    my( $self, $dataobj ) = @_;

    my $repo = $self->{repository};

    my $pre = $repo->make_element( "pre" );

    my $xml = $dataobj->export( "DataCiteXML" );
    $pre->appendChild( $repo->make_text( $xml ) );

    return $pre;
}

sub allow_mintdoi
{
    my( $self ) = @_;
    return 0 unless $self->could_obtain_eprint_lock;
 
    my $repository = $self->{repository};
 
    my $eprint = $self->{processor}->{eprint}; 
 
    if (defined $repository->get_conf( "datacitedoi", "typesallowed")) {
      # Is this type of eprint allowed/denied coining?
      return 0 unless $repository->get_conf( "datacitedoi", "typesallowed",  $eprint->get_type);
    }

    return 0 unless $repository->get_conf( "datacitedoi", "eprintstatus",  $eprint->value( "eprint_status" ));

    # Don't show coinDOI button if a DOI is already set AND coining of custom doi is disallowed
    #return 0 if($dataobj->is_set($repository->get_conf( "datacitedoi", "eprintdoifield")) && 
    #    !$repository->get_conf("datacitedoi","allow_custom_doi"));
    #TODO don't allow the coinDOI button if a DOI is already registered (may require a db flag for successful reg)
    # Or maybe check with datacite api to see if a doi is registered
    
    return $self->allow( $repository->get_conf( "datacitedoi", "minters") );
}

sub action_mintdoi
{
    my( $self ) = @_;
    my $repo = $self->{repository};

    return undef if ( !defined $repo );

    # get the dataobj we want to update
    my $class = $repo->param( "class" );
    my $dataset = $repo->dataset( $class );
    my $dataobj = $dataset->dataobj( $repo->param( "dataobj" ) );
    return undef if ( !defined $dataobj );

    my $problems = $self->validate( $dataobj, 1 ); # double check for any problems
    if( scalar @{$problems} == 0 )
    {
        my $dataobj_id = $dataobj->id;
        $repo->dataset( "event_queue" )->create_dataobj({
            pluginid => "Event::DataCiteEvent",
            action => "datacite_doi",
            params => [ $dataobj->internal_uri ],
        }); 

        $self->add_result_message( "mintdoi" );
    }
}    

sub allow_updatedoi
{
    my( $self ) = @_;

    my $repo = $self->{repository};  

    # does the dataobj exist
    my $class = $repo->param( "class" );
    my $dataset = $repo->dataset( $class );
    my $dataobj = $dataset->dataobj( $repo->param( "dataobj" ) );

    return 0 if !defined $dataobj;

    my $dataobj_id = $dataobj->id;
    my $doi_info = $self->{processor}->{dois}->{$class}->{$dataobj_id};

    return 1 if $doi_info->{current_doi}->{state} eq "draft"; # fewer checks for draft dois

    # are there problems with it
    my $problems = $self->validate( $dataobj, 1);
    if( scalar @{$problems} > 0 )
    {
        return 0;
    }

    # is the doi info we're working with good?
    if( $self->check_update_only( $doi_info ) )
    {
        return 1;
    }

    return 0;
}

# used by rendering and the action to check if we are allowed to update the metadata for an object/doi combo
sub check_update_only
{
    my( $self, $doi_info ) = @_;

    if( defined $doi_info->{current_doi}->{repo_doi} && # one of our DOIs
        defined $doi_info->{current_doi}->{redirects_to_dataobj} &&  # it redirects to this record (or its tombstone)
        ( $doi_info->{current_doi}->{state} eq "registered" || $doi_info->{current_doi}->{state} eq "findable" ) )
    {
        return 1;
    }

    return 0;
}

sub action_updatedoi
{
    my( $self ) = @_;
    my $repo = $self->{repository};

    # get the dataobj we want to update
    my $class = $repo->param( "class" );
    my $dataset = $repo->dataset( $class );
    my $dataobj = $dataset->dataobj( $repo->param( "dataobj" ) );
    my $doi = $repo->param( "doi" );

    # create the update event
    my $dataobj_id = $dataobj->id;
    $repo->dataset( "event_queue" )->create_dataobj({
        pluginid => "Event::DataCiteEvent",
        action => "datacite_updatedoi",
        params => [ $dataobj->internal_uri, $doi ],
    }); 

    $self->add_result_message( "updatedoi" );
}    

sub allow_updateurl
{
    my( $self ) = @_;

    my $repo = $self->{repository};  

    # does the dataobj exist
    my $class = $repo->param( "class" );
    my $dataset = $repo->dataset( $class );
    my $dataobj = $dataset->dataobj( $repo->param( "dataobj" ) );
    my $doi_type = $repo->param( "doi_type" );

    return 0 if !defined $dataobj;
 
    # is the doi info we're working with good?
    my $dataobj_id = $dataobj->id;
    my $doi_info = $self->{processor}->{dois}->{$class}->{$dataobj_id};

    return 1 if $doi_info->{$doi_type}->{state} eq "draft"; # fewer checks for draft dois

    # are there problems with it
    my $problems = $self->validate( $dataobj, 1 );
    if( scalar @{$problems} > 0 )
    {
        return 0;
    }
 
    if( $self->check_update_metadata_and_url( $dataobj, $doi_info->{$doi_type} ) )
    {
        return 1;
    }
    print STDERR "fail\n";
    return 0;
}

# used by rendering and the action to check if we are allowed to update the metadata and url for an object/doi combo
sub check_update_metadata_and_url
{
    my( $self, $dataobj, $doi_info ) = @_;
    if( defined $doi_info->{repo_doi} && # one of our DOIs
        ( $doi_info->{state} eq "registered" || $doi_info->{state} eq "findable" ) &&
        $self->get_dataobj_url( $dataobj ) ) # and is there a url to use??
    {
        return 1;
    }

    return 0;
}

sub action_updateurl
{
    my( $self ) = @_;
    my $repo = $self->{repository};

    # get the dataobj we want to update
    my $class = $repo->param( "class" );
    my $dataset = $repo->dataset( $class );
    my $dataobj = $dataset->dataobj( $repo->param( "dataobj" ) );
    my $doi = $repo->param( "doi" );

    # get the url we want to update, we may have been passed this, or we may need to generate it
    my $url = $repo->param( "url" );
    $url = $self->get_dataobj_url( $dataobj ) unless defined $url;

    # create the update event
    my $dataobj_id = $dataobj->id;
    $repo->dataset( "event_queue" )->create_dataobj({
        pluginid => "Event::DataCiteEvent",
        action => "datacite_updatedoi",
        params => [ $dataobj->internal_uri, $doi, $url ],
    }); 

    $self->add_result_message( "updateurl" );
}    

sub allow_reservedoi
{
    my( $self ) = @_;
    return 0 unless $self->could_obtain_eprint_lock;
 
    my $repository = $self->{repository};
 
    my $eprint = $self->{processor}->{eprint}; 
 
    if (defined $repository->get_conf( "datacitedoi", "typesallowed")) {
      # Is this type of eprint allowed/denied coining?
      return 0 unless $repository->get_conf( "datacitedoi", "typesallowed",  $eprint->get_type);
    }

    return 0 unless $repository->get_conf( "datacitedoi", "reservestatus",  $eprint->value( "eprint_status" ));
  
    return $self->allow( $repository->get_conf( "datacitedoi", "minters") );
}

# reserve this eprint's DOI, i.e. add it as a draft DOI in DataCite
sub action_reservedoi
{
    my( $self ) = @_;
    my $repo = $self->{repository};

    # get the dataobj we want to update
    my $class = $repo->param( "class" );
    my $dataset = $repo->dataset( $class );
    my $dataobj = $dataset->dataobj( $repo->param( "dataobj" ) );

    return undef if ( !defined $dataobj );

    my $doi = $repo->param( "doi" );
    return undef if ( !defined $doi );

    my( $response_content, $response_code ) = EPrints::DataCite::Utils::reserve_doi( $repo, $dataobj, $doi );
}    

sub allow_claimdoi { return 1; }

# set the doi using a previously existing one we've retrieved from DataCite
sub action_claimdoi
{
    my( $self ) = @_;
    my $repo = $self->{repository};

    return undef if ( !defined $repo );

    # get the dataobj we want to update
    my $class = $repo->param( "class" );
    my $dataset = $repo->dataset( $class );
    my $dataobj = $dataset->dataobj( $repo->param( "dataobj" ) );
    return undef if ( !defined $dataobj );
    
    my $doi = $repo->param( "doi" );
    return undef if ( !defined $doi );

    my $doi_field = $self->{processor}->{$class.'_field'};
    $dataobj->set_value( $doi_field, $doi );
    $dataobj->commit();
}    

sub add_result_message
{
    my( $self, $message ) = @_;

    if( $message )
    {
        $self->{processor}->add_message( "message",
            $self->html_phrase( $message ) );
    }
    else
    {
        # Error?
        $self->{processor}->add_message( "error" );
    }

    $self->{processor}->{screenid} = "EPrint::View";
}

# Validate this datacite submission - this will call validate_datacite in lib/cfg.d/z_datacite_mapping.pl
sub validate
{
    my( $self, $dataobj, $display ) = @_;

    my @problems;

    my $class = $dataobj->get_dataset_id;

    my $validate_fn = "validate_datacite_$class";
    if( $self->{session}->can_call( $validate_fn ) )
    {
        push @problems, $self->{session}->call( 
            $validate_fn,
            $dataobj, 
            $self->{session}
        );
    }

    # show a message to the user if problems are reported
    if( $display && scalar @problems > 0 )
    {
        # display problems   
        my $dom_problems = $self->{session}->make_element("ul");
        foreach my $problem_xhtml ( @problems )
        {
            $dom_problems->appendChild( my $li = $self->{session}->make_element("li"));
            $li->appendChild( $problem_xhtml );
        }
        $self->workflow->link_problem_xhtml( $dom_problems, "EPrint::Edit" );
        $self->{processor}->add_message( "warning", $dom_problems );
    }

    return \@problems;
}

sub get_dataobj_url
{
    my( $self, $dataobj ) = @_;

    my $repo = $self->{repository};
    my $eprint = $self->{processor}->{eprint};

    # if mintable, get the landing page
    if( $repo->get_conf( "datacitedoi", "eprintstatus",  $eprint->value( "eprint_status" ) ) )
    {
        my $class = $dataobj->get_dataset_id;
        my $dataobj_uri = $dataobj->uri;
        if( $repo->can_call( $class."_landing_page" ) ) # landing page url override for documents (or eprints if needed)
        {
            $dataobj_uri = $repo->call( $class."_landing_page", $dataobj, $repo );
        }
        return $dataobj_uri;
    }
    else # get the tombstone uri if it exists
    {
        my $datacite_ds = $repo->dataset( "datacite" );
        my $dc = $datacite_ds->dataobj_class->get_datacite_record( $repo, $dataobj->get_dataset_id, $dataobj->id );
        my $tombstone_url = "";
        if( defined $dc )
        {
            return $dc->get_url;
       }   
    }
    return undef;
}

1;
