
// Map the relevant structs in Compiler.jai to our own serializable representation

// Main reason to not use those directly is we're never gonna exhaustively map everything, as a lot of it is gonna fall out of scope,
// but also we want to provide a layer of isolation against compiler data changes via our own reflected field ids etc.
// TODO An important question here is:
// how do we reliably detect changes in the Compiler.jai datastructures without manually running a diff on every update?

// Obviously this still needs more thought but:
// I think in principle we'd like to strive for keeping this pretty much a 1to1 mapping to the public structs in Compiler.jai
// because that'd mean the visual editor should be able to edit this binary AST and feed it back to us (the metaprogram) to recompile,
// which could in principle allow us to do incremental AST modifications via compiler_get_code using the actual compiler structs.

// In fact.. hear me out.. what would be *really* awesome is to have this metaprogram be constantly running in the background and
// communicate continuously via shared memory with the visual editor GUI!?   **MINDBLOWN**



AST :: struct
{
    procHeaders:    [..] AstRef(.ProcedureHeader);
    procBodies:     [..] AstRef(.ProcedureBody);
    entryPointHeaderIndex:  s32;
    entryPointBodyIndex:    s32;
}

// This is used to convert back and forth to/from ast node pointers while serilizing
// TODO Pack this in a u32, probably
AstRefBase :: struct
{
    index: s32;
    kind: AstNodeKind;
}

AstRef :: struct( $Kind: AstNodeKind )
{
    #as using base : AstRefBase;
    base.kind = Kind;
}

// TODO Assign actual immutable enum values when this stabilizes a little
AstNodeKind :: enum u8
{
    Unknown;
    ProcedureHeader;
    ProcedureBody;
}



AstNode :: struct
{
    location: Source_Code_Location;
}

AstProcedureHeader :: struct
{
    #as using base : AstNode;

    arguments: [] *Code_Declaration;
    returns:   [] *Code_Declaration;
}
