// TODO Learn to generate bindings for updated ImGui version
// TODO Learn to generate bindings for latest SDL 3
// TODO Statically link both
#load "imgui_sdl_gl.jai";

main :: ()
{
    #if OS == .WINDOWS
    {
        // TODO Is this necessary with the SDL?
        Windows.SetProcessDPIAware();
        // Windows is very bad at thread-switching by default unless you do this. Sad.
        // Windows.timeBeginPeriod(1);
    }

    SDL_Init(SDL_INIT_VIDEO);

    window := SDL_CreateWindow("ImGui SDL2+OpenGL example", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 1280, 720, SDL_WINDOW_OPENGL|SDL_WINDOW_RESIZABLE);

    // Check that the window was successfully created
    if window == null {
        // In the case that the window could not be made...
        log_error("Could not create window: %", to_string(SDL_GetError()));
        exit(1);
    }

    // TODO SDL version?
    log("ImGui v%", to_string(ImGui.GetVersion()));

    print( "Working directory is '%'\n", get_working_directory() );
    binPath := path_strip_filename( get_path_of_running_executable() );

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);

    gl_context := SDL_GL_CreateContext(window);
    if !gl_context {
        log_error("Could not create OpenGL context: %", to_string(SDL_GetError()));
        exit(1);
    }

    gl_load(*gl, SDL_GL_GetProcAddress);

    imgui_context := ImGui.CreateContext();

    // Setup ImGui binding
    ImGui_ImplSdl_Init(window);

    // Setup style
    ImGui.StyleColorsClassic();
    //ImGui.StyleColorsLight();

    io := ImGui.GetIO();

    show_demo_window := true;

    app: App;
    appDLLName := sprint( "%.dll", APP_DLL_NAME );
    appDLLPath := join( binPath, appDLLName );

    appMemory: AppMemory;
    appMemory.imGuiContext = imgui_context;

    renderState: RenderState;

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

        // You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear imgui wants to use your inputs.
        // - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application.
        // - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main application.
        // Generally you may always pass all inputs to dear imgui, and hide them from your application based on those two flags.
        event: SDL_Event;
        while SDL_PollEvent(*event) {
            ImGui_ImplSdl_ProcessEvent(*event);
            if event.type == SDL_QUIT   quit = true;
            if event.type == SDL_WINDOWEVENT && event.window.event == SDL_WINDOWEVENT_CLOSE && event.window.windowID == SDL_GetWindowID(window) {
                quit = true;
            }
        }
        ImGui_ImplSdl_NewFrame(window);
        // Start the frame. This call will update the io.WantCaptureMouse, io.WantCaptureKeyboard flag that you can use to dispatch inputs (or not) to your application.
        ImGui.NewFrame();

        // 3. Show the ImGui demo window. Most of the sample code is in ImGui.ShowDemoWindow().
        if show_demo_window {
            ImGui.SetNextWindowPos(.{650, 20}, ImGui.Cond.FirstUseEver, .{0,0}); // Normally user code doesn't need/want to call this because positions are saved in .ini file anyway. Here we just want to make the demo initial state a bit more friendly!
            ImGui.ShowDemoWindow(*show_demo_window);
        }

        if ImGui.GetMouseCursor() == {
            case .Arrow;         SDL_SetCursor(cursor_arrow);
            case .TextInput;     SDL_SetCursor(cursor_text_input);
            case .Hand;          SDL_SetCursor(cursor_move);
            case .ResizeNS;      SDL_SetCursor(cursor_resize_ns);
            case .ResizeEW;      SDL_SetCursor(cursor_resize_ew);
            case .ResizeNESW;    SDL_SetCursor(cursor_resize_nesw);
            case .ResizeNWSE;    SDL_SetCursor(cursor_resize_nwse);
        }

        app.updateAndRender( appMemory, renderState );

        // Rendering
        ImGui.Render();
        glViewport(0, 0, xx io.DisplaySize.x, xx io.DisplaySize.y);
        ImGui_ImplSdl_RenderDrawLists(ImGui.GetDrawData());
        SDL_GL_SwapWindow(window);

        reset_temporary_storage();
    }

    // Cleanup
    ImGui_ImplSdl_Shutdown();
    ImGui.DestroyContext(imgui_context);
    SDL_GL_DeleteContext(gl_context);
    SDL_DestroyWindow(window);
    SDL_Quit();
}


#scope_file

#if OS == .WINDOWS
    Windows :: #import "Windows";

#import "System";
#import "File_Utilities";
// #import "Window_Creation";
#import "String";
// #import "Basic";

#load "interface.jai";


App :: struct
{
    handle:             *void;
    lastModtime :       Apollo_Time;
    updateAndRender:    ( AppMemory, RenderState ) -> (quit: bool);
}

APP_DLL_NAME :: "app";


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

