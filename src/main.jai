#if OS == .WINDOWS
    Windows :: #import "Windows";

globalMainWindow: Window_Type;

image_test: Simp.Texture;

main :: ()
{
    #if OS == .WINDOWS
    {
        Windows.SetProcessDPIAware();
        // Windows is very bad at thread-switching by default unless you do this. Sad.
        // Windows.timeBeginPeriod(1);
    }

    WANTED_MSAA :: 8;
    // On Linux, we need to pass the MSAA value to create_window
    globalMainWindow = create_window( 1920, 1080, "A Window", wanted_msaa = WANTED_MSAA );

    // On other operating systems, the MSAA value needs to be passed to *_create_context, so we
    // need to have an extra step here if you want MSAA.
    msaa := Simp.prepare_window( globalMainWindow, wanted_msaa = WANTED_MSAA );
    log( "Wanted MSAA: %\nChosen MSAA: %", WANTED_MSAA, msaa );

    // Actual render size in pixels can be different from the window dimensions we specified above (for example on high-resolution displays on macOS/iOS).
    renderWidth, renderHeight := Simp.get_render_dimensions( globalMainWindow );

    Simp.set_render_target( globalMainWindow, .LEFT_HANDED );

    InitFonts(  renderHeight  );
    success := Simp.texture_load_from_file( *image_test, "data/image_test.jpg" );
    assert(success);

    quit := false;
    while !quit
    {
        Input.update_window_events();

        for Input.get_window_resizes()
        {
            Simp.update_window( it.window );  // Simp will do nothing if it doesn't care about this window.

            if it.window == globalMainWindow
            {
                should_reinit := (it.width != renderWidth) || (it.height != renderHeight);

                renderWidth  = it.width;
                renderHeight = it.height;

                if should_reinit
                    InitFonts( renderHeight );  // Resize the font for the new window size.
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

        DrawOneFrame( renderWidth, renderHeight );
        DrawDebugCounters( renderWidth, renderHeight );

        Simp.swap_buffers(globalMainWindow);

        // sleep_milliseconds(10);
        reset_temporary_storage();
    }
}

DrawOneFrame :: ( renderWidth: s32, renderHeight: s32 )
{
    Simp.clear_render_target(.15, .15, .2, 1);

    Simp.set_shader_for_color();

    time := seconds_since_init();

    // This is our own code to set up a rotating square:
    {
        b := cast(float)renderHeight / 10;
        p: Vector2;
        p.x = cast(float)(renderWidth  / 2);
        p.y = cast(float)(renderHeight / 2);

        theta := cast(float) fmod_cycling(time, TAU);

        ct := cos(theta);
        st := sin(theta);

        w := Vector2.{b*ct, b*st};
        h := Vector2.{b*st, -b*ct};

        p0 := p - w - h;
        p1 := p + w - h;
        p2 := p + w + h;
        p3 := p - w + h;

        a :: 1.0;
        c0 := Vector4.{1, 0, 0, a};
        c1 := Vector4.{0, 1, 0, a};
        c2 := Vector4.{0, 0, 1, a};
        c3 := Vector4.{1, 1, 1, a};

        Simp.immediate_quad(p0, p1, p2, p3, c0, c1, c2, c3);
    }

    // Draw some text.
    {
        // Do a bunch of wacky math to figure out the text color.
        theta := cast(float) fmod_cycling(time*3, TAU);

        color: Vector4;
        color.x = cos(theta)*.5+.5;
        Clamp(*color.x, 0, 1);
        color.y = 1;
        color.z = sin(theta)*-.5+.5;
        Clamp(*color.z, 0, 1);
        color.w = 1;

        // Now, to draw the text:
        text := "Simp!";

        // We could just call Simp.draw_text to draw text! But we want to know the width
        // so that we can center the text, and to find the width, we have to do all the
        // text layout. So it makes sense just to draw the prepared text after that,
        // so there's a special routine, "draw_prepared_text", that draws the thing
        // you just prepared and got the width of.

        text_width := Simp.prepare_text(globalDefaultFont, text);

        text_x := (renderWidth - text_width) / 2;
        text_y := renderHeight/2 + globalDefaultFont.character_height/4;

        Simp.draw_prepared_text(globalDefaultFont, text_x, text_y, color);
    }


    if image_test.width && image_test.height
    {
        // Draw the texture test, to make sure
        // it comes out right-side-up.

        Simp.set_shader_for_images(*image_test);
        Simp.immediate_begin();

        w := renderHeight/8.0;
        y0 := cast(float) renderHeight;

        Simp.immediate_quad(.{0, y0-w}, .{w, y0-w}, .{w, y0}, .{0, y0});
        Simp.immediate_flush();
    }
}


// TODO Non-release
DrawDebugCounters :: ( renderWidth: s32, renderHeight: s32 )
{
    globalFrameCounter += 1;

    now := seconds_since_init();
    if now > globalLastCounterUpdateTimestamp + 0.5
    {
        elapsedSecs := (now - globalLastCounterUpdateTimestamp);
        avgPerFrame := elapsedSecs / globalFrameCounter;

        globalFpsText = sprint( "% fps (% ms.)",
            formatFloat( 1 / avgPerFrame, -1, 2 ), formatFloat( avgPerFrame * 1000, -1, 3 ) );

        globalLastCounterUpdateTimestamp = now;
        globalFrameCounter = 0;
    }

    Simp.draw_text( globalMonoSmallFont, 25, 25, globalFpsText );
}

InitFonts :: ( renderHeight: s32 )
{
    globalDefaultFont = Simp.get_font_at_size( ".", "data/fonts/OpenSans-BoldItalic.ttf", renderHeight / 24 );
    assert(globalDefaultFont != null);
    globalMonoSmallFont = Simp.get_font_at_size( ".", "data/fonts/SourceCodePro-Regular.ttf", renderHeight / 90 );
    assert(globalDefaultFont != null);
}

globalDefaultFont: *Simp.Dynamic_Font;
globalMonoSmallFont: *Simp.Dynamic_Font;
// TODO Group in DebugCounters
globalFrameCounter := 0;
globalLastCounterUpdateTimestamp: float64 = 0;
globalFpsText: string;

Simp  :: #import "Simp";
Input :: #import "Input";

#import "Window_Creation";

#import "Basic";
#import "Math";
