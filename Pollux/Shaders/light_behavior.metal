//
//  light_behavior.metal
//  Pollux
//
//  Created by William Ho on 12/3/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#include "light_behavior_header.metal"

using namespace metal;

void refract(const float3 incoming,
             const float3 surfaceNormal,
             const float ior,
             thread float3& output) {
    float3 i = normalize(incoming);
    float3 n = normalize(surfaceNormal);
    
    float3 iNorm = dot(i, n) * n;
    float cosi = length(iNorm);
    output = ior * i + (ior * cosi - sqrt(1.f - (ior * ior) * (1.f - cosi * cosi)));
}

void reflect(const float3 incoming,
             const float3 surfaceNormal,
             thread float3& output) {
    float dotProduct = dot(incoming, normalize(surfaceNormal));
    output = incoming - 2 * dotProduct * surfaceNormal;
}



