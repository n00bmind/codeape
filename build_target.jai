#import "Compiler";
#import "Basic";
#import "Bucket_Array";

#import "reflector";


build :: ()
{
    set_build_options_dc( .{do_output=false} );  // No executable for this workspace.

    // The compiler will set the CWD to the directory containing the current file
    path := get_working_directory();
    print( "Working directory for 'build' metaprogram: '%'\n", path );

    // TODO Not sure why but this workspace still emits the added strings in a hidden .build/ folder..
    global_options := get_build_options();
    global_options.output_path = "bin/target";
    global_options.intermediate_path = "bin/target";

    args := global_options.compile_time_command_line;

    // Application DLL
    {
        w := compiler_create_workspace( "Inspected target" );

        options := global_options;
        // TODO Eventually we'll want a static library too
        options.output_type = .DYNAMIC_LIBRARY;
        options.output_executable_name = "target";

        // if build_release
        // {
        //     set_optimization( *options, .VERY_OPTIMIZED, true );
        //     options.backend =.LLVM;
        // }
        // else
        {
            set_optimization( *options, .DEBUG, true );
            options.backend =.X64;
        }
        set_build_options( options, w );

        // I assume this must happen before we add files to the compilation?
        compiler_begin_intercept( w );

        // TODO Get path from command line
        add_build_file( "src/test.jai", w );

        results: AST;
        MessageLoop( w, *results );

        compiler_end_intercept(w);

        // Write results to disk
        // TODO In the future this could probably go through shared memory directly
        writer: BinaryWriterGM;
        result := Reflect( *results, *writer );
        log( "\n\nWriter result: %. Wrote % bytes\n", result, writer.buffer.size );
    }

    // NOTE NOTE At the moment we don't care about deallocating all the nodes and just let them leak..
}
#run build();


// #scope_file

#import "Hash_Table";
#load "src/ast.jai";

MessageLoop :: ( w: Workspace, targetAST: *AST )
{
    // TODO Do we want to separate the 'kind' attributes here into their own array for better packing?
    astNodes: Bucket_Array(AstNodeSlot, 1024);
    nodesMap: Table(*Code_Node, s32);

    while true
    {
        message := compiler_wait_for_message();
        if message.kind ==
        {
        case .TYPECHECKED;
            typechecked := cast(*Message_Typechecked) message;

            for tc: typechecked.procedure_headers
            {
                header := cast(*Code_Procedure_Header) tc.expression;
                ref := CreateOrUpdateAstNodeFor( header, *nodesMap, *astNodes );

                if header.name == "run"
                    targetAST.entryPointHeaderIndex = ref.index;
            }

            for tc: typechecked.procedure_bodies
            {
                body := cast(*Code_Procedure_Body) tc.expression;
                ref := CreateOrUpdateAstNodeFor( body, *nodesMap, *astNodes );

                assert( body.header != null, "Body should have a header by now" );

                if body.header.name == "run"
                    targetAST.entryPointBodyIndex = ref.index;
            }

        case .PHASE;
            phase := cast(*Message_Phase) message;
            if phase.phase ==
            {
                case .TYPECHECKED_ALL_WE_CAN;
            }

        case .COMPLETE;
            break;
        }
    }

    // Copy all nodes to a linear array in the target
    array_resize( *targetAST.nodes, astNodes.count, initialize = false );

    targetIdx := 0;
    for bucket, bIdx: astNodes.all_buckets
    {
        // We don't ever leave gaps in the astNodes array, so just memcpy each bucket
        memcpy( targetAST.nodes.data + targetIdx, bucket.data.data, bucket.count * size_of(astNodes.type) );
        targetIdx += bucket.count;
    }

    msg := tprint( "Expected to copy % items, but copied %!", astNodes.count, targetIdx );
    assert( targetIdx == astNodes.count, msg );
}

