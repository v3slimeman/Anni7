#version 130

uniform mat2x4    color_xform;
uniform sampler2D palettetex;
uniform sampler2D framebuf;
uniform float     palette;
uniform vec2      screensize;
uniform float     timer;
uniform float     waterheight;
uniform float     playerglow_strength;
uniform vec2      playerPos;
uniform float     level_param;

uniform vec4 light0;
uniform vec4 light1;
uniform vec4 light2;
uniform vec4 light3;
uniform vec4 light4;
uniform vec4 light5;
uniform vec4 light6;
uniform vec4 light7;

varying vec2 worldPos;
varying vec2 blurcoords[25];
varying vec2 screencoords;
varying vec2 ratio;

const vec4  light_color = vec4(0.352, 0.196, 0.482, 0.8); // the color of the light emitted from the water
const vec4  glow_color = vec4(0.352, 0.196, 0.482, 0.0);  // the color of the glow emitted from the water
const float glow_strength = 2;                            // how strong the glow effect is
const float glow_threshold = 0.1;                         // how bright the green channel needs to be to trigger a glow
const float glow_distance = 0.0015;                       // size of the glow
const float overexpose = 0.25;                            // colors more than full bright bleed into other channels to make stuff whiter
const float light_distance = 3;                           // less = farther distance

//
// caching these values for potential optimisation boost
//

const float aspect_div = 1280.0 / 720.0;

const float frag_blur_value_1 =  4.0 / 252.0;
const float frag_blur_value_2 =  6.0 / 252.0;
const float frag_blur_value_3 = 16.0 / 252.0;
const float frag_blur_value_4 = 24.0 / 252.0;
const float frag_blur_value_5 = 36.0 / 252.0;

#if COMPILING_VERTEX_PROGRAM

void vert()
{
    vec4 outcolor = gl_Color * color_xform[0] + color_xform[1];

    gl_FrontColor = vec4(texture(palettetex, vec2((outcolor.r * 15.0 + 0.5) / 16.0, (palette + 0.5) / 64.0)).rgb, outcolor.a);
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;

    worldPos = (gl_ModelViewMatrix * gl_Vertex).xy;

    screencoords = (gl_Position.xy + vec2(1, 1)) * 0.5;

    float scale_x = screensize.x / 1280.0;
    float scale_y = screensize.y / 720.0;

    float scale_min = min(scale_x, scale_y);

    ratio = vec2(scale_min / scale_x, scale_min / scale_y);
    ratio.y *= aspect_div;

     blurcoords[0] = screencoords.xy + vec2(-2,-2) * ratio * glow_distance;
     blurcoords[1] = screencoords.xy + vec2(-1,-2) * ratio * glow_distance;
     blurcoords[2] = screencoords.xy + vec2( 0,-2) * ratio * glow_distance;
     blurcoords[3] = screencoords.xy + vec2( 1,-2) * ratio * glow_distance;
     blurcoords[4] = screencoords.xy + vec2( 2,-2) * ratio * glow_distance;
     blurcoords[5] = screencoords.xy + vec2(-2,-1) * ratio * glow_distance;
     blurcoords[6] = screencoords.xy + vec2(-1,-1) * ratio * glow_distance;
     blurcoords[7] = screencoords.xy + vec2( 0,-1) * ratio * glow_distance;
     blurcoords[8] = screencoords.xy + vec2( 1,-1) * ratio * glow_distance;
     blurcoords[9] = screencoords.xy + vec2( 2,-1) * ratio * glow_distance;
    blurcoords[10] = screencoords.xy + vec2(-2, 0) * ratio * glow_distance;
    blurcoords[11] = screencoords.xy + vec2(-1, 0) * ratio * glow_distance;
    blurcoords[12] = screencoords.xy + vec2( 0, 0) * ratio * glow_distance;
    blurcoords[13] = screencoords.xy + vec2( 1, 0) * ratio * glow_distance;
    blurcoords[14] = screencoords.xy + vec2( 2, 0) * ratio * glow_distance;
    blurcoords[15] = screencoords.xy + vec2(-2, 1) * ratio * glow_distance;
    blurcoords[16] = screencoords.xy + vec2(-1, 1) * ratio * glow_distance;
    blurcoords[17] = screencoords.xy + vec2( 0, 1) * ratio * glow_distance;
    blurcoords[18] = screencoords.xy + vec2( 1, 1) * ratio * glow_distance;
    blurcoords[19] = screencoords.xy + vec2( 2, 1) * ratio * glow_distance;
    blurcoords[20] = screencoords.xy + vec2(-2, 2) * ratio * glow_distance;
    blurcoords[21] = screencoords.xy + vec2(-1, 2) * ratio * glow_distance;
    blurcoords[22] = screencoords.xy + vec2( 0, 2) * ratio * glow_distance;
    blurcoords[23] = screencoords.xy + vec2( 1, 2) * ratio * glow_distance;
    blurcoords[24] = screencoords.xy + vec2( 2, 2) * ratio * glow_distance;
}

#elif COMPILING_FRAGMENT_PROGRAM

float hash(float x)
{
    return fract(sin(x) * 43758.5453);
}

float noise(float u)
{
    vec3 x = vec3(u, 0, 0);

    vec3 p = floor(x);
    vec3 f = fract(x);

    f = f * f * (3.0 - 2.0 * f);
    float n = p.x + p.y * 57.0 + 113.0 * p.z;

    return mix(mix(mix(hash(n + 0.0), hash(n + 1.0),   f.x),
           mix(hash(n + 57.0), hash(n + 58.0), f.x),   f.y),
           mix(mix(hash(n + 113.0), hash(n + 114.0),   f.x),
           mix(hash(n + 170.0), hash(n + 171.0), f.x), f.y),
           f.z);
}

void frag()
{
    // SLUDGEGLOW2 STUFF ////////////////////////////////////////////////////////////////

    float blurcolor = 0;

    blurcolor += max(0, texture(framebuf, blurcoords[1 ]).g - glow_threshold) * frag_blur_value_1;
    blurcolor += max(0, texture(framebuf, blurcoords[2 ]).g - glow_threshold) * frag_blur_value_2;
    blurcolor += max(0, texture(framebuf, blurcoords[3 ]).g - glow_threshold) * frag_blur_value_1;
    blurcolor += max(0, texture(framebuf, blurcoords[5 ]).g - glow_threshold) * frag_blur_value_1;
    blurcolor += max(0, texture(framebuf, blurcoords[6 ]).g - glow_threshold) * frag_blur_value_3;
    blurcolor += max(0, texture(framebuf, blurcoords[7 ]).g - glow_threshold) * frag_blur_value_4;
    blurcolor += max(0, texture(framebuf, blurcoords[8 ]).g - glow_threshold) * frag_blur_value_3;
    blurcolor += max(0, texture(framebuf, blurcoords[9 ]).g - glow_threshold) * frag_blur_value_1;
    blurcolor += max(0, texture(framebuf, blurcoords[10]).g - glow_threshold) * frag_blur_value_2;
    blurcolor += max(0, texture(framebuf, blurcoords[11]).g - glow_threshold) * frag_blur_value_4;
    blurcolor += max(0, texture(framebuf, blurcoords[12]).g - glow_threshold) * frag_blur_value_5;
    blurcolor += max(0, texture(framebuf, blurcoords[13]).g - glow_threshold) * frag_blur_value_4;
    blurcolor += max(0, texture(framebuf, blurcoords[14]).g - glow_threshold) * frag_blur_value_2;
    blurcolor += max(0, texture(framebuf, blurcoords[15]).g - glow_threshold) * frag_blur_value_1;
    blurcolor += max(0, texture(framebuf, blurcoords[16]).g - glow_threshold) * frag_blur_value_3;
    blurcolor += max(0, texture(framebuf, blurcoords[17]).g - glow_threshold) * frag_blur_value_4;
    blurcolor += max(0, texture(framebuf, blurcoords[18]).g - glow_threshold) * frag_blur_value_3;
    blurcolor += max(0, texture(framebuf, blurcoords[19]).g - glow_threshold) * frag_blur_value_1;
    blurcolor += max(0, texture(framebuf, blurcoords[21]).g - glow_threshold) * frag_blur_value_1;
    blurcolor += max(0, texture(framebuf, blurcoords[22]).g - glow_threshold) * frag_blur_value_2;
    blurcolor += max(0, texture(framebuf, blurcoords[23]).g - glow_threshold) * frag_blur_value_1;

    vec4 basecolor = texture(framebuf, screencoords.xy);

    float dy = waterheight - worldPos.y;

    dy += noise(worldPos.x / 32.0 + timer *  2   ) * 6;
    dy += noise(worldPos.x / 16.0 + timer * -4.35) * 3;
    dy += noise(worldPos.x / 8.0  + timer *  1   ) * 1.5;

    float glowval = -(dy / 360.0);
    glowval = glowval * light_distance;
    glowval += 1;
    glowval = clamp(glowval, 0.0, 1.0);
    glowval = glowval * glowval;

    vec2 playervec = playerPos - worldPos;
    float dp = length(playervec);

    float angle = dot(vec2(0, -1), playervec) / (dp) * 100;
    float angle2 = dp;

    dp += noise(dp / 32.0 + timer *  2   ) * 6;
    dp += noise(dp / 16.0 + timer * -4.35) * 3;
    dp += noise(dp / 8.0  + timer *  1   ) * 1.5;

    dp += noise(angle / 32.0 + timer *  2   ) * 6;
    dp += noise(angle / 16.0 + timer * -4.35) * 3;
    dp += noise(angle / 8.0  + timer *  1   ) * 1.5;

    dp = -(dp / 360.0);
    float glowval2 = dp * light_distance / playerglow_strength;
    glowval2 += 1;
    glowval2 = clamp(glowval2, 0.0, 1.0);
    glowval2 = glowval2 * glowval2 * playerglow_strength;

    float dx = worldPos.x;

    dx += noise(worldPos.y / 32.0 + timer *  2   ) * 6;
    dx += noise(worldPos.y / 16.0 + timer * -4.35) * 3;
    dx += noise(worldPos.y / 8.0  + timer *  1   ) * 1.5;

    float glowval3 = -(dx / 360.0);
    glowval3 = glowval3 * light_distance / (playerglow_strength * 4);
    glowval3 += 1;
    glowval3 = clamp(glowval3, 0.0, 1.0);
    glowval3 = glowval3 * glowval3 * playerglow_strength * 1.5;

    glowval = 1.0 - (1.0 - clamp(glowval, 0.0, 1.0)) * (1.0 - clamp(glowval3, 0.0, 1.0)) + max(0.0, glowval - 1.0) + max(0.0, glowval3 - 1.0);
    glowval = 1.0 - (1.0 - clamp(glowval, 0.0, 1.0)) * (1.0 - clamp(glowval2, 0.0, 1.0)) + max(0.0, glowval - 1.0) + max(0.0, glowval2 - 1.0);

    vec4 outcolor = 1.0 - (1.0 - basecolor) * (1.0 - mix(vec4(0.0), light_color * light_color.a, glowval));

    vec4 glowcolor = (glow_color * glowval * glow_strength) * blurcolor;
    outcolor += glowcolor;

    float extra_green = max(outcolor.g - 1.0, 0.0);
    float extra_green_overexpose = extra_green * overexpose;
    outcolor.r += extra_green_overexpose;
    outcolor.b += extra_green_overexpose;

    float extra_red = max(outcolor.r - 1.0, 0.0);
    float extra_red_overexpose = extra_red * overexpose;
    outcolor.g += extra_red_overexpose;
    outcolor.b += extra_red_overexpose;

    float extra_blue = max(outcolor.b - 1.0, 0.0);
    float extra_blue_overexpose = extra_blue * overexpose;
    outcolor.r += extra_blue_overexpose;
    outcolor.g += extra_blue_overexpose;

    /////////////////////////////////////////////////////////////////////////////////////

    // LIGHTING STUFF ///////////////////////////////////////////////////////////////////

    float d = length(playerPos - worldPos);

    float ambient_light = level_param * level_param;
    float l_p = min(1.0, 60.0 / (d + 50.0));
    float l_0 = min(1.0, light0.z / (length(light0.xy - worldPos) + light0.z * 0.75));
    float l_1 = min(1.0, light1.z / (length(light1.xy - worldPos) + light1.z * 0.75));
    float l_2 = min(1.0, light2.z / (length(light2.xy - worldPos) + light2.z * 0.75));
    float l_3 = min(1.0, light3.z / (length(light3.xy - worldPos) + light3.z * 0.75));
    float l_4 = min(1.0, light4.z / (length(light4.xy - worldPos) + light4.z * 0.75));
    float l_5 = min(1.0, light5.z / (length(light5.xy - worldPos) + light5.z * 0.75));
    float l_6 = min(1.0, light6.z / (length(light6.xy - worldPos) + light6.z * 0.75));
    float l_7 = min(1.0, light7.z / (length(light7.xy - worldPos) + light7.z * 0.75));

    l_p = l_p * l_p;
    l_0 = l_0 * l_0 * 2;
    l_1 = l_1 * l_1 * 2;
    l_2 = l_2 * l_2 * 2;
    l_3 = l_3 * l_3 * 2;
    l_4 = l_4 * l_4 * 2;
    l_5 = l_5 * l_5 * 2;
    l_6 = l_6 * l_6 * 2;
    l_7 = l_7 * l_7 * 2;

    float lightval = l_p + l_0 + l_1 + l_2 + l_3 + l_4 + l_5 + l_6 + l_7 + glowval;
    lightval = 1.0 - (1.0 - lightval) * (1.0 - ambient_light);

    outcolor *= min(1.5, lightval);

    /////////////////////////////////////////////////////////////////////////////////////

    outcolor.a = gl_Color.a;
    gl_FragColor = outcolor;
}

#endif
