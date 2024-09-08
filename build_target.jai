#import "Compiler";
#import "Basic";

#import "reflector";


build :: ()
{
    set_build_options_dc( .{do_output=false} );  // No executable for this workspace.

    // The compiler will set the CWD to the directory containing the current file
    path := get_working_directory();
    print( "Working directory for 'build' metaprogram: '%'\n", path );

    global_options := get_build_options();
    global_options.output_path = "bin/target";
    global_options.intermediate_path = "bin/target";

    args := global_options.compile_time_command_line;

    // Application DLL
    {
        w := compiler_create_workspace( "Inspected target" );

        // I assume this must happen before we add files to the compilation?
        compiler_begin_intercept( w );

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

        // TODO Get path from command line
        add_build_file( "src/test.jai", w );

        MessageLoop( w );

        compiler_end_intercept(w);
    }

}
#run build();


#scope_file

#import "Hash_Table";
#load "src/ast.jai";

MessageLoop :: ( w: Workspace )
{
    while true
    {
        message := compiler_wait_for_message();
        if message.kind ==
        {
        case .TYPECHECKED;
            typechecked := cast(*Message_Typechecked) message;

            for tc: typechecked.procedure_bodies
            {
                CreateOrUpdateAstNodeFor( tc.expression, *globalNodesMap, *globalAstNodes );
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

    // TODO Do we need to be inside the msg loop for some reason?
    results: AST;

    writer: BinaryWriterGM;
    result := Reflect( *results, *writer );
    log( "Writer result: %. Wrote % bytes\n", result, writer.buffer.size );
}

globalAstNodes: [..] *AstNode;
globalNodesMap: Table(*Code_Node, s32);
