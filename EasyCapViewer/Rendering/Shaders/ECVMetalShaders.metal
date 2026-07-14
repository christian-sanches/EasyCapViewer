#include <metal_stdlib>
using namespace metal;

// Vertex input/output structures
struct VertexIn {
    float4 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Uniforms structure
struct Uniforms {
    float4x4 projectionMatrix;
    float4x4 modelViewMatrix;
};

// Vertex shader
vertex VertexOut vertexShader(VertexIn in [[stage_in]],
                              constant Uniforms &uniforms [[buffer(1)]])
{
    VertexOut out;
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * in.position;
    out.texCoord = in.texCoord;
    return out;
}

// Fragment shader - YUV to RGB conversion
fragment float4 yuvToRGB(VertexOut in [[stage_in]],
                          texture2d<float> yTexture [[texture(0)]],
                          texture2d<float> cbcrTexture [[texture(1)]])
{
    constexpr sampler s(mag_filter::linear, min_filter::linear);
    
    // Sample Y and CbCr textures
    float y = yTexture.sample(s, in.texCoord).r;
    float2 cbcr = cbcrTexture.sample(s, in.texCoord).rg;
    
    // BT.601 conversion matrix
    // Y is in range [16/255, 235/255]
    // CbCr is in range [16/255, 240/255] centered at 128/255
    float4x4 yuvToRGBMatrix = float4x4(
        float4(1.0,     1.0,     1.0,     0.0),
        float4(0.0,    -0.344,   1.772,   0.0),
        float4(1.402,  -0.714,   0.0,     0.0),
        float4(0.0,     0.0,     0.0,     1.0)
    );
    
    // Adjust Y and CbCr to proper ranges
    float4 yuv;
    yuv.r = (y - 16.0/255.0) * (255.0/219.0);
    yuv.g = cbcr.r - 128.0/255.0;
    yuv.b = cbcr.g - 128.0/255.0;
    yuv.a = 1.0;
    
    // Convert to RGB
    float4 rgb = yuvToRGBMatrix * yuv;
    rgb.a = 1.0;
    
    return rgb;
}
