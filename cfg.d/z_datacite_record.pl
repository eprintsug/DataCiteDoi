{
no warnings;

package EPrints::DataObj::DataCite;

@EPrints::DataObj::DataCite::ISA = qw( EPrints::DataObj );

sub get_dataset_id { "datacite" }

sub get_url { shift->uri }

sub get_defaults
{
    my( $class, $session, $data, $dataset ) = @_;

    $data = $class->SUPER::get_defaults( @_[1..$#_] );

    return $data;
}

# retrieves a datacite record based on the dataset and id
sub get_datacite_record
{
    my( $class, $session, $datasetid, $objectid ) = @_;

    return $session->dataset( $class->get_dataset_id )->search(
        filters => [
            { meta_fields => [qw( datasetid )], value => $datasetid, match => "EX", },
            { meta_fields => [qw( objectid )], value => $objectid, match => "EX", },
        ],
    )->item( 0 );
}

# define the dataset
$c->{datasets}->{datacite} = {
    class => "EPrints::DataObj::DataCite",
    sqlname => "datacite",
    name => "datacite",
    columns => [qw( dataciteid, datasetid, objectid, citation )],
    index => 1,
    import => 1,
};


unshift @{$c->{fields}->{datacite}}, (
    {
        name => "dataciteid",
        type => "counter",
        required => 1,
        can_clone => 0,
        sql_counter => "dataciteid"
    },
    {
        name => "datasetid",
        type => "id",
        text_index => 0,
        import => 0,
        can_clone => 0,
    },
    {
        name => "objectid",
        type => "int",
        import => 0,
        can_clone => 0,
    },
    {
        name => "doi",
        type => "text",
        import => 0,
        can_clone => 0,
        render_value => 'EPrints::Extras::render_possible_doi',
    },
    {
        name => "citation",
        type => "longtext",
        import => 0,
        can_clone => 0,
        render_single_value => "EPrints::Extras::render_xhtml_field",
    },
);

push @{$c->{public_roles}}, qw{
    +datacite/view
};

}
