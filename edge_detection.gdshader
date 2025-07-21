shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform sampler2D NORMAL_TEXTURE : hint_normal_roughness_texture, filter_nearest;

uniform float lightIntensity : hint_range(0.3, 1.2) = 1.0;
uniform float lineAlpha : hint_range(0.7, 1.0) = 0.7;
uniform bool useLighting = true;
uniform float lineHighlight : hint_range(0.05, 0.3) = 0.15;
uniform float lineShadow : hint_range(0.2, 0.6) = 0.55;
uniform float edgeThresholdNear : hint_range(0.05, 0.2) = 0.15;
uniform float edgeThresholdFar : hint_range(0.2, 0.6) = 0.4;
uniform float farDistance : hint_range(50.0, 200.0) = 100.0;
uniform float lineSmoothness : hint_range(1.0, 2.0) = 2.0;
uniform float edgeLengthThreshold : hint_range(1.0, 3.0) = 2.0;

uniform float strongEdgeFactor : hint_range(0.3, 1.0) = 0.5;
uniform float weakEdgeBoost : hint_range(1.0, 3.0) = 1.8;
uniform float edgeThreshold : hint_range(0.3, 0.7) = 0.5;
uniform float edgeContrast : hint_range(0.5, 2.0) = 1.5;
uniform bool useAdaptiveEdge = true;

uniform float specularLimit : hint_range(0.4, 0.7) = 0.6;
uniform float baseColorWeight : hint_range(0.9, 1.0) = 1.0;
uniform float depthGradientCompensate : hint_range(0.5, 2.0) = 1.2;

varying vec2 screenUV;
varying float lineMask;
varying float linearDepth;

float GetLinearDepth(vec2 sUV, sampler2D depthTexture, mat4 invProjectionMat, float mask){
    float depth = texture(depthTexture, sUV).x * mask;
    vec3 ndc = vec3(sUV * 2.0 - 1.0, depth);
    vec4 view = invProjectionMat * vec4(ndc, 1.0);
    view.xyz /= view.w;
    return -view.z;
}

vec3 GetNormal(vec2 uv, sampler2D normalTexture, float mask, float roughness){
    vec3 normal = texture(normalTexture, uv).rgb;
    normal = normal * 2.0 - 1.0 * mask;
    return normal * (1.0 - roughness * 0.5);
}

float NormalEdgeIndicator(vec3 normalEdgeBias, vec3 normal, vec3 neighborNormal, float depthDifference, float roughness){
    float normalDifference = dot(normal - neighborNormal, normalEdgeBias);
    float threshold = mix(0.02, 0.05, roughness);
    float normalIndicator = clamp(smoothstep(-threshold, threshold, normalDifference), 0.0, 1.0);
    float depthIndicator = clamp(sign(depthDifference * 0.25 + 0.0025), 0.0, 1.0);
    float normalEdgeStrength = 1.0 - dot(normal, neighborNormal);
    return normalEdgeStrength * depthIndicator * normalIndicator;
}


float NonMaximumSuppression(vec2 uv, vec2 texelSize, float edgeValue, vec2 gradientDir, sampler2D edgeTexture) {
    if (edgeValue < 0.25) return 0.0;
    float angle = atan(gradientDir.y, gradientDir.x) * 180.0 / 3.1415926;
    angle = mod(angle + 180.0, 180.0);
    
    vec2 pos1, pos2;
    if ((angle >= 0.0 && angle < 15.0) || (angle >= 165.0 && angle < 180.0)) {
        pos1 = uv + vec2(texelSize.x, 0);
        pos2 = uv - vec2(texelSize.x, 0);
    } else if (angle >= 15.0 && angle < 75.0) {
        pos1 = uv + vec2(texelSize.x, texelSize.y) * 0.8;
        pos2 = uv - vec2(texelSize.x, texelSize.y) * 0.8;
    } else if (angle >= 75.0 && angle < 105.0) {
        pos1 = uv + vec2(0, texelSize.y);
        pos2 = uv - vec2(0, texelSize.y);
    } else {
        pos1 = uv + vec2(-texelSize.x, texelSize.y) * 0.8;
        pos2 = uv - vec2(-texelSize.x, texelSize.y) * 0.8;
    }
    
    float edge1 = texture(edgeTexture, pos1).x;
    float edge2 = texture(edgeTexture, pos2).x;
    return (edgeValue > max(edge1, edge2) * 1.2) ? edgeValue : 0.0;
}


float EdgeLengthFilter(vec2 uv, vec2 texelSize, float edgeValue, sampler2D edgeTexture) {
    if (edgeValue < 0.4) return 0.0;
    float length = 0.0;
    float threshold = 0.35;
    vec2 directions[4] = vec2[4](vec2(1.0,0.0), vec2(0.0,1.0), vec2(1.0,1.0), vec2(1.0,-1.0));
    for (int dir = 0; dir < 4; dir++) {
        vec2 dirStep = directions[dir] * texelSize;
        for (int i = 1; i <= min(int(edgeLengthThreshold), 3); i++) {
            vec2 offsetUV = uv + dirStep * float(i);
            float neighborEdge = texture(edgeTexture, offsetUV).x;
            if (neighborEdge > threshold) length += 1.0;
            else break;
        }
        for (int i = 1; i <= min(int(edgeLengthThreshold), 3); i++) {
            vec2 offsetUV = uv - dirStep * float(i);
            float neighborEdge = texture(edgeTexture, offsetUV).x;
            if (neighborEdge > threshold) length += 1.0;
            else break;
        }
    }
    return clamp(length / (edgeLengthThreshold * 0.8), 0.0, 1.0);
}


float AdaptiveEdgeStrength(float edgeValue, float threshold, float strongFactor, float weakBoost) {
    return edgeValue > threshold ? 
        threshold + (edgeValue - threshold) * strongFactor : 
        edgeValue * weakBoost;
}


vec2 CalculateEdgeGradient(vec2 uv, vec2 texelSize, sampler2D depthTexture, sampler2D normalTexture, mat4 invProjectionMat, float roughness) {
    float mask = ceil(roughness);
    float depthR = GetLinearDepth(uv + vec2(texelSize.x, 0), depthTexture, invProjectionMat, mask);
    float depthL = GetLinearDepth(uv - vec2(texelSize.x, 0), depthTexture, invProjectionMat, mask);
    float gradX = abs(depthR - depthL);
    
    float depthU = GetLinearDepth(uv + vec2(0, texelSize.y), depthTexture, invProjectionMat, mask);
    float depthD = GetLinearDepth(uv - vec2(0, texelSize.y), depthTexture, invProjectionMat, mask);
    float gradY = abs(depthU - depthD);
    
    gradY = gradY / depthGradientCompensate;
    return normalize(vec2(gradX, gradY));
}

void vertex(){
  POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
    vec2 texelSize = 1.0 / VIEWPORT_SIZE.xy;
    screenUV = SCREEN_UV;
    
    vec2 UVOffsets[8];
    UVOffsets[0] = SCREEN_UV + vec2(0.0, -1.0) * texelSize;
    UVOffsets[1] = SCREEN_UV + vec2(0.0, 1.0) * texelSize;
    UVOffsets[2] = SCREEN_UV + vec2(1.0, 0.0) * texelSize;
    UVOffsets[3] = SCREEN_UV + vec2(-1.0, 0.0) * texelSize;
    UVOffsets[4] = SCREEN_UV + vec2(1.0, 1.0) * texelSize * 0.9;
    UVOffsets[5] = SCREEN_UV + vec2(-1.0, 1.0) * texelSize * 0.9;
    UVOffsets[6] = SCREEN_UV + vec2(1.0, -1.0) * texelSize * 0.9;
    UVOffsets[7] = SCREEN_UV + vec2(-1.0, -1.0) * texelSize * 0.9;
    
    float roughness = texture(NORMAL_TEXTURE, SCREEN_UV).a;
    float outlineMask = ceil(roughness);
    linearDepth = GetLinearDepth(SCREEN_UV, DEPTH_TEXTURE, INV_PROJECTION_MATRIX, outlineMask);
    float distanceFactor = clamp(linearDepth / farDistance, 0.0, 1.0);
    float depthThreshold = mix(edgeThresholdNear, edgeThresholdFar, distanceFactor);
    
    float depthDifference = 0.0;
    float depth = GetLinearDepth(SCREEN_UV, DEPTH_TEXTURE, INV_PROJECTION_MATRIX, outlineMask);
    for (int i = 0; i < UVOffsets.length(); i++){
        float dOff = GetLinearDepth(UVOffsets[i], DEPTH_TEXTURE, INV_PROJECTION_MATRIX, outlineMask);
        float diff = clamp(dOff - depth, 0.0, 1.0);
        diff = diff * (1.0 - min(diff * 0.5, 0.3));
        depthDifference += diff;
    }
    depthDifference = smoothstep(depthThreshold, depthThreshold + 0.02, depthDifference);
    depthDifference = pow(depthDifference, 1.2);
    
    float normalDifference = 0.0;
    vec3 normalEdgeBias = vec3(1.0, 1.0, 1.0);
    vec3 normal = GetNormal(SCREEN_UV, NORMAL_TEXTURE, outlineMask, roughness);
    for (int i = 0; i < UVOffsets.length(); i++){
        vec3 nOff = GetNormal(UVOffsets[i], NORMAL_TEXTURE, outlineMask, roughness);
        normalDifference += NormalEdgeIndicator(normalEdgeBias, normal, nOff, depthDifference, roughness);
    }
    normalDifference /= float(UVOffsets.length());
    normalDifference = smoothstep(0.18, 0.22, normalDifference);
    
    float rawEdge = clamp(depthDifference + normalDifference, 0.0, 1.0);
    vec2 gradientDir = CalculateEdgeGradient(SCREEN_UV, texelSize, DEPTH_TEXTURE, NORMAL_TEXTURE, INV_PROJECTION_MATRIX, roughness);
    float suppressedEdge = NonMaximumSuppression(SCREEN_UV, texelSize, rawEdge, gradientDir, SCREEN_TEXTURE);
    float edgeLength = EdgeLengthFilter(SCREEN_UV, texelSize, suppressedEdge, SCREEN_TEXTURE);
    float filteredEdge = suppressedEdge * edgeLength;
    
    float adaptiveEdge = useAdaptiveEdge ? 
        AdaptiveEdgeStrength(filteredEdge, edgeThreshold, strongEdgeFactor, weakEdgeBoost) : 
        filteredEdge;
    adaptiveEdge = pow(adaptiveEdge, edgeContrast);
    
    lineMask = clamp(adaptiveEdge * lineAlpha, 0.0, 1.0);
    
    vec3 originalColor = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
    ALBEDO = originalColor * baseColorWeight;
    
    if (!useLighting){
        float highlightFactor = clamp((normalDifference - depthDifference), 0.0, 1.0) * lineHighlight;
        vec3 highlight = originalColor * highlightFactor;
        
        vec3 shadow = ALBEDO * depthDifference * lineShadow;
        
        ALBEDO = clamp(ALBEDO + highlight - shadow, 0.0, 1.0);
    }
}

void light (){
    if (useLighting){
        vec4 normal = texture(NORMAL_TEXTURE, screenUV);
        normal = normal * 2.0 - 1.0;
        
        float dotNL = dot(normal.rgb, LIGHT);
        dotNL = pow(max(dotNL, 0.0), 2.0);
        dotNL = clamp(dotNL, 0.0, specularLimit);
        
        float edgeLightFactor = mix(0.8, 1.0, lineMask);
        float roughness = texture(NORMAL_TEXTURE, screenUV).a;
        
        if(LIGHT_IS_DIRECTIONAL)
            DIFFUSE_LIGHT += dotNL * LIGHT_COLOR * lightIntensity * edgeLightFactor * (1.0 - roughness * 0.5);
    }
    else
        DIFFUSE_LIGHT = vec3(1.0);
}