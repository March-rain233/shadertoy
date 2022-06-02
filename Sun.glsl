#define SUNR 0.5
#define BGCOLOR vec3(.8,.4,.0)
#define SUNCOLOR vec3(0.8,0.65,0.3 )
#define HOLOCOLOR vec3(.8,.4,.1)
#define CORONACOLOR vec3(.8,.4,.1)
float hash(float seed){
	return fract(sin(seed)*	12.516);
}
vec2 hash2(in vec2 seed){
	return fract(sin(vec2(
		dot(seed, vec2(127.1, 311.7)),
		dot(seed, vec2(269.5, 183.3))
		)
	) * 43758.5358);
}
vec2 hash2B(in vec2 seed){
  return 1.-2.*hash2(seed);
}
float sdfCircle(in vec2 uv, float r){
	return length(uv)-r;
}
float worley(in vec2 st){
	vec2 p = floor(st);
	vec2 f = fract(st);
	float d = 1.;
	for(int i=-1;i<=1;++i){
		for(int j=-1;j<=1;++j){
			vec2 offset = vec2(float(i), float(j));
			d = min(d, length(hash2(p+offset)+offset-f));
		}
	}
	return d;
}
float perlin(in vec2 st){
	vec2 i = floor(st);
	vec2 f = st-i;
	vec2 w = f*f*f*(10.-15.*f+6.*f*f);
	return mix(
		mix(dot(hash2B(i+vec2(0.,0.)),f-vec2(0.,0.)),
		    dot(hash2B(i+vec2(1.,0.)),f-vec2(1.,0.)),w.x),
		mix(dot(hash2B(i+vec2(0.,1.)),f-vec2(0.,1.)),
			  dot(hash2B(i+vec2(1.,1.)),f-vec2(1.,1.)),w.x),
			  w.y);
}
float fbm(in vec2 st){
	float f = 0.;
	float a = 1.;
	float b = 1.;
	for(int i=0;i<5;++i){
		f += a * perlin(st * b);
		a /= 2.;
		b *= 2.;
	}
	return f;
}
float snoise(vec3 uv, float res)
{
	const vec3 s = vec3(1e0, 1e2, 1e3);
	
	uv *= res;
	
	vec3 uv0 = floor(mod(uv, res))*s;
	vec3 uv1 = floor(mod(uv+vec3(1.), res))*s;
	
	vec3 f = fract(uv); f = f*f*(3.0-2.0*f);

	vec4 v = vec4(uv0.x+uv0.y+uv0.z, uv1.x+uv0.y+uv0.z,
		      	  uv0.x+uv1.y+uv0.z, uv1.x+uv1.y+uv0.z);

	vec4 r = fract(sin(v*1e-1)*1e3);
	float r0 = mix(mix(r.x, r.y, f.x), mix(r.z, r.w, f.x), f.y);
	
	r = fract(sin((v + uv1.z - uv0.z)*1e-1)*1e3);
	float r1 = mix(mix(r.x, r.y, f.x), mix(r.z, r.w, f.x), f.y);
	
	return mix(r0, r1, f.z)*2.-1.;
}
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
	vec2 uv = (2.* fragCoord.xy - iResolution.xy) / min(iResolution.x, iResolution.y);
	vec3 color = vec3(0.);
	color = vec3(-sdfCircle(uv,SUNR)) * BGCOLOR;

	color += vec3(1.0-pow(abs(sdfCircle(uv, SUNR)), 0.3)) / SUNR * HOLOCOLOR;

	color += vec3(max(-sdfCircle(uv, SUNR),0.) * (fbm((uv + vec2(iTime / 2.,0.))*10.) + 2.)) * SUNCOLOR;

	float fade = pow(length(uv),0.5);
    float fval1 = 1.-fade;
    float fval2 = 1.-fade;
	float angle = atan(uv.x, uv.y)/6.2832;
	vec3 coord = vec3(angle, length(uv), iTime*0.1);
	float noise1 = abs(snoise(coord + vec3(0., 0., iTime * .015), 15.));
	float noise2 = abs(snoise(coord + vec3(0., -iTime * .15, iTime * .015), 45.));
    float power = 6.;
    fval1 += (1./power) * snoise(coord + vec3(0., -iTime, iTime * .2), power * 10. * (noise1 + 1.));
    fval2 += (1./power) * snoise(coord + vec3(0., -iTime, iTime * .2), power * 25. * (noise2 + 1.));
    float corona = pow(fval1 * abs(1.1 - fade), 2.) * 12.;
    corona += pow(fval2 * abs(1.1 - fade), 2.) * 12.;
    corona *= 1.2 - noise1;
    corona *= step(SUNR, length(uv));
	color += vec3(corona);
	color.r += .15;

	fragColor = vec4(color, 1.);
}
