// 32 bewegende, roterende kubussen in S-vorm met per-vlak rood→groen gradient

// Shadertoy uniforms (NIET opnieuw declareren!)
/* iResolution = vec3(viewport.xy, 0)
   iTime       = elapsed tijd in seconden */

// Signed‐distance naar axis-aligned box
float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

// Y-rotatie matrix
mat3 rotY(float a) {
    float c = cos(a), s = sin(a);
    return mat3(
         c, 0,  s,
         0, 1,  0,
        -s, 0,  c
    );
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // 1. Normaliseer coord naar -aspect…+aspect
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // 2. Stel camera op en draai langzaam rond Y
    vec3 ro = vec3(0.0, 2.0, 6.0);
    vec3 rd = normalize(vec3(uv, -1.0));
    float ca = cos(iTime * 0.15), sa = sin(iTime * 0.15);
    ro.xz = mat2(ca,-sa, sa,ca) * ro.xz;
    rd.xz = mat2(ca,-sa, sa,ca) * rd.xz;

    // 3. Ray-march door scene
    float t = 0.0;
    int   hitID = -1;
    for(int i = 0; i < 80; i++){
        vec3 p = ro + rd * t;
        float minD = 1e5;
        int   minJ = -1;
        // loop alle 32 kubussen
        for(int j = 0; j < 32; j++){
            float jf = float(j);
            int   row = j / 5, col = j - row * 5;
            float T = iTime * 0.6 + jf * 0.15;
            // grid-center + S-beweging
            float rows = ceil(32.0 / 5.0);
            vec2 g = vec2(
                float(col) - (5.0 - 1.0) * 0.5,
                float(row) - (rows - 1.0) * 0.5
            ) * 2.0;
            vec3 center = vec3(
                g.x + sin(T + float(row)) * 0.5,
                g.y + cos(T * 0.8 + float(col)) * 0.3,
                0.0
            );
            // lokale ruimte
            vec3 lp = p - center;
            float c2 = cos(-T), s2 = sin(-T);
            lp = vec3(lp.x*c2 + lp.z*s2, lp.y, -lp.x*s2 + lp.z*c2);
            float d = sdBox(lp, vec3(0.3));
            if(d < minD){ minD = d; minJ = j; }
        }
        if(minD < 0.001 || t > 20.0){ hitID = minJ; break; }
        t += minD;
    }

    // 4. Achtergrond donker
    vec3 col = vec3(0.02);

    // 5. Als er een hit is, schaduw & kleur
    if(hitID >= 0){
        vec3 pos = ro + rd * t;
        float e = 0.001;
        vec3 n = normalize(vec3(
            sdBox((pos+vec3(e,0,0))-pos,vec3(0.3))
          - sdBox((pos-vec3(e,0,0))-pos,vec3(0.3)),
            sdBox((pos+vec3(0,e,0))-pos,vec3(0.3))
          - sdBox((pos-vec3(0,e,0))-pos,vec3(0.3)),
            sdBox((pos+vec3(0,0,e))-pos,vec3(0.3))
          - sdBox((pos-vec3(0,0,e))-pos,vec3(0.3))
        ));
        // herbereken lokale coords
        int j = hitID;
        int row = j / 5, colj = j - row * 5;
        float jf = float(j), T = iTime * 0.6 + jf * 0.15;
        float rows = ceil(32.0 / 5.0);
        vec2 g = vec2(
            float(colj) - (5.0 - 1.0) * 0.5,
            float(row)  - (rows - 1.0) * 0.5
        ) * 2.0;
        vec3 center = vec3(
            g.x + sin(T + float(row)) * 0.5,
            g.y + cos(T * 0.8 + float(colj)) * 0.3,
            0.0
        );
        vec3 lp = pos - center;
        lp = vec3(lp.x*cos(-T) + lp.z*sin(-T),
                  lp.y,
                 -lp.x*sin(-T) + lp.z*cos(-T)) / 0.3;
        // UV diagonaal per vlak
        vec2 uv2 = abs(lp.x)>=abs(lp.y)&&abs(lp.x)>=abs(lp.z)
                   ? vec2(lp.z,lp.y)
                   : abs(lp.y)>=abs(lp.x)&&abs(lp.y)>=abs(lp.z)
                   ? vec2(lp.x,lp.z)
                   :              vec2(lp.x,lp.y);
        float f = (uv2.x + uv2.y + 1.0) * 0.5;
        vec3 base = mix(vec3(1,0,0), vec3(0,1,0), f);
        float diff = clamp(dot(n, normalize(vec3(1))), 0.0, 1.0);
        col = base * diff;
    }

    fragColor = vec4(col, 1.0);
}
