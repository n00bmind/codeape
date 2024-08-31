Simp  :: #import "Simp";

// TODO Make an @implements(UpdateAndRenderFunc) note that's parsed by the metaprogram which will then
// #assert( type_of(UpdateAndRender) == UpdateAndRenderFunc );
#program_export
UpdateAndRender :: ( renderState: RenderState ) -> bool
{
    DrawOneFrame( renderState.renderWidth, renderState.renderHeight, renderState.defaultFont );

    DrawDebugCounters( renderState.renderWidth, renderState.renderHeight, renderState.monoSmallFont );

    return true;
}


#scope_file

#import "Basic";
#import "Math";

#load "interface.jai";


DrawOneFrame :: ( renderWidth: s32, renderHeight: s32, font: *Simp.Dynamic_Font )
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

        text_width := Simp.prepare_text(font, text);

        text_x := (renderWidth - text_width) / 2;
        text_y := renderHeight/2 + font.character_height/4;

        Simp.draw_prepared_text(font, text_x, text_y, color);
    }

}

// TODO Group in DebugCounters
frameAccum := 0;
lastCounterUpdateTimestamp: float64 = 0;
fpsText: string;

// TODO Non-release
DrawDebugCounters :: ( renderWidth: s32, renderHeight: s32, font: *Simp.Dynamic_Font )
{
    frameAccum += 1;

    now := seconds_since_init();
    if now > lastCounterUpdateTimestamp + 0.5
    {
        elapsedSecs := (now - lastCounterUpdateTimestamp);
        avgPerFrame := elapsedSecs / frameAccum;

        fpsText = sprint( "% fps (% ms.)",
            formatFloat( 1 / avgPerFrame, -1, 2 ), formatFloat( avgPerFrame * 1000, -1, 3 ) );

        lastCounterUpdateTimestamp = now;
        frameAccum = 0;
    }

    Simp.draw_text( font, 25, 25, fpsText );
}

