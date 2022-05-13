#define OPEN_AO
//常数
#define PRECISION .01
#define PI 3.1415926
#define AA 2
#define SHADOW_K 15
//raymarch配置
#define TMAX 20.
#define TMIN 0.1
#define RAYMARCH_TIME 100
#define REFLECT_TIME 5;
#define BOUNCE_TIME 5
const vec3 amb = vec3(0.25, .1, .15);//环境光
//物体材质
struct material{
    vec3 color;//物体基本色
    float shininess;//光泽度
    float reflectance;//反射率
    float ior;//折射率
};
//修正原点坐标到屏幕中心
vec2 fixUV(in vec2 uv){
    return (uv * 2. - iResolution.xy) / min(iResolution.x, iResolution.y);
}
//sdf 3d图形集合
//球体
float sdfSphere(in vec3 p, float r){
    return length(p) - r;
}
//盒子
float sdfBox(in vec3 p, in vec3 a, float r){
    vec3 d = abs(p) - a;
    return length(max(d, 0.)) + min(max(d.x, max(d.y, d.z)), 0.) - r;
}
//平面
float sdfPlat(in vec3 p){
    return abs(p.y);
}
//standard
//sdf操作
//并集
vec2 opUnion(vec2 a, vec2 b){
    return a.x < b.x ? a : b; 
}
//交集
vec2 opIntersect(vec2 a, vec2 b){
    return a.x < b.x ? b : a;
}
//差集
vec2 opDifference(vec2 a, vec2 b){
    return a.x < -b.x ? vec2(-b.x, b.y) : a;
}
//计算场景sdf
vec2 map(in vec3 p){
    vec2 d;
    d =     vec2(           sdfPlat(p + vec3(0., 1., 0.)),  0);
    d = opUnion(    d, vec2(sdfSphere(p, 1.),               1.));
    d = opUnion(    d, vec2(sdfBox(p - vec3(2, 0, -1), vec3(0.8), .1),       2.));
    //d = opDifference(vec2(sdfSphere(p, .8), 1.), vec2(sdfBox(p, vec3(0.5), .1), 1.));
    return d;
}
//计算法线
vec3 calcNormal(in vec3  p ){
    //获取梯度方向
    const float h = PRECISION;
    const vec2 k = vec2(1,-1);
    return normalize( k.xyy * map( p + k.xyy * h ).x + 
                      k.yyx * map( p + k.yyx * h ).x + 
                      k.yxy * map( p + k.yxy * h ).x + 
                      k.xxx * map( p + k.xxx * h ).x );
} 
//获取物体材质
material getMaterial(in float type){
    material res = material(vec3(.5), 32., .05, 0.);
    if(type == 1.){
        res.color.r = .3;
    }
    return res;
}
//获取背景色
vec3 getBg(in vec3 vd){
    return vec3(1.5 * (vd.y + .5), 2. * (vd.y + .5), .99);
}
//设置摄像机
mat3 setCamera(vec3 ta, vec3 ro, float ra){
    vec3 z = normalize(ta - ro);
    vec3 cp = vec3(sin(ra), cos(ra), 0.);
    vec3 x = normalize(cross(z, cp));
    vec3 y = cross(x, z);
    return mat3(x, y, z);
}
//光线步进
vec2 rayMarch(in vec3 ro, in vec3 rd){
    float t = TMIN;
    vec2 res = vec2(-1);
    for(int i = 0; i < RAYMARCH_TIME && t < TMAX; ++i){
        vec3 p = ro + t * rd;
        vec2 d = map(p);
        if(d.x < PRECISION){
            res = vec2(t, d.y);
            break;
        }
        t += d.x;
    }
    return res;
}
//阴影
float softshadow(in vec3 ro, in vec3 rd){
    float res = 1.0;
    for(float t = TMIN; t < TMAX;)
    {
        float h = map(ro + rd * t).x;
        if(h < PRECISION)
            return 0.0;
        res = min(res, float(SHADOW_K) * h / t);
        t += h;
    }
    return res;
}
//环境光遮蔽
float calcAO(in vec3 p, in vec3 n){
    float occ = 0.0;
    float sca = 1.0;
    for(int i = 0; i < 5; ++i){
        float h = 0.01 + 0.03 * float(i);
        float d = map(p + h * n).x;
        occ += (h - d) * sca;
        sca *= 0.95;
        if(occ > 0.35)
            break;
    }
    return clamp(1. - 3. * occ, 0., 1.);
}
//菲涅尔效应
float fresnel(vec3 v, vec3 n, float p){
    return pow(1. - dot(v, n), p);
}
//着色
vec3 shader(in vec3 p, in vec3 n, in vec3 vd, in vec3 ld, in vec3 lc,in material m){
    vec3 color = vec3(0.);
    float spec = pow(max(dot(n, normalize(vd + ld)), 0.), m.shininess);
    color += spec * lc;
    float dif = max(dot(ld, n), 0.);
    color += dif * m.color;
    color *= softshadow(p, ld);
#ifdef OPEN_AO
    color += amb * calcAO(p, n);
#else
    color += amb * 0.1;
#endif
    return color;
}
//渲染
vec3 render(in vec2 uv){
    //摄像机设定
    vec3 ro = vec3(0., 1., 3.);//摄像机位置
    if(iMouse.z > 0.01){
        float deltaX = iMouse.x / iResolution.x * 2. * PI;
        float deltaY = iMouse.y / iResolution.y * 2. * PI;
        ro = vec3(3. * cos(deltaX), 3. * sin(deltaY), 3. * sin(deltaX));
    }
    vec3 ta = vec3(0);//摄像机关注点
    mat3 cam = setCamera(ta, ro, 0.);//摄像机空间矩阵
    vec3 rd = normalize(cam * vec3(uv, 1));//摄像机方向
    //光源设定
    vec3 lc = vec3(1, .9, .8);//光源颜色
    vec3 lp = vec3(.5, 1.5, 2.);//光源位置
    vec3 amb = vec3(0.1);//环境光颜色

    vec2 t = rayMarch(ro, rd);
    vec3 color = vec3(0);
    if(t.x > 0.){
        vec3 p = ro + t.x * rd;//顶点位置
        vec3 n = calcNormal(p);//法线方向
        vec3 ld = lp - p;//光源方向
        vec3 kc = lc / (length(ld) * length(ld));//衰减后的光线颜色
        ld = normalize(ld);
        material om = getMaterial(t.y);//物体材质
        //Blinn-Pong
        color += shader(p, n, -rd, ld, kc, om);
        //计算反射
        vec3 refl = reflect(rd, n);
        t = rayMarch(p, refl);
        if(t.x > 0.){
            material rm = getMaterial(t.y);
            vec3 rp = p + refl * t.x;
            vec3 rld = lp - rp;
            vec3 rkc = lc / (length(rld) * length(rld));
            rld = normalize(rld);
            color += om.reflectance * shader(rp, calcNormal(rp), -refl, rld, rkc, rm);// (t.x * t.x);
        }
        //计算折射
        // vec3 refr = refract(rd, n, 1.5);
        // t = rayMarch(p, refr);
        // if(t.x > 0.){
        //     material rm = getMaterial(t.y);
        //     vec3 rp = p + refr * t.x;
        //     vec3 rld = lp - rp;
        //     vec3 rkc = lc / (length(rld) * length(rld));
        //     rld = normalize(rld);
        //     color += 0.5 * shader(rp, calcNormal(rp), -refr, rld, rkc, rm);// (t.x * t.x);
        // }
    }
    else{
        //背景色
        return getBg(rd);
    }
    return color;
}
void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec3 color = vec3(0);
    //超采样
    for(int i = 0; i < AA; ++i){
        for(int j = 0; j < AA; ++j){
            vec2 offset = 2. * (vec2(float(i), float(j)) / float(AA) - 0.5);
            color += render(fixUV(fragCoord + offset));
        }
    }
    fragColor = vec4(color / float(AA *AA), 1.);
}