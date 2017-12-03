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
    float indexRatios = ior;
    
    float cosi = dot(i, n);
    if (cosi < 0) {
        cosi = -cosi;
    } else {
        n = -n;
        indexRatios = ior / 1.f;
    }
    float k = 1.f - (ior * ior) * (1.f - cosi * cosi);
    output = (k < 0) ? 0 : ior * i + (ior * cosi - sqrt(k)) * n;
}

void reflect(const float3 incoming,
             const float3 surfaceNormal,
             thread float3& output) {
    float dotProduct = dot(incoming, normalize(surfaceNormal));
    output = incoming - 2 * dotProduct * surfaceNormal;
}



