varying mediump vec2 var_texcoord0;

uniform lowp sampler2D texture_sampler;
uniform lowp vec4 tint;

uniform lowp vec4 light_type;
uniform lowp vec4 attenuation;
uniform lowp vec4 pointing_to;
uniform lowp vec4 spot_data;

void main()
{
    // Pre-multiply alpha since all runtime textures already are
    lowp vec4 tint_pm = vec4(tint.xyz * tint.w, tint.w);
    lowp vec4 useless = light_type * attenuation * pointing_to * spot_data;
    gl_FragColor = texture2D(texture_sampler, var_texcoord0.xy) * tint_pm;
}
