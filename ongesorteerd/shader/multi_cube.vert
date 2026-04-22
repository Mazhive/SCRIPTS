#version 330 core
in vec3 position;
uniform mat4 u_modelViewProjectionMatrix;
uniform float u_time;
out vec3 vPos;

const int N = 32;
const int C = 5;
mat3 rotY(float a){
    float c = cos(a), s = sin(a);
    return mat3(c,0,s, 0,1,0, -s,0,c);
}

void main(){
    int id  = gl_InstanceID;
    int col = id % C;
    int row = id / C;
    float t  = u_time*0.6 + id*0.15;

    vec3 p = rotY(t) * position;
    float rows = ceil(float(N)/float(C));
    vec2 grid = vec2(col - (C-1)*0.5, row - (rows-1)*0.5);
    p.xy += grid*2.0;
    p.x += sin(t+row)*0.5;
    p.y += cos(t*0.8+col)*0.3;

    vPos = position;
    gl_Position = u_modelViewProjectionMatrix * vec4(p*0.3,1.0);
}
