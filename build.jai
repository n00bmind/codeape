#import "Basic";
#import "Compiler";
#import "System";
#import "String";

build :: ()
{
    set_build_options_dc( .{do_output=false} );  // No executable for this workspace.

    // The compiler will set the CWD to the directory containing the current file
    path := get_working_directory();
    print( "Working directory for 'build' metaprogram: '%'\n", path );

    global_options := get_build_options();
    global_options.output_path = "bin";
    global_options.intermediate_path = "bin";


    build_release := false;
    args := global_options.compile_time_command_line;

    // NOTE These arguments have to be specified last, after any arguments for the compiler itself, separated with a hyphen, e.g:
    // jai build.jai - release
    for arg: args
    {
        if arg ==
        {
            case "release"; #through;
            case "-release"; #through;
            case "--release";
                build_release = true;
                print( "Building release version.\n" );
        }
    }



    // Application DLL
    {
        w := compiler_create_workspace( "Application library" );
        options := global_options;
        options.output_type = .DYNAMIC_LIBRARY;
        options.output_executable_name = "app";
        // TODO Actually, for release we wouldn't even want a separate dll
        if build_release
        {
            set_optimization( *options, .VERY_OPTIMIZED, true );
            options.backend =.LLVM;
        }
        else
        {
            set_optimization( *options, .DEBUG, true );
            options.backend =.X64;
        }
        set_build_options( options, w );

        add_build_file( "src/app.jai", w );
    }

    // Main executable
    {
        w := compiler_create_workspace( "Main executable" );
        options := global_options;
        options.output_type = .EXECUTABLE;
        options.output_executable_name = "run";
        if build_release
        {
            set_optimization( *options, .VERY_OPTIMIZED, true );
            options.backend =.LLVM;
        }
        else
        {
            set_optimization( *options, .DEBUG, true );
            options.backend =.X64;
        }
        set_build_options( options, w );

        add_build_file( "src/main.jai", w );
    }
}
#run build();

