
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
    nodes:          [..] AstNodeSlot;
    // procHeaders:    [..] AstRef(.ProcedureHeader);
    // procBodies:     [..] AstRef(.ProcedureBody);
    entryPointHeaderIndex:  s32;
    entryPointBodyIndex:    s32;
}

// This is used to convert back and forth to/from ast node pointers while serializing
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
    Block;
}



AstNode :: struct
{
    location: Source_Code_Location;
}

AstNodeSlot :: struct
{
    node: *AstNode;
    kind: AstNodeKind;
}

CheckInit :: ( slot: *AstNodeSlot, $T: Type, kind: AstNodeKind ) -> *T
{
    if slot.node == null
    {
        slot.node = New( T );
        slot.kind = kind;
    }

    result := cast(*T) slot.node;
    return result;
}

// TODO BLOCKER!! Seems like we cannot make this participate in overload resolution, since all Reflect() calls are compiled inside the module scope!

// NOTE Serialize nodes inline, preceded by their kind so we know how to read them back
// Reflect :: inline ( d: *AstNodeSlot, r: *BinaryReflectorGM ) -> ReflectResult
Reflect :: ( d: *AstNodeSlot, r: *BinaryWriterGM ) -> ReflectResult
{
    // TODO Still, this seems to compile it but not actually call into it!
    print( "Reflecting ast node %\n", d );

    Reflect( *d.kind, r );

    // TODO How do we collapse this down (& only switch once!)
    #if r.IsReading
    {
        if d.kind ==
        {
            case .ProcedureHeader; d.node = New( AstProcedureHeader );
            case .ProcedureBody;   d.node = New( AstProcedureBody );
            case .Block;           d.node = New( AstBlock );
        }
    }
    // if d.kind ==
    // {
    //     case .ProcedureHeader; return Reflect( cast(*AstProcedureHeader)d.node, r );
    //     case .ProcedureBody;   return Reflect( cast(*AstProcedureBody)d.node, r );
    //     case .Block;           return Reflect( cast(*AstBlock)d.node, r );
    // }

    return .Ok;
}

// Translate :: ( inputNode: *$T, slotOut: *AstNodeSlot,
//                 nodesMap: *Table(*Code_Node, s32), astNodes: *Bucket_Array(AstNodeSlot, $N) )
// {
//     assert( false, "Not implemented!" );
// }


AstProcedureHeader :: struct
{
    #as using base : AstNode;

    // arguments: [] *Code_Declaration;
    // returns:   [] *Code_Declaration;
    name: string;
}

Translate :: ( inputNode: *Code_Procedure_Header, slotOut: *AstNodeSlot,
                nodesMap: *Table(*Code_Node, s32), astNodes: *Bucket_Array(AstNodeSlot, $N) )
{
    target := CheckInit( slotOut, AstProcedureHeader, .ProcedureHeader );
    // TODO 
}

AstProcedureBody :: struct
{
    #as using base : AstNode;

    block:       AstRef(.Block);
    header:      AstRef(.ProcedureHeader);
}

Translate :: ( inputNode: *Code_Procedure_Body, slotOut: *AstNodeSlot,
                nodesMap: *Table(*Code_Node, s32), astNodes: *Bucket_Array(AstNodeSlot, $N) )
{
    target := CheckInit( slotOut, AstProcedureBody, .ProcedureBody );
    target.block = xx CreateOrUpdateAstNodeFor( inputNode.block, nodesMap, astNodes );
    target.header = xx CreateOrUpdateAstNodeFor( inputNode.header, nodesMap, astNodes );
}

AstBlock :: struct
{
    #as using base : AstNode;

    // TODO Should store the actual kinds here..
    statements: [] AstRef(.Unknown);
    parent:     AstRef(.Block);
    blockType:  u32;
}

Translate :: ( inputNode: *Code_Block, slotOut: *AstNodeSlot,
                nodesMap: *Table(*Code_Node, s32), astNodes: *Bucket_Array(AstNodeSlot, $N) )
{
    target := CheckInit( slotOut, AstBlock, .Block );
    // TODO 
}


CreateOrUpdateAstNodeFor :: ( input: *$T, nodesMap: *Table(*Code_Node, s32), astNodes: *Bucket_Array(AstNodeSlot, $N) ) -> AstRefBase
{
    slotPtr: *AstNodeSlot = null;

    indexPtr := table_find_pointer( nodesMap, input );
    if indexPtr
    {
        // Update existing target node
        // TODO Curious if we do ever hit this case?
        slotPtr = *(<<astNodes)[ <<indexPtr ];
    }
    else
    {
        assert( astNodes.count < (1 << 24), "Too many AST nodes" );
        newIndex := cast(s32) astNodes.count;

        slotPtr = find_and_occupy_empty_slot( astNodes, initialize=true );
        indexPtr = table_add( nodesMap, input, newIndex );
    }

    Translate( input, slotPtr, nodesMap, astNodes );

    return .{ <<indexPtr, slotPtr.kind };
}

