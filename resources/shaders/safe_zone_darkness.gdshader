shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec3 back_wall_origin;
uniform vec3 entrance_direction;
uniform float fade_length = 8.0;
varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    float distance_from_back = dot(world_position - back_wall_origin, entrance_direction);
    ALBEDO = vec3(0.0);
    ALPHA = 1.0 - smoothstep(0.0, fade_length, distance_from_back);
}
