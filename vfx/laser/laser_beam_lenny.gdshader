shader_type canvas_item;

uniform float speed = 8.0;       // How fast the spiral travels down the beam
uniform float frequency = 12.0;   // How tight the coils are
uniform float amplitude = 0.45;  // How far it reaches outside the beam center

void fragment() {
    // Calculate the 3D angle of the rotation using a sine wave along the beam (UV.x)
    float angle = (UV.x * frequency) - (TIME * speed);
    
    // Wave height determines the vertical position (Up/Down)
    float wave_height = sin(angle) * amplitude;
    
    // Depth calculates if the strand is "in front" or "behind" using a cosine wave
    // It maps from -1.0 (deep behind) to 1.0 (closest in front)
    float depth = cos(angle);
    
    // Center the baseline UV.y around 0.5, then add our vertical wave shift
    float distance_from_wave = abs((UV.y - 0.5) - wave_height);
    
    // Define the thickness of the strand. 
    // We dynamically make it THICKER when it's in front (depth > 0)
    float baseline_thickness = 0.08;
    float dynamic_thickness = baseline_thickness * (1.0 + (depth * 0.3));
    
    // Generate the crisp edge of the line strand
    float alpha_mask = smoothstep(dynamic_thickness, dynamic_thickness - 0.02, distance_from_wave);
    
    // Optional: Make it slightly darker/faded when it loops behind the main beam
    float shading = smoothstep(-1.2, 1.0, depth);
    
    // Use the built-in COLOR variable (which contains the Line2D's Default Color)
    vec3 final_color = COLOR.rgb * (0.6 + (shading * 0.4));
    
    // Apply the final color and the mask to the pixel output
    COLOR = vec4(final_color, alpha_mask);
}
