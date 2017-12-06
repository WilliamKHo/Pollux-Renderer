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
    
    float cosT = fabs(dot(-wi, float3(0, -1, 0))); //TODO: Why is this value what it is?
    float sampleDistance = length(shapeSample.xyz - ref);
    float solid_angle = ((sampleDistance * sampleDistance) / cosT);
    
    pdf_li = solid_angle / (2 * (light.scale.x * light.scale.y
                               + light.scale.x * light.scale.z
                               + light.scale.y * light.scale.z));
    
    //Check if dividing by 0.f
    pdf_li = isnan(pdf_li) ? 0.f : pdf_li;
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
    float f = nf * fpdf;
    float g = ng * gpdf;
    return (f * f) / (f*f + g*g);
}

float calculatePDF(thread int& bsdf,
                   thread float3& n,
                   thread float3& wo) {
    if (bsdf == 0) {
        float dotWo = dot(n, wo);
        float cosTheta = fabs(dotWo) * InvPi;
        float pdf = cosTheta;
        return pdf;
    } else {
        return 0;
    }
}

float3 sampleBSDF(const thread Material& m,
                  const thread float3& wi,
                  const thread float3& wo) {
    switch (m.bsdf) {
        case 0:
            return m.color * InvPi;
        case 1:
            break;
        case 2:
            break;
        default:
            break;
    }
    return float3(0);
}
