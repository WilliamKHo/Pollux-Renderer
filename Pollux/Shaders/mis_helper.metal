//
//  mis_helper.metal
//  Pollux
//
//  Created by William Ho on 12/1/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#include "mis_helper_header.metal"

using namespace metal;

float powerHeuristic(const thread float& nf,
                     const thread float& fpdf,
                     const thread float& ng,
                     const thread float& gpdf) {
    const float f = nf * fpdf, g = ng * gpdf;
    if (fpdf == 0 && gpdf == 0) return 0.f;
    return (f * f) / (f*f + g*g);
}

float  pdf(const thread int& bsdf,
           const thread float3& n,
           const thread float3& wi,
           const thread float3& wo) {
    if (bsdf == 0) {
        // PDF is the lambert term / Pi
        return fabs(dot(n, wo)) * InvPi;
    } else if (bsdf == 1 || bsdf == 2){
        // Speculars hava a pdf of zero
        return 0;
        
    } else {
        return 0;
    }
}

float pdfLi(constant Geom& randlight,
              const thread float3& pisect,
              const thread float3& wi) {
    
    float3 tmp_intersect; float3 tmp_normal;
    Ray tmp_wi; tmp_wi.origin = pisect; tmp_wi.direction = wi;
    
    
    bool outside;
    float t;
    // TODO: Shape Intersection
    switch (randlight.type) {
        case CUBE:
            t = computeCubeIntersection(&randlight, tmp_wi, tmp_intersect, tmp_normal, outside);
            break;
        case SPHERE:
            t = computeSphereIntersection(&randlight, tmp_wi, tmp_intersect, tmp_normal, outside);
            break;
        case PLANE:
            // TODO: Plane Intersection
            t = -1;
            break;
    }
    
    if(t < 0.f) {
        return 0.f;
    }
    
    
    const float denominator = abs(dot(tmp_normal, -wi)) * shapeSurfaceArea(randlight);

    if(denominator > 0.f) {
        return      distance_squared(pisect, tmp_intersect)
                           / denominator;
    } else {
        return 0.f;
    }
}

// Gets color contribution from that particular point using the BSDF
float3  f(const thread Material& m,
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

bool isSpecular(const thread Material& m) {
    return m.bsdf == 1 || m.bsdf == 2;
}
