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
#define RAY_DEPTH 5
#define DIFF 0
#define SPEC 1
#define REFR 2
const vec3 amb = vec3(0.02); //环境光
//物体材质
struct material{
    vec3 color; //物体基本色
    float shininess; //光泽度
    float ior; //折射率
    vec3 f0; //反射率偏移
    float frenselPow;
    int type;//物体类型
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
    vec2 d = vec2(100.);
    d =     vec2(           sdfPlat(p + vec3(0., 1., 0.)),  0);
    d = opUnion(    d, vec2(sdfSphere(p - vec3(1, 0., 1.), 1.),               1.));
    d = opUnion(    d, vec2(sdfBox(p - vec3(-1.5, .1, .5), vec3(0.8), .01),       2.));
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
    material res = material(vec3(.5), 32., -1., vec3(0.05), 5., SPEC);
    if(type == 0.){
        res.f0 = vec3(0.15);
    }
    else if(type == 1.){
        res.color = vec3(.6, .25, .2);
        res.ior = -1.;
        res.shininess = 32.;
        res.f0 = vec3(0.955, 0.638, 0.538);
        res.frenselPow = 1.;
        res.type = SPEC;
    }
    else if(type == 2.){
        res.color.r = .3;
        res.ior = 1.5;
        res.f0 = vec3(0.04);
        res.type = SPEC | REFR;
    }
    return res;
}
//获取背景色
vec3 getBg(in vec3 vd){
    return vec3(.12);
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
vec2 rayMarch(in vec3 ro, in vec3 rd, float outside){
    float t = TMIN;
    vec2 res = vec2(-1);
    for(int i = 0; i < RAYMARCH_TIME && t < TMAX; ++i){
        vec3 p = ro + t * rd;
        vec2 d = map(p);
        d.x *= outside;
        if(abs(d.x) < PRECISION){
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
vec3 fresnel(vec3 v, vec3 n, float p, vec3 f0){
    return f0 + (1. - f0) * pow(1. - dot(v, n), p);
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
struct Node{
    int parent;//父节点的索引
    int next;//同一层的下一节点
    material m;//当前物体材质
    vec3 color;//当前层颜色
    vec3 p;//位置
    vec3 n;//法线
    vec3 rd;//光线方向
    vec3 rate;//衰减率
    bool inside;//光路是否位于物体内
};
//渲染
 Node tree[(1 << RAY_DEPTH) - 1];//渲染树
vec3 render(in vec2 uv){
    //摄像机设定
    vec3 vo = vec3(1., 1., 3.);//摄像机位置
    float deltaX = iMouse.x / iResolution.x * 2. * PI;
    float deltaY = iMouse.y / iResolution.y * 2. * PI;
    vo = vec3(3. * cos(deltaX), 3. * sin(deltaY), 3. * sin(deltaX));
    vec3 ta = vec3(0);//摄像机关注点
    mat3 cam = setCamera(ta, vo, 0.);//摄像机空间矩阵
    vec3 vd = normalize(cam * vec3(uv, 1));//摄像机方向
    //光源设定
    vec3 lc = vec3(3, 2.9, 2.8);//光源颜色
    vec3 lp = vec3(.5, 3., 2.);//光源位置
    vec3 amb = vec3(0.1);//环境光颜色
    vec2 t = rayMarch(vo, vd, 1.);
    if(t.x > 0.){
        tree[0].parent = -1;
        tree[0].next = -1;
        tree[0].m = getMaterial(t.y);
        tree[0].color = vec3(0.);
        tree[0].p = vo + t.x * vd;
        tree[0].n = calcNormal(tree[0].p);
        tree[0].rd = vd;
        tree[0].inside = false;
    }
    else{
        return getBg(vd);
    }
    int count = 1;//当前节点数
    int preStart = 0;//上一层节点起始位置
    //生成渲染树
    for(int i = 1; i < RAY_DEPTH && preStart != count; ++i){
        int temp = preStart;
        preStart = count;
        //遍历前一层节点生成当前层节点
        for(int now = temp; now != -1; now = tree[now].next){
            vec3 frens = clamp(fresnel(-tree[now].rd, tree[now].n, tree[now].m.frenselPow, tree[now].m.f0), 0., 1.);//获取父节点菲涅尔效应
            float factor = tree[now].inside ? 1. : -1.;//父节点光路是否在物体内部
            //生成反射左子树
            if((tree[now].m.type & SPEC) == SPEC){
                vec3 tempP = tree[now].p + tree[now].rd * PRECISION * factor * 1.;
                tree[count].rd = normalize(reflect(tree[now].rd, tree[now].n));
                t = rayMarch(tempP, tree[count].rd, -factor);
                if(t.x > 0.){
                    tree[count].parent = now;
                    tree[count].next = count + 1;
                    tree[count].m = getMaterial(t.y);
                    tree[count].color = vec3(0.);
                    tree[count].p = tempP + t.x * tree[count].rd;
                    tree[count].n = calcNormal(tree[count].p) * -factor;
                    tree[count].rate = frens;
                    tree[count].inside = tree[now].inside;
                    count += 1;
                }
                else{
                    tree[now].color += getBg(tree[count].rd) * frens;
                }
            }
            //生成折射右子树
            if((tree[now].m.type & REFR) != REFR)
                continue;
            vec3 tempP = tree[now].p;// + tree[now].rd * PRECISION * factor * 1.;
            tree[count].rd = refract(tree[now].rd, tree[now].n, tree[now].inside ? tree[now].m.ior : 1. / tree[now].m.ior);
            if(length(tree[count].rd) > PRECISION){
                tree[count].rd = normalize(tree[count].rd);
                t = rayMarch(tempP, tree[count].rd, factor);
                if(t.x > 0.){
                    tree[count].parent = now;
                    tree[count].next = count + 1;
                    tree[count].m = getMaterial(t.y);
                    tree[count].color = vec3(0.);
                    tree[count].p = tempP + t.x * tree[count].rd;
                    tree[count].n = calcNormal(tree[count].p) * factor;
                    tree[count].rate = 1. - frens;
                    tree[count].inside = !tree[now].inside;
                    count += 1;
                }
                else{
                    tree[now].color += getBg(tree[count].rd) * (1. - frens);
                }
            }
        }
        tree[count - 1].next = -1;
    }
    //计算节点
    for(int i = count - 1; i > 0; --i){
        vec3 ld = lp - tree[i].p;//光源方向
        vec3 kc = lc / dot(ld, ld);//衰减后的光线颜色
        ld = normalize(ld);
        tree[i].color += shader(tree[i].p, tree[i].n, -tree[i].rd, ld, kc, tree[i].m);//计算当前点颜色
        tree[tree[i].parent].color += tree[i].color * tree[i].rate;//反向更新
    }
    vec3 ld = lp - tree[0].p;//光源方向
    vec3 kc = lc / dot(ld, ld);//衰减后的光线颜色
    ld = normalize(ld);
    tree[0].color += shader(tree[0].p, tree[0].n, -tree[0].rd, ld, kc, tree[0].m);
    return pow(tree[0].color, vec3(1.0));//伽马校正
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