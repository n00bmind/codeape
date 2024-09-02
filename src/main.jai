Simp  :: #import "Simp";
#load "imgui_sdl_gl.jai";

main :: ()
{
    print( "Working directory is '%'\n", get_working_directory() );
    binPath := path_strip_filename( get_path_of_running_executable() );

    #if OS == .WINDOWS
    {
        Windows.SetProcessDPIAware();
        // Windows is very bad at thread-switching by default unless you do this. Sad.
        // Windows.timeBeginPeriod(1);
    }

    WANTED_MSAA :: 8;
    // On Linux, we need to pass the MSAA value to create_window
    mainWindow := create_window( 1920, 1080, "A Window", wanted_msaa = WANTED_MSAA );

    // On other operating systems, the MSAA value needs to be passed to *_create_context, so we
    // need to have an extra step here if you want MSAA.
    msaa := Simp.prepare_window( mainWindow, wanted_msaa = WANTED_MSAA );
    log( "Wanted MSAA: %\nChosen MSAA: %", WANTED_MSAA, msaa );

    renderState: RenderState;
    // Actual render size in pixels can be different from the window dimensions we specified above (for example on high-resolution displays on macOS/iOS).
    renderState.renderWidth, renderState.renderHeight = Simp.get_render_dimensions( mainWindow );

    Simp.set_render_target( mainWindow, .LEFT_HANDED );

    InitFonts( *renderState, renderState.renderHeight  );
    success := Simp.texture_load_from_file( *globalTestImage, "data/image_test.jpg" );
    assert(success);

    app: App;
    appDLLName := sprint( "%.dll", APP_DLL_NAME );
    appDLLPath := join( binPath, appDLLName );


    quit := false;
    while !quit
    {
        // Check whether we need to load app entry points from the DLL
        modtime, size, modtimeOk := file_modtime_and_size( appDLLPath );
        if modtimeOk && modtime > app.lastModtime
        {
            if LoadAppCode( *app, binPath, appDLLName )
                app.lastModtime = modtime;
        }
        if !app.updateAndRender
        {
            print( "FATAL :: No app to run!\n" );
            exit( 1 );
        }

        Input.update_window_events();

        for Input.get_window_resizes()
        {
            Simp.update_window( it.window );  // Simp will do nothing if it doesn't care about this window.

            if it.window == mainWindow
            {
                should_reinit := (it.width != renderState.renderWidth) || (it.height != renderState.renderHeight);

                renderState.renderWidth  = it.width;
                renderState.renderHeight = it.height;

                if should_reinit
                    InitFonts( *renderState, renderState.renderHeight );  // Resize the font for the new window size.
            }
        }

        for Input.events_this_frame
        {
            if it.type == .QUIT then
                quit = true;

            if it.type ==
            {
                case .KEYBOARD;
                    if it.key_pressed && it.key_code == .ESCAPE
                        quit = true;
            }
        }

        app.updateAndRender( renderState );

        Simp.swap_buffers(mainWindow);

        // sleep_milliseconds(10);
        reset_temporary_storage();
    }
}


#scope_file

#if OS == .WINDOWS
    Windows :: #import "Windows";

Input :: #import "Input";

#import "System";
#import "File_Utilities";
#import "Window_Creation";
#import "String";
#import "Basic";

#load "interface.jai";


App :: struct
{
    handle:             *void;
    lastModtime :       Apollo_Time;
    updateAndRender:    ( RenderState ) -> (quit: bool);
}

APP_DLL_NAME :: "app";

globalTestImage: Simp.Texture;


InitFonts :: ( renderState: *RenderState, renderHeight: s32 )
{
    renderState.defaultFont = Simp.get_font_at_size( ".", "data/fonts/OpenSans-BoldItalic.ttf", renderHeight / 24 );
    assert(renderState.defaultFont != null);
    renderState.monoSmallFont = Simp.get_font_at_size( ".", "data/fonts/SourceCodePro-Regular.ttf", renderHeight / 90 );
    assert(renderState.monoSmallFont != null);
}


tempDLLOrdinal := 0;

// TODO Move platform-specific bits to platform.jai
LoadAppCode :: ( app: *App, binPath: string, filename: string ) -> bool
{
    tempSrcPath := join( binPath, filename );
    // Make a copy of the DLL first so we don't lock it when loading it
    tempDLLName := tprint( "%.temp.%.dll", APP_DLL_NAME, tempDLLOrdinal );
    // The docs explicitly mention using '\', although it appears to work with '/' too..
    tempDLLPath := join( binPath, tempDLLName );

    print( "Trying to load app code from '%'..\n", tempDLLPath );

    if copy_file( tempSrcPath, tempDLLPath, silent = true )
    {
        oldAppHandle: Windows.HMODULE;
        if app.handle
            oldAppHandle = app.handle;

        app.handle = Windows.LoadLibraryA( tempDLLPath.data );
        if app.handle
        {
            loadedOk := true;

            app.updateAndRender = Windows.GetProcAddress( app.handle, "UpdateAndRender" );
            if( app.updateAndRender == null )
            {
                log_error( "Couldn't find function 'UpdateAndRender'" );
                loadedOk = false;
            }

            if( loadedOk )
            {
                Windows.FreeLibrary( oldAppHandle );
                tempDLLOrdinal = 1 - tempDLLOrdinal;

                print( "App code loaded OK\n" );
                // loadNoticeShown = false;
                return true;
            }
        }
        else
        {
            error, desc := get_error_value_and_string();
            log_error( "App code loading FAILED (%)!\n", desc );
        }
    }

    return false;
}

