package EPrints::Plugin::Screen::EPrint::Staff::CoinDOI;

#use EPrints::Plugin::Screen::EPrint;

@ISA = ( 'EPrints::Plugin::Screen::EPrint' );

use strict;

sub new
{
        my( $class, %params ) = @_;

        my $self = $class->SUPER::new(%params);

        #       $self->{priv} = # no specific priv - one per action

        $self->{actions} = [qw/ coindoi /];

        $self->{appears} = [ {
                place => "eprint_editor_actions",
                action => "coindoi",
                position => 1977,
        }, ];

        return $self;
}

sub obtain_lock
{
        my( $self ) = @_;

        return $self->could_obtain_eprint_lock;
}

sub about_to_render
{
        my( $self ) = @_;

        $self->EPrints::Plugin::Screen::EPrint::View::about_to_render;
}

sub allow_coindoi
{
    my( $self ) = @_;

    return 0 unless $self->could_obtain_eprint_lock;
 
	my $repository = $self->{repository};
	#TODO a version that works for documents too
	my $dataobj = $self->{processor}->{eprint}; 
    if (defined $repository->get_conf( "datacitedoi", "typesallowed")) {
      # Is this type of eprint allowed/denied coining?
      return 0 unless $repository->get_conf( "datacitedoi", "typesallowed",  $dataobj->get_type);
    }
    return 0 unless $repository->get_conf( "datacitedoi", "eprintstatus",  $dataobj->value( "eprint_status" ));
    # Don't show coinDOI button if a DOI is already set AND coining of custom doi is disallowed
    return 0 if($dataobj->is_set($repository->get_conf( "datacitedoi", "eprintdoifield")) && 
        !$repository->get_conf("datacitedoi","allow_custom_doi"));
	#TODO don't allow the coinDOI button if a DOI is already registered (may require a db flag for successful reg)
    # Or maybe check with datacite api to see if a doi is registered
    return $self->allow( $repository->get_conf( "datacitedoi", "minters") );
}

sub action_coindoi
{
    my( $self ) = @_;
 
    my $repository = $self->{repository};

    return undef if (!defined $repository);

    $self->{processor}->{redirect} = $self->redirect_to_me_url()."&_current=2";

    my $eprint = $self->{processor}->{eprint};

    if (defined $eprint) {
        

        my $problems = $self->validate($eprint);
            
        if( scalar @{$problems} > 0 )
        {
            my $dom_problems = $self->{session}->make_element("ul");
            foreach my $problem_xhtml ( @{$problems} )
            {
                $dom_problems->appendChild( my $li = $self->{session}->make_element("li"));
                $li->appendChild( $problem_xhtml );
            }
            $self->workflow->link_problem_xhtml( $dom_problems, "EPrint::Edit" );
            $self->{processor}->add_message( "warning", $dom_problems );


        }else{

            my $eprint_id = $eprint->id;
                        
            $repository->dataset( "event_queue" )->create_dataobj({
                pluginid => "Event::DataCiteEvent",
                action => "datacite_doi",
                params => [$eprint->internal_uri],
            }); 

            $self->add_result_message( 1 );
        }
    }
}    

sub add_result_message
{
        my( $self, $ok ) = @_;

        if( $ok )
        {
                $self->{processor}->add_message( "message",
                        $self->html_phrase( "coiningdoi" ) );
        }
        else
        {
                # Error?
                $self->{processor}->add_message( "error" );
        }

        $self->{processor}->{screenid} = "EPrint::View";
}

# Validate this datacite submission this will call validate_datacite in cfg.d/z_datacite.pl
sub validate
{
	my( $self, $eprint ) = @_;

	my @problems;

	my $validate_fn = "validate_datacite";
	if( $self->{session}->can_call( $validate_fn ) )
	{
		push @problems, $self->{session}->call( 
			$validate_fn,
			$eprint, 
			$self->{session}  );
	}

	return \@problems;
}


1;
