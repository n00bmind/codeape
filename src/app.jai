ImGui :: #import "ImGui";

f :float = 0.0;
clear_color := Vector4.{0.45, 0.55, 0.60, 1.00};

// TODO Make an @implements(UpdateAndRenderFunc) note that's parsed by the metaprogram which will then
// #assert( type_of(UpdateAndRender) == UpdateAndRenderFunc );
#program_export
UpdateAndRender :: ( appMemory: AppMemory, renderState: RenderState ) -> bool
{
    // TODO Set global allocators
    ImGui.SetCurrentContext( appMemory.imGuiContext );
    io := ImGui.GetIO();

    #if true
    {
        ImGui.Text("Hello, world!");                                // Some text (you can use a format string too)
        ImGui.Text("Hello, jai-style print: %, %!", 25, "Striiing");                                // Some text (you can use a format string too)
        ImGui.TextColored(.{1.0, 0, 0, 1.0}, "Hello, colored print world: %, %!", 25, "Striiing");
        ImGui.TextDisabled("Disbled formatted text: %, %!", 25, "Striiing");
        ImGui.SliderFloat("float", *f, 0.0, 1.0, "%.3f");                   // Edit 1 float as a slider from 0.0f to 1.0f
        ImGui.ColorEdit3("clear color", *clear_color.xyz.component);  // Edit 3 floats as a color
        ImGui.Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0 / io.Framerate, io.Framerate);
    }


    // Rendering
    glClearColor(clear_color.x, clear_color.y, clear_color.z, clear_color.w);
    glClear(GL_COLOR_BUFFER_BIT);

    // DrawDebugCounters( renderState.renderWidth, renderState.renderHeight, renderState.monoSmallFont );

    return true;
}


#scope_file

#import "Basic";
#import "Math";
#import "GL";

#load "interface.jai";



// TODO Group in DebugCounters
frameAccum := 0;
lastCounterUpdateTimestamp: float64 = 0;
fpsText: string;

// TODO Non-release
// DrawDebugCounters :: ( renderWidth: s32, renderHeight: s32, font: *Simp.Dynamic_Font )
// {
//     frameAccum += 1;
//
//     now := seconds_since_init();
//     if now > lastCounterUpdateTimestamp + 0.5
//     {
//         elapsedSecs := (now - lastCounterUpdateTimestamp);
//         avgPerFrame := elapsedSecs / frameAccum;
//
//         fpsText = sprint( "% fps (% ms.)",
//             formatFloat( 1 / avgPerFrame, -1, 2 ), formatFloat( avgPerFrame * 1000, -1, 3 ) );
//
//         lastCounterUpdateTimestamp = now;
//         frameAccum = 0;
//     }
//
//     Simp.draw_text( font, 25, 25, fpsText );
// }

