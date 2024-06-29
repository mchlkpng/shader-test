varying mediump vec2 var_texcoord0;

uniform lowp sampler2D diffuse;
uniform lowp sampler2D normal;
uniform lowp sampler2D specular;
uniform lowp vec4 tint;
uniform lowp vec4 offset;
varying highp vec4 var_position;
varying highp mat4 var_viewproj;

#define MAX_LIGHTS 25

uniform highp vec4 ambient;
uniform lowp vec4 num_lights;
uniform mediump vec4 light_positions[MAX_LIGHTS];
uniform highp vec4 light_colors[MAX_LIGHTS];
uniform mediump vec4 light_attens[MAX_LIGHTS];
uniform mediump vec4 light_directions[MAX_LIGHTS];
uniform mediump vec4 light_spotdata[MAX_LIGHTS];
uniform mediump vec4 view_pos;
uniform mediump vec4 spec_strength;

float power(float n, int e) {
    float new = 1.0;
    if (e > 0) {
        for (int i = 0; i < e; i++) {
            new *= n;
        }
    } else if (e < 0) {
        for (int i = 0; i < e; i++) {
            new /= n;
        }
    }

    return new;
}

float maximum(float n1, float n2) {
    if (n1 > n2) {return n1;} else if (n2 > n1) {return n2;} else {return n1;}
}


void main() 
{
    lowp vec4 tint_pm = vec4(tint.xyz * tint.w, tint.w);
    vec4 albedo_color = texture2D(diffuse, var_texcoord0.xy);
    vec4 normal_color = texture2D(normal, var_texcoord0.xy) * 2.0 -1.0;
    vec4 spec_color = texture2D(specular, var_texcoord0.xy);
    lowp vec4 color_diffuse = vec4(0.0);

    vec4 final_color = ambient * albedo_color;


    mediump int lights = int(num_lights.x);
    int light_index = 0;

    for (light_index = 0; light_index < lights; light_index++) {
        
        if (int(light_positions[light_index].w) == 0) { //DIRECTIONAL LIGHT
            //lowp vec3 light_dir = normalize(light_positions[light_index].xyz - var_position.xyz);
            lowp vec3 light_dir = normalize(light_directions[light_index].xyz);
            
            // Pre-multiply alpha since all runtime textures already are


            // Get View Direction
            lowp vec3 view_dir = normalize(view_pos.xyz - var_position.xyz);

            // Calculate Reflection Direction
            vec3 reflect_dir = normalize(reflect(-light_dir, normal_color.xyz));

            // Calculate Specular

            //premultiply color cuz i need to lmao
            highp vec4 l_col = vec4(light_colors[light_index].xyz * light_colors[light_index].w, light_colors[light_index].w);
            float specular = power(maximum(dot(view_dir, reflect_dir), 0.0), 32);
            spec_color = (specular * l_col * spec_color *spec_strength.x);

            float diff = maximum(0.0, dot(normal_color.xyz, light_dir.xyz));
            color_diffuse = diff * l_col;

            final_color += vec4((color_diffuse + spec_color).xyz * albedo_color.xyz, albedo_color.w);
        }
        else if (int(light_positions[light_index].w) == 1) {//POINT LIGHT
            lowp vec3 light_dir = light_positions[light_index].xyz - var_position.xyz;
            float distance = length(light_dir);
            light_dir = normalize(light_dir);
            float attenuation = 1.0 / (light_attens[light_index].x + (light_attens[light_index].y * distance) + 
                (light_attens[light_index].z * distance * distance));

               // lowp vec3 light_dir = normalize(light_positions[light_index].xyz - var_position.xyz);

            // Pre-multiply alpha since all runtime textures already are


            // Get View Direction
            lowp vec3 view_dir = normalize(view_pos.xyz - var_position.xyz);

            // Calculate Reflection Direction
            vec3 reflect_dir = normalize(reflect(-light_dir, normal_color.xyz));

            highp vec4 l_col = vec4(light_colors[light_index].xyz * light_colors[light_index].w, light_colors[light_index].w);
            // Calculate Specular
            float specular = power(maximum(dot(view_dir, reflect_dir), 0.0), 32);
            spec_color = (specular * l_col * spec_color *spec_strength.x*attenuation);

            float diff = maximum(0.0, dot(normal_color.xyz, light_dir.xyz));
            color_diffuse = diff * l_col * attenuation;

            final_color += vec4((color_diffuse + spec_color).xyz * albedo_color.xyz, albedo_color.w);
        }
        else if (int(light_positions[light_index].w) == 2) { //SPOTLIGHT
            lowp vec3 light_dir = light_positions[light_index].xyz - var_position.xyz;
            float distance = length(light_dir);
            light_dir = normalize(light_dir);
            float attenuation = 1.0 / (light_attens[light_index].x + (light_attens[light_index].y * distance) + 
            (light_attens[light_index].z * distance * distance));
            float phi = sin(light_spotdata[light_index].x);
            float gamma = sin(light_spotdata[light_index].y);
            float theta = dot(light_dir, normalize(light_directions[light_index].xyz));
            float epsilon = gamma - phi;
            float intensity = 0.0;
            if (epsilon != 0.0) {
                intensity = clamp((theta - gamma)/epsilon, 0.0, 1.0);
            }// Get View Direction
            lowp vec3 view_dir = normalize(view_pos.xyz - var_position.xyz);

            // Calculate Reflection Direction
            vec3 reflect_dir = normalize(reflect(-light_dir, normal_color.xyz));

            //premultiply color cuz i need to lmao
            highp vec4 l_col = vec4(light_colors[light_index].xyz * light_colors[light_index].w, light_colors[light_index].w);
            // Calculate Specular
            float specular = power(maximum(dot(view_dir, reflect_dir), 0.0), 32);
            spec_color = (specular * l_col * spec_color *spec_strength.x) * intensity * attenuation;

            float diff = maximum(0.0, dot(normal_color.xyz, light_dir.xyz));
            color_diffuse = diff * l_col * intensity*attenuation;

            final_color += vec4((color_diffuse + spec_color).xyz * albedo_color.xyz, albedo_color.w);
        }
    }
    
    gl_FragColor = final_color * tint_pm;
}
