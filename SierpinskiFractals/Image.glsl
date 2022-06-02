#iChannel0 "self"
#iChannel1 "BufferA.glsl"
#define CAL_NUM 600
#define VERTEX_NUM 5 //顶点数
//修正原点坐标到屏幕中心
vec2 fixUV(in vec2 uv){
    return (uv * 2. - iResolution.xy) / min(iResolution.x, iResolution.y);
}
//获得顶点颜色
vec3 getColor(float i){
    vec3 color = vec3(288./255., 0., 127./255.);
    if(i <= 0.5 && i > -0.5){
        color = vec3(0., 0., 1.);
    }
    else if(i <= 1.5){
        color = vec3(0., 1., 0.);
    }
    else if(i <= 2.5){
        color = vec3(0., 1., 1.);
    }
    else if(i <= 3.5){
        color = vec3(1., 0., 0.);
    }
    else if(i <= 4.5){
        color = vec3(1., 0., 1.);
    }
    else if(i <= 5.5){
        color = vec3(1., 1., 1.);
    }
    return color;
}
void mainImage(out vec4 fragColor, in vec2 fragCoord){
    ivec2 ipx = ivec2(fragCoord-0.5);
    vec3 color = texelFetch(iChannel0, ipx, 0).xyz;
    vec2 uv = fixUV(fragCoord);
    for(int i = 0; i < CAL_NUM; ++i){//绘制散点
        vec4 prePos = texelFetch(iChannel1, ivec2(i, 1), 0);
        prePos.xy = (prePos.xy*2. - vec2(600.))/vec2(600.);
        if(length(prePos.xy - uv) < .005){
            color = getColor(prePos.z);
        }
    }
    for(int i = 0; i < VERTEX_NUM; ++i){//绘制顶点
        vec4 prePos = texelFetch(iChannel1, ivec2(i, 0), 0);
        prePos.xy = (prePos.xy*2. - vec2(600.))/vec2(600.);
        if(length(prePos.xy - uv) < .03){
            color = getColor(prePos.z);
        }
    }
    fragColor = vec4(color, 1.);
}