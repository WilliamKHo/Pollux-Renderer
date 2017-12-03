//
//  mis_helper.metal
//  Pollux
//
//  Created by William Ho on 12/1/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#include "mis_helper_header.metal"

using namespace metal;

float3 sampleCube(device Geom& light,
                  device Material& m,
                  thread float3& ref,
                  thread Loki& rng,
                  thread float3& wi,
                  thread float& pdf_li){
    float4 shapeSample = float4(rng.rand() - 0.5, rng.rand() - 0.5, rng.rand() - 0.5, 1.f);
    shapeSample = light.transform * shapeSample;
    
    wi = normalize(shapeSample.xyz - ref);
    pdf_li = 0.2f; // TODO: Actually calculate pdf
    return m.color * m.emittance;
}

float3 sampleSphere(thread Geom& light,
                    thread Loki& rng) {
    return float3(0);
}

float powerHeuristic(thread float& nf,
                     thread float& fpdf,
                     thread float& ng,
                     thread float& gpdf) {
    float f = nf * fpdf, g = ng * gpdf;
    return (f * f) / (f*f + g*g);
}
