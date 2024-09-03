
sum :: ( operand: *int, amount: int )
{
    <<operand += amount;
}

run :: ()
{
    result := 0;
    sum( *result, 10 );
    sum( *result, 10 );
    sum( *result, 10 );
    sum( *result, 10 );
    sum( *result, 2 );
}
