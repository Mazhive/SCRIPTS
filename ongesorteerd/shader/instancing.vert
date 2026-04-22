#version 330 core

layout(location=0) in vec3 position;
uniform float u_time;
out vec3 vColor;

const int N    = 32;
const int COLS = 5;

// simpele Y-rotatie
mat3 rotY(float a) {
    float c = cos(a), s = sin(a);
    return mat3(
        c,  0, s,
        0,  1, 0,
       -s,  0, c
    );
}

// HSV→RGB
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz)*6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main() {
    int id  = gl_InstanceID;
    int col = id % COLS;
    int row = id / COLS;
    float t = u_time * 0.5 + float(id) * 0.2;

    // 1) roteer de cube
    vec3 p = rotY(t) * position;

    // 2) grid (gecentreerd rond 0)
    float rows = ceil(float(N) / float(COLS));
    vec2 grid = vec2(
        float(col) - float(COLS-1)*0.5,
        float(row) - (rows-1.0)*0.5
    );
    p.xy += grid * 2.0;

    // 3) S-vormige golf-animatie
    p.x += sin(t + float(row)) * 0.5;
    p.y += cos(t*0.8 + float(col)) * 0.3;

    // 4) orthografische “projectie”: simpelweg kleiner schalen
    //    zodat alles in [-1,1] clip-space valt
    gl_Position = vec4(p * 0.12, 1.0);

    // 5) vloeiende kleur-wave
    float hue = fract(float(id)/float(N) + u_time*0.1);
    vColor = hsv2rgb(vec3(hue, 1.0, 1.0));
}
