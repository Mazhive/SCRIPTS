#version 450 core

out vec4 fragColor;

uniform vec2 iResolution;

#define PI 3.141592653589793

vec3 rotateX(vec3 p, float angle) {
    mat3 m = mat3(
        1.0, 0.0, 0.0,
        0.0, cos(angle), -sin(angle),
        0.0, sin(angle), cos(angle)
    );
    return m * p;
}

vec3 rotateY(vec3 p, float angle) {
    mat3 m = mat3(
        cos(angle), 0.0, sin(angle),
        0.0, 1.0, 0.0,
        -sin(angle), 0.0, cos(angle)
    );
    return m * p;
}

vec3 rotateZ(vec3 p, float angle) {
    mat3 m = mat3(
        cos(angle), -sin(angle), 0.0,
        sin(angle), cos(angle), 0.0,
        0.0, 0.0, 1.0
    );
    return m * p;
}

// Vereenvoudigde kubus tekenfunctie (als een punt)
bool drawCube(vec3 center, float size, vec2 uv) {
    vec2 dist = abs(uv - center.xy);
    return max(dist.x, dist.y) < size * 0.5;
}

void main() {
    vec2 uv = gl_FragCoord.xy / iResolution.xy;
    uv -= 0.5;
    uv.x *= iResolution.x / iResolution.y;

    vec2 center = vec2(0.0, 0.0);
    float size = 0.2;

    vec2 dist = abs(uv - center);
    if (max(dist.x, dist.y) < size * 0.5) {
        fragColor = vec4(0.7, 0.7, 0.7, 1.0); // Lichtgrijs vierkant
    } else {
        fragColor = vec4(0.1, 0.1, 0.1, 1.0); // Donkergrijze achtergrond
    }
}
