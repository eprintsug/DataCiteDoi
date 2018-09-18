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
        return 0 unless $repository->get_conf( "datacitedoi", "eprintstatus",  $dataobj->value( "eprint_status" ));

	if (defined $repository->get_conf( "datacitedoi", "typesallowed")) {
		# Is this type of eprint allowed/denied coining?
		return 0 unless $repository->get_conf( "datacitedoi", "typesallowed",  $dataobj->get_type);
	}

  # Don't show coinDOI button if a DOI is already registered 
  return 0 if $dataobj->is_set($repository->get_conf( "datacitedoi", "eprintdoifield"));
  return $self->allow( "eprint/edit:editor" );
}

sub action_coindoi
{
	my( $self ) = @_;
 
       my $repository = $self->{repository};
 
       return undef if (!defined $repository);

	my $eprint = $self->{processor}->{eprint};

	if (defined $eprint) {
			my $eprint_id = $eprint->id;
                        
            	       $repository->dataset( "event_queue" )->create_dataobj({
					pluginid => "Event::DataCiteEvent",
					action => "datacite_doi",
					params => [$eprint->internal_uri],
		        }); 

                        $self->add_result_message( 1 );
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

1;
