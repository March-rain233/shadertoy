#iChannel0 "self"
#define PI 3.1415
#define VERTEX_NUM 4 //顶点数
#define CAL_NUM 600 //一次计算的点数
#define SIZE 600. //画布大小
#if VERTEX_NUM != 5
#define RATE .5 //分割率
#else
#define RATE 0.618033988
#endif
#define RADIAN_UNIT 2.*PI/float(VERTEX_NUM) //单位旋转角
const ivec4 txPrePos = ivec4(0, 1, CAL_NUM - 1, 1);
const ivec4 txVertexs = ivec4(0, 0, VERTEX_NUM - 1, 0);
//随机函数
float hash(float n) {
    return fract(sin(n)*128.5453123);
}
//读取
vec4 loadValue(in ivec2 re){
    return texelFetch(iChannel0, re, 0);
}
//储存
void storeValue(in ivec4 re, in vec4 va, inout vec4 fragColor, in ivec2 p){
    fragColor = (p.x>=re.x && p.y>=re.y && p.x<=re.z && p.y<=re.w ) ? va : fragColor;
}
void storeValue(in ivec2 re, in vec4 va, inout vec4 fragColor, in ivec2 p){
    fragColor = (p==re) ? va : fragColor;
}
//获得顶点坐标
vec4 getVertex(int id){
    vec2 p = vec2(0, SIZE/2.);
    float r = float(id)* RADIAN_UNIT;
    mat2 rotate = mat2(
        cos(r), -sin(r),
        sin(r), cos(r)
    );
    p *= rotate;
    p += vec2(SIZE/2.);
    return vec4(p.xy, id, id);
}
void mainImage(out vec4 fragColor, in vec2 fragCoord){
    ivec2 ipx = ivec2(fragCoord-0.5);
    if(ipx.y > 1 || ipx.x > max(VERTEX_NUM, CAL_NUM)){
        discard;
    }
    vec4 vertex = getVertex(ipx.x);
    vec4 prePos = loadValue(ivec2(CAL_NUM - 1, 1));
    if(iFrame == 0){
        prePos = getVertex(0);
    }
    for(int i = 0; i <= ipx.x && i <= CAL_NUM; ++i){
        int r =int(floor(hash(iTime / float(i + 1)) * float(VERTEX_NUM)));
#if VERTEX_NUM > 3
        if(abs(float(r) - prePos.w) < 0.1){
            int step;
    #if VERTEX_NUM == 4
            step = 1 + 2 * (int(floor(hash(iTime / float(i * i)) * 2.)));
    #else
            step = int(ceil(hash(iTime / float(i * i)) * float(VERTEX_NUM - 1))) + 1;
    #endif
            r = (r + step) % VERTEX_NUM;
        }
#endif
        vec4 select = getVertex(r);
        prePos = vec4(((select.xy - prePos.xy) * RATE + prePos.xy), select.z, r);
    }
    storeValue(txVertexs, vertex, fragColor, ipx);
    storeValue(txPrePos, prePos, fragColor, ipx);
}