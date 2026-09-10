enum AquariumDepthShaders {
    // Compiled once on scene creation. Local articulation stays on the GPU.
    static let source = #"""
    #include <metal_stdlib>
    using namespace metal;

    constant float3 bowlCenter = float3(\#(AquariumBowl.center.x), \#(AquariumBowl.center.y), \#(AquariumBowl.center.z));
    constant float3 bowlRadii = float3(\#(AquariumBowl.radii.x), \#(AquariumBowl.radii.y), \#(AquariumBowl.radii.z));
    constant float bowlFront = \#(AquariumBowl.frontCut);
    constant float waterHeight = \#(AquariumBowl.waterHeight);
    constant float sandHeight = \#(AquariumBowl.sandHeight);
    constant float3 fishProportions[\#(FishSpecies.allCases.count)] = { \#(FishSpecies.allCases.sorted { $0.glassID < $1.glassID }.map {
        let p = $0.glassProportions
        return "float3(\(p.x),\(p.y),\(p.z))"
    }.joined(separator: ", ")) };

    struct Vertex { float4 position; float4 normal; float4 uv; float4 motion; };
    struct Uniforms {
        float4x4 viewProjection;
        float4x4 model;
        float4x4 lightViewProjection;
        float4x4 inverseViewProjection;
        float4 camera;
        float4 control; // seconds, material, daylight, aspect
        float4 interaction; // ripple x/y, age, animation amplitude
        float4 fishLight; // glass fish position for the colored light pool
        float4 catalog; // species, substrate, feature, vitality
        float4 companionMotion; // species, gait, activity, ambient time
        float4 wallLower; // lower wall RGB, palette glow
        float4 wallUpper; // upper wall RGB, themed lighting amount
        float4 themeKey;
        float4 themeFill;
        float4 featureLight0;
        float4 featureLight1;
        float4 widget; // enabled, circular outline, half width, half height
    };
    struct Varying {
        float4 position [[position]];
        float3 world;
        float3 normal;
        float4 uv;
        float3 local;
    };

    float hash(float3 p) { return fract(sin(dot(p, float3(127.1, 311.7, 74.7))) * 43758.5453); }
    float noise(float3 p) {
        float3 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
        return mix(mix(mix(hash(i), hash(i+float3(1,0,0)),f.x),
                       mix(hash(i+float3(0,1,0)),hash(i+float3(1,1,0)),f.x),f.y),
                   mix(mix(hash(i+float3(0,0,1)),hash(i+float3(1,0,1)),f.x),
                       mix(hash(i+float3(0,1,1)),hash(i+float3(1,1,1)),f.x),f.y),f.z);
    }
    float caustic(float2 p, float t) {
        p *= 5.0;
        float a = sin(p.x + sin(p.y*1.32+t*.16)) * sin(p.y - cos(p.x*.87-t*.12));
        float b = sin(p.x*.81-p.y*.43+t*.13) * cos(p.y*1.17+p.x*.31-t*.11);
        return pow(1.0-abs(a), 16.0)*.65 + pow(1.0-abs(b), 22.0)*.35;
    }

    float3 sunlight() { return normalize(float3(.55,1.0,.65)); }
    float3 viewRay(float2 uv, constant Uniforms& u) {
        if(u.widget.x>0.5) return float3(0,0,-1);
        float4 far = u.inverseViewProjection * float4(uv.x*2-1,1-uv.y*2,1,1);
        return normalize(far.xyz/far.w-u.camera.xyz);
    }
    float3 waterNormal(float2 p, float t) {
        float2 d1 = normalize(float2(1,.45)), d2 = normalize(float2(-.7,1)), d3=normalize(float2(.4,1));
        float2 slope = d1*.018*cos(dot(p,d1)*3.1+t*.46)
                     + d2*.013*cos(dot(p,d2)*5.4-t*.31)
                     + d3*.008*cos(dot(p,d3)*9.7+t*.57);
        return normalize(float3(-slope.x,1,-slope.y));
    }
    float2 bowlIntersections(float3 eye, float3 ray) {
        float3 origin=(eye-bowlCenter)/bowlRadii, direction=ray/bowlRadii;
        float a=dot(direction,direction), b=dot(origin,direction), c=dot(origin,origin)-1;
        float discriminant=b*b-a*c;
        if(discriminant<0) return float2(-1);
        float root=sqrt(discriminant);
        return float2((-b-root)/a,(-b+root)/a);
    }
    float3 roomLight(float3 direction, float daylight, constant Uniforms& u) {
        float height=smoothstep(-.85,.80,direction.y);
        float3 room=mix(u.wallLower.rgb,u.wallUpper.rgb,height);
        float side=smoothstep(-.75,.75,direction.x);
        room+=mix(u.themeKey.rgb,u.themeFill.rgb,side)*u.wallLower.w*.16;
        return room*mix(.23,1.0,daylight);
    }
    float tigerStripes(float2 p) {
        // Uneven, tapered bands follow the bowl's cylindrical coordinates.
        // Their phase never depends on the camera or time, so tilting reveals
        // the pattern on the curved glass rather than sliding a screen overlay.
        float phase=p.x*13.0+p.y*.55+sin(p.y*5.4)*1.1+sin(p.y*10.7+p.x*2.1)*.40;
        float band=floor(phase/3.14159265);
        float taper=smoothstep(-.25,.70,sin(p.y*4.3+band*2.17));
        float width=.025+.53*taper;
        return 1-smoothstep(width,width+.035,abs(cos(phase)));
    }
    float3 curvedGlass(float3 position, float3 inward, float3 eye, constant Uniforms& u) {
        float facing=clamp(abs(dot(inward,eye)),0.0,1.0);
        float fresnel=.035+.965*pow(1-facing,4.5);
        float3 reflection=reflect(-eye,inward);
        float3 transmission=refract(-eye,inward,1.0/1.33);
        float3 base=roomLight(transmission,u.control.z,u);
        float top=smoothstep(-1.7,2.2,position.y);
        base=mix(base,roomLight(float3(0,.4,0),u.control.z,u),.38);
        base*=mix(.79,1.10,top);
        // Broad studio light and two narrow window reflections describe the curved side walls.
        float angle=atan2(reflection.x,reflection.z);
        float ribbon=exp(-pow((angle-.91)*18.0,2.0))*.55
                    +exp(-pow((angle+1.16)*12.0,2.0))*.31;
        ribbon*=smoothstep(-1.62,-.95,position.y)*(1-smoothstep(1.5,2.5,position.y));
        float shoulder=pow(1-facing,1.5);
        float3 color=mix(base,roomLight(reflection,u.control.z,u),fresnel*.65);
        color*=1-.24*shoulder;
        float side=position.x/bowlRadii.x;
        float leftGlow=exp(-pow((side+.53)*2.25,2.0));
        float rightGlow=exp(-pow((side-.53)*2.25,2.0));
        // Colored light wraps the existing shell; its geometry and refraction
        // remain the same for solid wall colors and the two-color palettes.
        float patterned=saturate(u.themeKey.w+u.themeFill.w);
        color+=(u.themeKey.rgb*leftGlow+u.themeFill.rgb*rightGlow)*u.wallLower.w*(1-patterned)*mix(.30,1.0,u.control.z);
        if(patterned>.001) {
            float3 local=position-bowlCenter;
            float2 patternPoint=float2(atan2(local.x,-local.z),local.y/1.6);
            float3 ground=mix(u.wallLower.rgb,u.wallUpper.rgb,top);
            float3 tiger=mix(ground,u.themeKey.rgb*.70,tigerStripes(patternPoint));
            // Two soft pools of yellow, fixed to the shell. Circular falloff
            // makes distinct spots rather than a left-to-right color split.
            float2 wall=float2(patternPoint.x*1.5,local.y);
            float2 a=(wall-float2(-.43,.86))/float2(.67,.73);
            float2 b=(wall-float2(.47,-.73))/float2(.64,.69);
            float spots=saturate(exp(-dot(a,a)*2.0)+exp(-dot(b,b)*2.0));
            float3 sunset=mix(ground,u.themeFill.rgb,spots*.92);
            float3 motif=(tiger*u.themeKey.w+sunset*u.themeFill.w)/max(patterned,.001);
            motif*=mix(.23,1.0,u.control.z)*mix(.80,1.03,top)*(1-shoulder*.24);
            color=mix(color,motif,patterned*(1-fresnel*.25));
        }
        float3 rimLight=mix(float3(.72,.81,.79),mix(u.themeKey.rgb,u.themeFill.rgb,saturate(side*.5+.5)),u.wallUpper.w*.70);
        color+=rimLight*ribbon*(.16+shoulder*.54)*mix(.25,1.0,u.control.z);
        // An overhead softbox falls across the curved wall, leaving darker sides
        // behind the clear sculptures rather than lighting every surface equally.
        float2 softbox=(position.xy-float2(-.62,1.48))/float2(1.10,1.35);
        float pool=exp(-dot(softbox,softbox));
        color*=.64+pool*.63;
        color+=mix(float3(1,.94,.78),u.themeKey.rgb,.25)*pool*.075*mix(.25,1.0,u.control.z);
        // The glass-water contact is a curved meniscus, rather than a horizon across the scene.
        float meniscus=exp(-abs(position.y-waterHeight)*85.0);
        color+=float3(.25,.29,.26)*meniscus*mix(.3,1.0,u.control.z);
        return color;
    }
    float3 widgetWaterColor(float2 uv, constant Uniforms& u) {
        float top=1-uv.y;
        float3 color=mix(u.wallLower.rgb,u.wallUpper.rgb,top);
        float2 motif=float2((uv.x-.5)*1.55,(.5-uv.y)*2.0);
        if(u.themeKey.w>.01) color=mix(color,u.themeKey.rgb*.70,tigerStripes(motif)*u.themeKey.w);
        if(u.themeFill.w>.01) {
            float2 a=(uv-float2(.28,.29))/float2(.26,.28);
            float2 b=(uv-float2(.72,.70))/float2(.25,.26);
            float spots=saturate(exp(-dot(a,a)*2)+exp(-dot(b,b)*2));
            color=mix(color,u.themeFill.rgb,spots*.92*u.themeFill.w);
        }
        float2 lightSpot=(uv-float2(.28,.22))*float2(2.0,2.8);
        color+=float3(.075,.080,.070)*exp(-dot(lightSpot,lightSpot));
        float patterned=saturate(u.themeKey.w+u.themeFill.w);
        color+=mix(u.themeKey.rgb,u.themeFill.rgb,uv.x)*u.wallLower.w*.24*(1-patterned);
        float c=caustic(uv*float2(u.control.w*.65,.65),u.control.x);
        color+=color*c*.045;
        // A shallow, face-on sand strip rather than the perspective floor.
        float sandLine=.865+.003*sin(uv.x*8);
        float grain=noise(float3(uv*720,1));
        float3 sand=mix(float3(.78,.75,.68),float3(.94,.92,.85),.65+grain*.12);
        if(u.catalog.y==1) sand=mix(float3(.026,.040,.050),float3(.085,.11,.13),grain*.20+.3);
        if(u.catalog.y==2) sand=mix(float3(.72,.56,.54),float3(.92,.81,.76),grain*.20+.65);
        if(u.catalog.y==3) sand=mix(float3(.62,.67,.76),float3(.86,.90,.94),grain*.20+.65);
        sand*=.94+c*.055;
        sand*=mix(float3(1),mix(u.themeKey.rgb,u.themeFill.rgb,uv.x),u.wallUpper.w*.10);
        color=mix(color,sand,smoothstep(sandLine-.0015,sandLine+.0015,uv.y));
        float waterLine=.13+sin(uv.x*5)*.003;
        color=mix(color,mix(color,float3(.91,.94,.89),.28),1-smoothstep(waterLine-.001,waterLine+.001,uv.y));
        color+=float3(.15,.19,.17)*exp(-abs(uv.y-waterLine)*650);
        return color*mix(.28,1.0,u.control.z);
    }

    float3 waterColor(float2 uv, constant Uniforms& u) {
        if(u.widget.x>0.5) return widgetWaterColor(uv,u);
        float3 ray=viewRay(uv,u), eye=u.camera.xyz;
        float2 intersections=bowlIntersections(eye,ray);
        if(intersections.y<=0) return roomLight(ray,u.control.z,u);
        float3 hit=eye+ray*intersections.y;
        float3 inward=-normalize((hit-bowlCenter)/(bowlRadii*bowlRadii));
        float3 result=curvedGlass(hit,inward,-ray,u);
        float surfaceDistance=ray.y>.0001 ? (waterHeight-eye.y)/ray.y : 1000.0;
        float3 surfacePoint=eye+ray*surfaceDistance;
        float3 surfaceUnit=(surfacePoint-bowlCenter)/bowlRadii;
        if(surfaceDistance>0 && surfaceDistance<intersections.y && dot(surfaceUnit,surfaceUnit)<1 && surfacePoint.z<bowlFront) {
            float t=u.control.x*u.interaction.w;
            float3 n=waterNormal(surfacePoint.xz,t);
            float3 reflected=reflect(ray,-n);
            float grazing=pow(1-abs(dot(ray,n)),3.0);
            float streak=caustic(surfacePoint.xz*.73+reflected.xz*.4,t);
            result=mix(result,roomLight(reflected,u.control.z,u)*.80,.42+grazing*.28);
            result+=float3(.13,.15,.14)*pow(streak,3.0)*mix(.3,1.0,u.control.z);
        }
        return result;
    }

    float3 companionPoint(float3 p, float4 joint, float4 motion) {
        float species = motion.x, gait = motion.y, group = joint.w;
        float activity = motion.z, ambient = motion.w;
        float3 q = p - joint.xyz;
        if (group >= 10 && group < 20) {
            // Alternating crab feet swing forward, lift, then settle onto their
            // support plane. The carapace keeps its calm sideways orientation.
            float phase = gait + (group - 10) * 2.0944;
            float weight = smoothstep(.0, .085, length(q));
            p.x += sin(phase) * .020 * weight * activity;
            p.y += max(0.0, cos(phase)) * .018 * weight * activity;
        } else if (group == 30) {
            p.y += sin(ambient * .65 + sign(joint.x)) * .004 * smoothstep(0.0, .06, length(q));
        } else if (group >= 40 && group < 46) {
            float angle = sin(gait + group * 1.35) * (.10 + .32 * activity);
            p.xy = joint.xy + float2(q.x * cos(angle) - q.y * sin(angle), q.x * sin(angle) + q.y * cos(angle));
        } else if (group == 50) {
            float weight = smoothstep(0.0, .13, length(q));
            p.z += sin(ambient * .8 + joint.z * 25) * .012 * weight;
            p.y += cos(ambient * .65) * .005 * weight;
        } else if (group >= 80 && group < 85) {
            float weight=smoothstep(.006,.045,length(q));
            p.x+=sin(gait+group*1.2566)*.004*weight*activity;
            p.y+=max(0.0,cos(gait+group*1.2566))*.0025*weight*activity;
        } else if (group >= 90 && group < 95) {
            float weight=smoothstep(.0,.050,length(q));
            p.x+=sin(ambient*.48+group*1.2566)*.002*weight;
            p.z+=cos(ambient*.41+group*1.2566)*.002*weight;
        } else if (group == 70) {
            // The hull stays rigid while the small propeller idles during a hover.
            p.yz = joint.yz + float2(q.y*cos(gait)-q.z*sin(gait), q.y*sin(gait)+q.z*cos(gait));
        } else if (group == 60) {
            p.y += sin(gait) * (.003 + .011 * activity) * smoothstep(0.0, .06, length(q));
        }
        if (species == 2) {
            float tail = 1.0 - smoothstep(-.18, .08, p.x);
            p.y += sin(gait * .5 - p.x * 15) * .006 * tail * activity;
            p.z += sin(gait * .5 - p.x * 13) * .004 * tail * activity;
            p.y += sin(ambient * 1.1) * .004 * (1 - activity);
        } else if (species == 7) {
            p.y += sin(ambient * .9) * .003 * (1 - activity);
        } else if (species >= 4 && species <= 6) {
            // A low traveling contraction carries the soft body over the floor.
            float wave = gait - p.x * 24;
            p.x *= 1 + sin(gait) * .028 * activity;
            p.z += sin(wave) * .006 * activity;
            p.y += (1 + sin(wave)) * .002 * smoothstep(.008, .055, p.y) * activity;
        } else if (species == 1 && p.y < .07) {
            p.z += sin(gait - p.x * 30) * .0025 * (1 - smoothstep(.04, .07, p.y)) * activity;
        }
        return p;
    }

    float3 collectionSwim(float3 p, float t, float species, bool fin, float amplitude, float4 motion) {
        if(species==11) {
            // Rotate back into the ray's broad wing plane before applying its wave.
            float wing=p.y*.581035+p.z*.813878;
            float lift=sin(t*1.45-abs(wing)*5+p.x*2)*pow(abs(wing)/.75,1.7)*.105;
            p.y+=lift*.813878*amplitude;
            p.z-=lift*.581035*amplitude;
            p.z+=sin(t*1.4-p.x*5)*.028*(1-smoothstep(-.7,-.28,p.x))*amplitude;
        } else if(species==12) {
            float tail=1-smoothstep(-1.17,.40,p.x);
            p.z+=sin(t*2.2+p.x*7.2)*.13*tail*amplitude;
            p.y+=sin(t*1.8+p.x*6)*.029*tail*amplitude;
        } else if(species==19) {
            float flutter=motion.w==100 ? smoothstep(.025,.16,length(p-motion.xyz)) : 0;
            float tail=1-smoothstep(-.8,.30,p.x);
            p.z+=sin(t*1.5-p.x*6)*.028*tail*amplitude;
            if(fin) {
                p.z+=sin(t*1.8+p.y*9-p.x*5)*.018*flutter*amplitude;
                p.y+=sin(t*1.3-p.x*5)*.008*flutter*amplitude;
            }
        } else if(species==13) {
            float flutter=motion.w==110 ? smoothstep(.015,.11,length(p-motion.xyz)) : 0;
            p.z+=sin(t*1.5-p.y*5)*.007*(1-smoothstep(-.20,.2,p.y))*amplitude;
            if(fin) p.z+=sin(t*7+p.y*19)*.012*flutter*amplitude;
        } else {
            float tail=1-smoothstep(-.06,.36,p.x);
            float speed=species==14 ? 4.3 : 2.0;
            p.z+=sin(t*speed-p.x*7)*.015*tail*amplitude;
            if(fin) {
                float finWeight=max(tail,smoothstep(.06,.28,abs(p.y)));
                p.z+=sin(t*(species==14 ? 8.0 : 2.7)-p.x*8+p.y*5)*.024*finWeight*amplitude;
            }
        }
        return p;
    }

    vertex Varying aquariumDepthVertex(uint id [[vertex_id]],
                                      const device Vertex* vertices [[buffer(0)]],
                                      constant Uniforms& u [[buffer(1)]]) {
        Vertex v = vertices[id];
        float3 p = v.position.xyz;
        float3 normal = v.normal.xyz;
        float t = u.control.x, kind = u.control.y;
        if (kind == 10.0) {
            float3 tangent = normalize(cross(normal, abs(normal.y) < .9 ? float3(0,1,0) : float3(1,0,0)));
            float3 bitangent = cross(normal, tangent);
            float3 moved = companionPoint(p, v.motion, u.companionMotion);
            float3 dx = companionPoint(p + tangent * .001, v.motion, u.companionMotion) - moved;
            float3 dy = companionPoint(p + bitangent * .001, v.motion, u.companionMotion) - moved;
            normal = normalize(cross(dx, dy));
            p = moved;
        }
        if (kind == 2.0) {
            float weight = pow(v.uv.y, 1.7);
            p.x += sin(t*1.1+p.y*3.1+p.z*4.0)*.024*weight*u.interaction.w;
            p.z += cos(t*.8+p.x*4.0)*.018*weight*u.interaction.w;
        }
        if (kind == 3.0 || kind == 4.0 || kind == 7.0) {
            if(u.catalog.x>=11) {
                float3 tangent=normalize(cross(normal,abs(normal.y)<.9 ? float3(0,1,0) : float3(1,0,0)));
                float3 bitangent=cross(normal,tangent);
                float3 moved=collectionSwim(p,t,u.catalog.x,kind==4,u.interaction.w,v.motion);
                float3 dx=collectionSwim(p+tangent*.001,t,u.catalog.x,kind==4,u.interaction.w,v.motion)-moved;
                float3 dy=collectionSwim(p+bitangent*.001,t,u.catalog.x,kind==4,u.interaction.w,v.motion)-moved;
                normal=normalize(cross(dx,dy));
                p=moved;
            } else {
                float tail = 1.0-smoothstep(-.04,.36,p.x);
                p.z += sin(t*2.0-p.x*7.0)*.012*tail*u.interaction.w;
                if (kind == 4.0) {
                    float fin = max(tail, smoothstep(.055,.30,abs(p.y)));
                    p.z += sin(t*2.4-p.x*8.0+p.y*5.0)*.025*fin*u.interaction.w;
                    p.y += sin(t*1.6-p.x*7.0)*.012*fin*u.interaction.w;
                }
            }
        }
        if(kind == 9.0) {
            float seed=v.uv.z;
            float speed=.090+.038*fract(seed*.371);
            float travel=waterHeight-sandHeight;
            float age=fract(t*speed*u.interaction.w/travel+fract(seed*.618034));
            float born=smoothstep(0.0,.028,age);
            float dissolve=1-smoothstep(.965,1.0,age);
            p*=born*dissolve*(.74+age*.26);
            int emitter=int(seed)%3;
            float2 origin=emitter==0 ? float2(-.50,-.72) : (emitter==1 ? float2(.48,-.35) : float2(.18,.38));
            float drift=t*speed*u.interaction.w+seed*2.399;
            if(u.widget.x>0.5) {
                p*=.78;
                p+=float3((origin.x*1.9+sin(seed*4.1)*.13),
                          mix(-.70,.70,age)*u.widget.w,.72);
            } else {
                p+=float3(origin.x+sin(drift*1.7)*.045+sin(seed*4.1)*.085,
                          sandHeight+age*travel,
                          origin.y+sin(drift*.9)*.035+cos(seed*2.1)*.06);
            }
        }
        Varying o;
        o.local = v.position.xyz;
        float4 world = u.model * float4(p,1);
        o.position = u.viewProjection * world;
        o.world = world.xyz;
        o.normal = normalize((u.model * float4(normal,0)).xyz);
        o.uv = v.uv;
        return o;
    }

    vertex Varying aquariumBackgroundVertex(uint id [[vertex_id]]) {
        float2 p[3] = { float2(-1,-1), float2(3,-1), float2(-1,3) };
        Varying o;
        o.position = float4(p[id], .99999, 1);
        o.uv = float4(p[id].x*.5+.5, .5-p[id].y*.5, 0, 0);
        o.local = float3(0);
        o.world = float3(0); o.normal = float3(0,0,1);
        return o;
    }

    fragment float4 aquariumBackgroundFragment(Varying in [[stage_in]],
                                               constant Uniforms& u [[buffer(1)]]) {
        float2 uv = in.uv.xy;
        float2 delta = uv-u.interaction.xy;
        delta.x *= u.control.w;
        float radius = length(delta), age = u.interaction.z;
        float ripple = sin(radius*110-age*10)*exp(-pow((radius-age*.12)*16,2))*exp(-age*1.5);
        if(age >= 0 && age < 3) uv += normalize(delta+float2(.00001))*ripple*.002;
        return float4(waterColor(uv,u),1);
    }

    fragment void aquariumShadowFragment(Varying in [[stage_in]]) {
        float3 unit=(in.world-bowlCenter)/bowlRadii;
        if(dot(unit,unit)>1.005 || in.world.z>bowlFront) discard_fragment();
    }

    float shadowVisibility(float3 world, float3 normal, constant Uniforms& u, depth2d<float> shadow) {
        constexpr sampler s(filter::linear, compare_func::less_equal, address::clamp_to_edge);
        float4 p=u.lightViewProjection*float4(world+normal*.004,1);
        float3 q=p.xyz/p.w;
        float2 uv=float2(q.x*.5+.5,.5-q.y*.5);
        if(any(uv<0.0)||any(uv>1.0)||q.z>1.0) return 1.0;
        float result=0;
        for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++)
            result+=shadow.sample_compare(s,uv+float2(x,y)/float(shadow.get_width())*1.6,q.z-.0012);
        return result/9.0;
    }

    float3 caneColor(float index) {
        int i=int(round(index))%7;
        if(i==0) return float3(.004,.31,.085);
        if(i==1) return float3(.004,.35,.39);
        if(i==2) return float3(.008,.024,.43);
        if(i==3) return float3(.94,.27,.009);
        if(i==4) return float3(.53,.006,.018);
        if(i==5) return float3(.68,.81,.72);
        return float3(.025,.055,.16);
    }

    float3 sculptureColor(float index) {
        int i=int(round(index));
        if(i==0) return float3(.007,.050,.39);
        if(i==1) return float3(.005,.24,.10);
        if(i==2) return float3(.12,.57,.60);
        if(i==3) return float3(.95,.40,.025);
        if(i==4) return float3(.60,.012,.060);
        if(i==5) return float3(.86,.91,.87);
        if(i==6) return float3(.21,.035,.40);
        if(i==7) return float3(.92,.27,.18);
        if(i==8) return float3(.28,.13,.040);
        if(i==9) return float3(.005,.012,.024);
        if(i==10) return float3(.96,.83,.53);
        return float3(.001,.003,.006);
    }

    float3 fishPigment(float3 p, float species, bool fin, thread float& ink) {
        int kind=int(round(species));
        float3 color;
        float flow=sin(p.x*23+p.y*18+sin(p.z*20)*2);
        ink=fin ? .13 : .40;
        if(kind==0) {
            color=mix(float3(.003,.019,.30),float3(.012,.32,.59),smoothstep(-.2,.9,flow));
            color=mix(color,float3(.22,.72,.76),pow(.5+.5*sin(p.x*15-p.y*22),22.0)*.50);
        } else if(kind==1) {
            float coral=smoothstep(.47,.62,noise(p*float3(9,15,18)+2));
            color=mix(float3(.89,.90,.81),float3(.85,.07,.025),coral);
            float onyx=smoothstep(.72,.82,noise(p*20+13))*(1-coral);
            color=mix(color,float3(.014,.020,.037),onyx*.90);
            ink=fin ? .10 : mix(.72,.42,coral);
        } else if(kind==3) {
            color=mix(float3(.98,.42,.025),float3(.99,.72,.28),smoothstep(-.3,.8,flow)*.6);
            color=mix(color,float3(.98,.88,.62),pow(.5+.5*sin(p.x*18+p.y*21),30.0)*.3);
            ink=fin ? .10 : .32;
        } else if(kind==4) {
            float ribbon=smoothstep(.42,.84,sin(p.x*22-p.y*15+sin(p.y*24)));
            color=mix(float3(.005,.42,.46),float3(.77,.012,.22),ribbon*(fin ? .85 : .50));
            color=mix(color,float3(.31,.81,.67),pow(.5+.5*flow,20.0)*.42);
        } else if(kind==5) {
            color=mix(float3(.58,.012,.019),float3(.98,.23,.018),smoothstep(-.13,.10,p.y));
            color=mix(color,float3(.98,.63,.19),exp(-pow((p.y-.015)*100,2))*.75);
            ink=fin ? .11 : .35;
        } else if(kind==6) {
            float band=pow(.5+.5*sin(p.x*33+p.y*3),18.0);
            color=mix(float3(.69,.85,.89),float3(.030,.07,.28),band*.82);
            color+=float3(.14,.055,.10)*pow(.5+.5*sin(p.y*12+p.z*30),3.0);
            ink=fin ? .08 : .41;
        } else if(kind==7) {
            float spot=smoothstep(.63,.76,noise(p*float3(37,42,42)));
            color=mix(float3(.31,.43,.48),float3(.025,.044,.070),spot*.92);
            color=mix(color,float3(.79,.84,.78),1-smoothstep(-.07,.005,p.y));
            ink=fin ? .13 : .51;
        } else if(kind==8) {
            float wave=sin(p.y*40+sin(p.x*18)*3+p.z*14);
            color=mix(float3(.085,.008,.20),float3(.46,.17,.49),smoothstep(-.45,.8,wave));
            color=mix(color,float3(.76,.56,.34),pow(.5+.5*wave,32.0)*.48);
            ink=fin ? .16 : .45;
        } else if(kind==9) {
            color=mix(float3(.41,.58,.63),float3(.87,.91,.84),smoothstep(-.07,.07,p.y));
            float silver=pow(.5+.5*sin(p.x*57+p.y*22),20.0);
            color=mix(color,float3(.80,.83,.71),silver*.17);
            ink=fin ? .065 : .32;
        } else if(kind==11) {
            float edge=smoothstep(.08,.43,abs(p.y));
            float fleck=pow(.5+.5*sin(p.x*67+sin(p.z*39)*2),30.0);
            color=mix(float3(.42,.76,.81),float3(.035,.22,.42),edge*.58);
            color=mix(color,float3(.88,.87,.69),fleck*.28);
            ink=fin ? .10 : .18;
        } else if(kind==12) {
            color=mix(float3(.008,.026,.45),float3(.012,.36,.63),smoothstep(-.09,.08,p.y));
            if(fin) color=mix(float3(.98,.60,.075),float3(.91,.80,.34),.5+.5*sin(p.x*8));
            ink=fin ? .16 : .33;
        } else if(kind==13) {
            float ribbon=pow(.5+.5*sin(p.y*38+p.x*10),12.0);
            color=mix(float3(.93,.36,.32),float3(.98,.69,.38),smoothstep(-.3,.42,p.y));
            color=mix(color,float3(.98,.90,.74),ribbon*.30);
            ink=fin ? .11 : .40;
        } else if(kind==14) {
            float belly=1-smoothstep(-.035,.11,p.y);
            float2 cell=p.xy*float2(27,30);
            cell.x+=floor(cell.y)*.5;
            float spot=1-smoothstep(.12,.21,length(fract(cell)-.5));
            color=mix(float3(.94,.52,.11),float3(.93,.90,.74),belly);
            color=mix(color,float3(.27,.12,.025),spot*(1-belly)*.65);
            if(fin) color=float3(.92,.85,.60);
            ink=fin ? .07 : .37;
        } else if(kind==15) {
            float band=1-smoothstep(.023,.043,abs(p.x+p.y*.24-.41));
            float pearl=1-smoothstep(.055,.105,abs(p.x+p.y*.22-.18));
            color=mix(float3(.96,.67,.035),float3(.94,.93,.77),pearl*.90);
            color=mix(color,float3(.014,.025,.035),band*.95);
            ink=fin ? .15 : .45;
        } else if(kind==16) {
            float ribbon=pow(.5+.5*sin(p.x*25+sin(p.y*29)*2.3+p.z*12),7.0);
            float trim=pow(.5+.5*sin(p.x*25+sin(p.y*29)*2.3+p.z*12+.75),18.0);
            color=mix(float3(.003,.31,.32),float3(.96,.21,.018),ribbon*.95);
            color=mix(color,float3(.17,.76,.66),trim*.80);
            ink=fin ? .13 : .40;
        } else if(kind==17) {
            float sweep=p.y-.065*sin((p.x+.15)*6);
            float band=1-smoothstep(.026,.055,abs(sweep));
            color=mix(float3(.010,.055,.61),float3(.001,.012,.045),band*.94);
            if(fin && p.x<-.16) color=float3(.99,.77,.02);
            ink=fin ? .16 : .40;
        } else if(kind==19) {
            float veins=pow(.5+.5*sin(p.x*36+p.y*21+sin(p.y*14)),16.0);
            color=mix(float3(.025,.21,.070),float3(.38,.63,.19),smoothstep(-.18,.36,p.y));
            color=mix(color,float3(.93,.77,.38),veins*.34);
            if(fin) color=mix(color,float3(.82,.85,.49),.32);
            ink=fin ? .10 : .30;
        } else if(kind==18) {
            float belly=1-smoothstep(-.03,.045,p.y);
            color=mix(float3(.014,.19,.29),float3(.73,.86,.84),belly);
            if(fin) {
                float ray=pow(.5+.5*sin(p.x*49+p.y*11),18.0);
                color=mix(float3(.035,.37,.52),float3(.61,.85,.87),ray*.56);
            }
            ink=fin ? .13 : .31;
        } else {
            float belly=1-smoothstep(-.06,.028,p.y+sin(p.x*7)*.018);
            color=mix(float3(.007,.055,.14),float3(.82,.88,.85),belly);
            float pleat=pow(.5+.5*sin(p.x*60+sin(p.y*14)*2),16.0)*belly;
            color*=1-pleat*.13;
            if(fin) color=mix(color,float3(.21,.45,.57),.30);
            ink=fin ? .17 : .50;
        }
        return color;
    }

    float3 atelierReflection(float3 reflection, float daylight, constant Uniforms& u) {
        float angle=atan2(reflection.x,reflection.z);
        float a=(angle+.52)*3.4, b=(reflection.y-.42)*2.0;
        float c=(angle-.92)*16.0, d=reflection.y*1.4;
        float key=exp(-a*a*a*a-b*b*b*b);
        float edge=exp(-c*c-d*d*d*d);
        float strip=exp(-pow((angle+.13+reflection.y*.24)*25,2.0))
            *exp(-pow((reflection.y-.10)*1.35,4.0));
        float ceiling=pow(max(dot(reflection,normalize(float3(-.15,.90,.30))),0.0),45.0);
        // Dark studio panels between the softboxes give clear glass a visible shape.
        float3 room=mix(float3(.008,.027,.031),roomLight(reflection,daylight,u)*.24,
                        smoothstep(-.45,.8,reflection.y));
        float3 keyColor=mix(float3(1.0,.89,.66),u.themeKey.rgb,u.wallUpper.w*.30);
        float3 fillColor=mix(float3(.53,.85,1.0),u.themeFill.rgb,u.wallUpper.w*.40);
        return room+(keyColor*(key*5.5+strip*3.2)+fillColor*edge*6.0+ceiling*3.0)*mix(.35,1.0,daylight);
    }

    float3 artGlass(Varying in, float3 n, float3 eye, float3 pigment, float ink, float thickness,
                    constant Uniforms& u, texture2d<float> sceneColor, float visibility) {
        constexpr sampler s(filter::linear,address::clamp_to_edge);
        if(dot(n,eye)<0) n=-n;
        float facing=clamp(dot(n,eye),0.0,1.0);
        float fresnel=.042+.958*pow(1-facing,5.0);
        float2 uv=in.position.xy/float2(u.camera.w*u.control.w,u.camera.w);
        float3 entering=refract(-eye,n,1.0/1.52);
        float path=max(thickness,.012)*sqrt(max(facing,.02));
        float3 exitPoint=in.world+entering*thickness*2.3;
        float3 innerNormal=normalize(float3(-n.x*.72,-n.y*.72,n.z));
        float rearPearl=0;
        if(u.control.y==3 && u.catalog.x!=11 && u.catalog.x!=12 && u.catalog.x!=13 && u.catalog.x!=14 && u.catalog.x!=19) {
            // Follow the ray to a curved rear interface inside the fish volume.
            // The ellipsoid is a bounded approximation of its sculpted spindle.
            float3 shape=fishProportions[clamp(int(u.catalog.x),0,\#(FishSpecies.allCases.count - 1))];
            float3 center=float3(.525+(.13-.525)*shape.x,.024*shape.y,0);
            float3 radii=float3(.414,.17,.105)*shape;
            float3x3 rotation=float3x3(normalize(u.model[0].xyz),normalize(u.model[1].xyz),normalize(u.model[2].xyz));
            float3 ray=transpose(rotation)*entering;
            float3 origin=(in.local-center)/radii, direction=ray/radii;
            float a=dot(direction,direction), b=dot(origin,direction), c=dot(origin,origin)-1;
            float distance=clamp((-b+sqrt(max(0.0,b*b-a*c)))/max(a,.001),.006,.7);
            float3 rear=in.local+ray*distance;
            innerNormal=normalize(rotation*normalize((rear-center)/(radii*radii)));
            exitPoint=(u.model*float4(rear,1)).xyz;
            path=distance;
            if(u.catalog.x==2) {
                float x=rear.x+rear.y*.16+sin(rear.y*9)*.008;
                rearPearl=max(1-smoothstep(.029,.044,abs(x-.25)),1-smoothstep(.022,.038,abs(x-.006)));
            }
        }
        float4 exitClip=u.viewProjection*float4(exitPoint,1);
        float2 exitUV=float2(exitClip.x/exitClip.w*.5+.5,.5-exitClip.y/exitClip.w*.5);
        float2 bend=(exitUV-uv)+float2(n.x/u.control.w,-n.y)*thickness*.032;
        float2 separation=bend*.045;
        float3 behind=float3(sceneColor.sample(s,uv+bend+separation).r,
                             sceneColor.sample(s,uv+bend).g,
                             sceneColor.sample(s,uv+bend-separation).b);
        float flow=.92+.08*sin(in.local.x*28+sin(in.local.y*19)*2+in.local.z*15);
        float3 absorption=exp(log(max(pigment,float3(.015)))*path*5.0*flow);
        float3 incident=behind+float3(.32,.26,.18)*mix(.30,1.0,u.control.z)*(1-ink);
        float3 transmitted=incident*absorption;
        transmitted=mix(transmitted,float3(.94,.83,.62)*sqrt(absorption)*mix(.35,1.0,u.control.z),rearPearl*.48);
        float diffuse=max(dot(n,sunlight()),0.0);
        float3 inclusion=pigment*(.16+diffuse*.68)*mix(.33,1.0,u.control.z);
        inclusion*=mix(float3(1),mix(u.themeKey.rgb,u.themeFill.rgb,saturate(n.x*.5+.5)),u.wallUpper.w*.13);
        float3 color=mix(transmitted,inclusion,ink)*(.76+.24*visibility);
        float3 reflected=reflect(-eye,n);
        float reflectionWeight=min(.94,fresnel*1.65);
        color=color*(1-reflectionWeight)+atelierReflection(reflected,u.control.z,u)*reflectionWeight;
        // A second interface returns a tint of the studio through the colored core.
        // This is a local approximation of internal reflection, kept independent of time.
        float3 internal=atelierReflection(reflect(entering,innerNormal),u.control.z,u);
        color+=internal*sqrt(absorption)*(.12+.14*pow(1-facing,2.0))*(1-ink);
        float warmTransmission=pow(saturate(dot(entering,normalize(float3(.40,-.55,-.75)))),7.0);
        color+=sqrt(pigment)*warmTransmission*(1-ink)*.22*mix(.3,1.0,u.control.z);
        float3 halfLight=normalize(sunlight()+eye);
        float glint=pow(max(dot(n,halfLight),0.0),170.0);
        color+=mix(float3(1.0,.94,.81),u.themeKey.rgb,u.wallUpper.w*.60)*glint*2.4*mix(.3,1.0,u.control.z)*(.6+.4*visibility);
        // A cool second reflection and transmitted light keep thin glass luminous.
        float coolGlint=pow(max(dot(n,normalize(eye+float3(-.8,.45,.6))),0.0),240.0);
        float backlight=pow(max(dot(-n,sunlight()),0.0),2.0)*(1-ink);
        color+=mix(float3(.62,.84,1.0),u.themeFill.rgb,u.wallUpper.w*.75)*coolGlint*1.45*mix(.24,1.0,u.control.z);
        color+=sqrt(max(pigment,float3(0)))*backlight*.23*mix(.2,1.0,u.control.z);
        float rim=pow(1-facing,9.0);
        color+=float3(.54,.72,.73)*rim*.16*mix(.3,1.0,u.control.z);
        return color;
    }

    float3 airBubble(Varying in, float3 n, float3 eye, constant Uniforms& u, texture2d<float> sceneColor) {
        constexpr sampler s(filter::linear,address::clamp_to_edge);
        if(dot(n,eye)<0) n=-n;
        float facing=saturate(dot(n,eye));
        float rim=pow(1-facing,3.2);
        float2 uv=in.position.xy/float2(u.camera.w*u.control.w,u.camera.w);
        // Air in water is a diverging lens. Its bend is opposite to solid glass.
        float distance=max(length(u.camera.xyz-in.world),.5);
        float2 bend=-float2(n.x/u.control.w,-n.y)*in.uv.w*.80/distance;
        float2 dispersion=bend*.085;
        float3 transmitted=float3(sceneColor.sample(s,uv+bend+dispersion).r,
                                   sceneColor.sample(s,uv+bend).g,
                                   sceneColor.sample(s,uv+bend-dispersion).b);
        float3 reflected=atelierReflection(reflect(-eye,n),u.control.z,u);
        float fresnel=.020+.70*pow(1-facing,4.0);
        float3 color=mix(transmitted,reflected,fresnel);
        color*=1-rim*.16;
        float glint=pow(max(dot(n,normalize(eye+sunlight())),0.0),110.0);
        float lowerGlint=pow(max(dot(n,normalize(eye+float3(-.7,-.4,.6))),0.0),160.0);
        color+=(mix(float3(1,.96,.86),u.themeKey.rgb,u.wallUpper.w*.70)*glint*3.4
                +mix(float3(.60,.86,1),u.themeFill.rgb,u.wallUpper.w*.75)*lowerGlint*1.4)*mix(.22,1.0,u.control.z);
        float arc=pow(1-facing,6.0)*(.5+.5*sin(atan2(n.y,n.x)*2+in.uv.z));
        color+=float3(.33,.48,.56)*arc*.30*mix(.22,1.0,u.control.z);
        return color;
    }

    float3 brightSample(texture2d<float> scene, float2 uv) {
        constexpr sampler s(filter::linear,address::clamp_to_edge);
        float3 c=scene.sample(s,uv).rgb;
        return c*(max(max(c.r,max(c.g,c.b))-.95,0.0)/max(max(c.r,max(c.g,c.b)),.001));
    }

    fragment float4 aquariumOpticsFragment(Varying in [[stage_in]],
                                           constant Uniforms& u [[buffer(1)]],
                                           texture2d<float> scene [[texture(0)]]) {
        constexpr sampler s(filter::linear,address::clamp_to_edge);
        float2 uv=in.uv.xy;
        if(u.widget.x>0.5) {
            float2 p=(uv-.5)*float2(u.control.w,1);
            // Fill the snapshot; WidgetKit supplies the outer rounded corners.
            float distance=min(min(uv.x,1-uv.x)*u.control.w,min(uv.y,1-uv.y));
            float rim=exp(-distance*180);
            float2 bend=normalize(p+float2(.0001))*rim*.005/float2(u.control.w,1);
            float2 sampleUV=clamp(uv-bend,float2(.001),float2(.999));
            float3 color=scene.sample(s,sampleUV).rgb;
            color+=brightSample(scene,sampleUV)*.045;
            float glint=.30+.70*pow(saturate(.5-p.x+p.y),3.0);
            color+=mix(float3(.74,.89,.92),float3(1,.92,.73),uv.x)*rim*glint*.37*mix(.3,1.0,u.control.z);
            color*=1-exp(-abs(distance-.019)*150)*.045;
            float peak=max(color.r,max(color.g,color.b));
            if(peak>.88) color*=(.88+.12*(1-exp(-(peak-.88)/.24)))/peak;
            return float4(color,1);
        }
        float aspect=u.control.w, t=u.control.x*u.interaction.w;
        float2 p=(uv-.5)*float2(aspect,1);
        float2 sideDistance=float2(uv.x,1-uv.x)*aspect;
        float left=exp(-sideDistance.x*sideDistance.x/.00125);
        float right=exp(-sideDistance.y*sideDistance.y/.00125);
        float top=exp(-uv.y*uv.y/.0018);
        float bottom=exp(-(1-uv.y)*(1-uv.y)/.00032)*.18;
        float edge=saturate(left+right+top*.60+bottom);
        // Gentle optical thickness at the viewing cut, with no added glass ledge.
        float2 slope=float2(right-left,(bottom-top*.55));
        float breathe=1+.08*sin(t*.33+uv.y*8)+.08*u.camera.x;
        float2 bend=slope*float2(.013/aspect,.012)*breathe;
        bend.y+=(left+right)*sin(uv.y*10+t*.24+u.camera.y)*.0018;
        float2 lensUV=clamp(uv-bend,float2(.001),float2(.999));
        float2 dispersion=bend*.075;
        float3 color=float3(scene.sample(s,lensUV+dispersion).r,
                            scene.sample(s,lensUV).g,
                            scene.sample(s,lensUV-dispersion).b);

        float2 pixel=1.0/float2(scene.get_width(),scene.get_height());
        float3 bloom=brightSample(scene,lensUV)*.18;
        constexpr float2 directions[8]={float2(1,0),float2(.707,.707),float2(0,1),float2(-.707,.707),
                                       float2(-1,0),float2(-.707,-.707),float2(0,-1),float2(.707,-.707)};
        for(int i=0;i<8;i++) {
            bloom+=brightSample(scene,lensUV+directions[i]*pixel*3.0)*.065;
            bloom+=brightSample(scene,lensUV+directions[i]*pixel*10.0)*.0375;
        }
        color+=bloom*.28;

        // Narrow moving light ribbons live inside broad transparent edge lenses.
        float width=.008+.003*sin(uv.y*5+t*.15+u.camera.x*.5);
        float lineLeft=exp(-pow((sideDistance.x-width)*430,2.0));
        float lineRight=exp(-pow((sideDistance.y-width*1.15)*380,2.0));
        float leftLight=pow(.5+.5*sin(uv.y*5.7+t*.16+u.camera.y*.7),5.0);
        float rightLight=pow(.5+.5*sin(uv.y*6.5-t*.13+2.2-u.camera.y*.6),5.0);
        float baseFade=1-smoothstep(.78,.99,uv.y);
        float light=mix(.24,1.0,u.control.z);
        color*=1-edge*.035;
        color+=(mix(float3(.62,.84,1.0),u.themeKey.rgb,u.wallUpper.w)*lineLeft*leftLight
                +mix(float3(1.0,.85,.61),u.themeFill.rgb,u.wallUpper.w)*lineRight*rightLight)*baseFade*.50*light;
        float glimmer=caustic(float2(p.x*1.4,uv.y*.65)+float2(u.camera.x*.09,u.camera.y*.08),t);
        color+=float3(.53,.72,.79)*glimmer*edge*.10*light;
        // A soft shoulder preserves the pale sand while rolling off HDR reflections.
        float peak=max(color.r,max(color.g,color.b));
        if(peak>.88) color*=(.88+.12*(1-exp(-(peak-.88)/.24)))/peak;
        return float4(color,1);
    }

    fragment float4 aquariumDepthFragment(Varying in [[stage_in]],
                                          constant Uniforms& u [[buffer(1)]],
                                          texture2d<float> sceneColor [[texture(0)]],
                                          depth2d<float> shadow [[texture(1)]]) {
        float kind=u.control.y, t=u.control.x;
        float3 bowlUnit=(in.world-bowlCenter)/bowlRadii;
        if(u.widget.x<.5 && kind!=6 && (dot(bowlUnit,bowlUnit)>1.005 || in.world.z>bowlFront)) discard_fragment();
        if(u.widget.x>.5 && kind!=9 && in.world.y < -u.widget.w*.73-.035) discard_fragment();
        float3 n=normalize(in.normal), eye=u.widget.x>.5 ? float3(0,0,1) : normalize(u.camera.xyz-in.world), light=sunlight();
        float3 color;
        if(kind==9.0) return float4(airBubble(in,n,eye,u,sceneColor),1);
        float visibility=shadowVisibility(in.world,n,u,shadow);
        if(kind==6.0) {
            float2 screenUV=in.position.xy/float2(u.camera.w*u.control.w,u.camera.w);
            float3 ray=viewRay(screenUV,u);
            float surfaceDistance=ray.y>.0001 ? (waterHeight-u.camera.y)/ray.y : 1000.0;
            float3 surfacePoint=u.camera.xyz+ray*surfaceDistance;
            float3 unit=(surfacePoint-bowlCenter)/bowlRadii;
            if(surfaceDistance>0 && surfaceDistance<length(in.world-u.camera.xyz) && dot(unit,unit)<1 && surfacePoint.z<bowlFront) {
                return float4(waterColor(screenUV,u),1);
            }
            color=curvedGlass(in.world,n,eye,u);
            float2 surface=in.world.xz+light.xz*((waterHeight-in.world.y)/light.y);
            float c=caustic(surface,t*u.interaction.w);
            color*=.94+.06*visibility;
            color+=color*c*.085*visibility*u.interaction.w;
            return float4(color,1);
        }
        if(kind==1.0) {
            // Soft ivory sand leaves a quiet base beneath the glass sculptures.
            float grain=noise(in.world*820.0);
            color=mix(float3(.76,.72,.64),float3(.94,.92,.85),grain*.24+.64);
            if(u.catalog.y==1) color=mix(float3(.026,.040,.050),float3(.085,.11,.13),grain*.20+.3);
            if(u.catalog.y==2) color=mix(float3(.72,.56,.54),float3(.92,.81,.76),grain*.20+.65);
            if(u.catalog.y==3) color=mix(float3(.62,.67,.76),float3(.86,.90,.94),grain*.20+.65);
            float diffuse=max(dot(n,light),0.0);
            color*=mix(.32,1.0,u.control.z)*(.58+.39*diffuse)*(.72+.28*visibility);
            float2 surface=in.world.xz+light.xz*((waterHeight-in.world.y)/light.y);
            float c=caustic(surface,t*u.interaction.w);
            color+=color*c*.22*u.interaction.w;
            float3 themeBounce=mix(u.themeKey.rgb,u.themeFill.rgb,smoothstep(-.8,.8,in.world.x));
            color*=mix(float3(1),themeBounce,u.wallUpper.w*.12);
            color+=themeBounce*c*u.wallLower.w*.055*mix(.3,1.0,u.control.z);
            float2 fishPool=u.fishLight.xz-light.xz*((u.fishLight.y-in.world.y)/light.y);
            float2 delta=(in.world.xz-fishPool)/float2(.36,.20);
            float pool=exp(-dot(delta,delta)*2.0)*(.45+.55*c);
            color+=float3(.15,.055,.005)*pool*u.control.z;
            float2 glassPool=(in.world.xz-float2(-.48,-.28))/float2(.66,.85);
            float glassGlow=exp(-dot(glassPool,glassPool)*2)*(.35+.65*c);
            color+=float3(.014,.070,.066)*glassGlow*u.control.z;
            float4 lamps[2]={u.featureLight0,u.featureLight1};
            for(int i=0;i<2;i++) if(lamps[i].w>0) {
                float2 pool=(in.world.xz-lamps[i].xz)/(float2(.35,.30)*lamps[i].w);
                color+=float3(.26,.16,.044)*exp(-dot(pool,pool)*2)*mix(.7,1.0,u.control.z);
            }
            return float4(color,1);
        }
        float3 pigment;
        float ink=.65, thickness=max(in.uv.w,.008);
        if(kind==0.0) {
            float3 p=in.local;
            float warp=noise(p*9.0+float3(in.uv.z))*2.0;
            float wave=p.y*29+p.x*9+sin(p.z*11+p.x*8+in.uv.z)*4.2
                      +sin(p.y*9-p.x*7)*3.1+warp;
            float stripe=smoothstep(.35,.88,sin(wave));
            pigment=mix(float3(.003,.011,.028),float3(.006,.13,.20),stripe);
            float cobalt=smoothstep(.86,.97,sin(wave*.53+1.5));
            pigment=mix(pigment,float3(.009,.024,.33),cobalt);
            float gold=pow(.5+.5*sin(wave*.77),28.0);
            pigment=mix(pigment,float3(.67,.43,.13),gold*.85);
            float white=pow(.5+.5*sin(wave+1.1),60.0);
            pigment=mix(pigment,float3(.61,.79,.72),white*.65);
            ink=.48;
        } else if(kind==2.0) {
            pigment=caneColor(in.uv.z);
            float swirl=.80+.20*sin(in.local.y*15+in.local.x*8+in.uv.z);
            pigment*=swirl;
            ink=thickness>.04 ? .12 : .40;
        } else if(kind==10.0) {
            pigment=sculptureColor(in.uv.z);
            float filament=pow(.5+.5*sin(in.local.y*43+sin(in.local.x*19)*2+in.local.z*22),24.0);
            pigment=mix(pigment,sqrt(pigment)*.95,filament*.27);
            ink=in.uv.z==11 ? 1.0 : (in.uv.z==5 ? .24 : .36);
            if(in.uv.z==10) ink=.26;
            if(in.uv.z==16) {
                float edge=smoothstep(.76,1.0,in.uv.y);
                float veins=pow(.5+.5*cos(in.uv.x*6.2831853*12),14.0);
                pigment=mix(float3(.035,.45,.34),float3(.50,.32,.66),edge*.83);
                pigment=mix(pigment,float3(.73,.88,.75),veins*.18);
                ink=.22;
            }
            if(in.uv.z==18) {
                pigment=mix(float3(.24,.085,.45),float3(.74,.59,.86),in.uv.y);
                ink=.30;
            }
            if(in.uv.z==14) {
                float ribs=pow(.5+.5*cos(in.uv.x*6.2831853*9),10.0);
                pigment=mix(float3(.81,.43,.39),float3(.98,.83,.59),ribs*.50+in.uv.y*.22);
                ink=.22;
            }
            if(in.uv.z==15) {
                pigment=float3(.94,.93,.83);
                ink=.62;
            }
            if(in.uv.z==12 || in.uv.z==13) {
                float radial=saturate(in.uv.y);
                float lip=smoothstep(.84,1.0,radial);
                float ribs=pow(.5+.5*sin(in.uv.x*6.2831853*18+radial*7),12.0);
                float3 core=in.uv.z==12 ? float3(.57,.025,.055) : float3(.008,.23,.17);
                float3 edge=in.uv.z==12 ? float3(.97,.31,.19) : float3(.13,.62,.43);
                pigment=mix(core,edge,smoothstep(.16,.96,radial));
                pigment=mix(pigment,float3(.94,.83,.64),lip*.32+ribs*radial*.065);
                ink=mix(.56,.27,radial);
            }
        } else if(kind==3.0 && u.catalog.x!=2.0) {
            pigment=fishPigment(in.local,u.catalog.x,false,ink);
        } else if(kind==3.0) {
            float x=in.local.x+in.local.y*.16+sin(in.local.y*9.0)*.008;
            float band=max(1-smoothstep(.029,.044,abs(x-.25)),1-smoothstep(.022,.038,abs(x-.006)));
            pigment=mix(float3(1.0,.105,.003),float3(.98,.045,.001),(1-smoothstep(-.15,.02,in.local.y))*.65);
            pigment=mix(pigment,float3(.96,.89,.72),band);
            ink=mix(.045,.63,band);
        } else if(kind==4.0) {
            float edge=pow(1-abs(dot(n,eye)),2.0);
            float streak=pow(.5+.5*sin(in.local.x*30+in.local.y*24),18.0);
            pigment=mix(float3(.98,.87,.62),float3(1.0,.46,.075),edge*.58);
            pigment=mix(pigment,float3(1.0,.92,.76),streak*.12);
            ink=.025+edge*.045;
            if(u.catalog.x!=2.0) {
                pigment=fishPigment(in.local,u.catalog.x,true,ink);
                pigment=mix(pigment,sqrt(pigment),edge*.35);
            }
            if(u.catalog.x==2.0 && in.uv.z==3) {
                pigment=float3(1.0,.34,.025);
                ink=.08;
            }
        } else if(kind==7.0) {
            pigment=in.uv.z<.5 ? float3(.72,.66,.40) : (in.uv.z<1.5 ? float3(.001,.003,.007) : float3(.85,.19,.010));
            ink=in.uv.z<1.5 ? 1.0 : .55;
        } else {
            pigment=float3(.45,.18,.022);
            ink=.82;
        }
        color=artGlass(in,n,eye,pigment,ink,thickness,u,sceneColor,visibility);
        if(kind==10.0 && in.uv.z==10) color+=float3(.47,.30,.095)*(.4+.6*pow(max(dot(n,eye),0.0),2.0));
        if(kind==3.0 || kind==4.0) color=mix(color*float3(.70,.75,.78),color,.5+.5*u.catalog.w);
        return float4(color,1);
    }
    """#
}
