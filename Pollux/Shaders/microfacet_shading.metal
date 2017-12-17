//
//  microfacet_shading.metal
//  Pollux-macOS
//
//  Created by Youssef Victor on 12/12/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#include "microfacet_shading_header.metal"


// Computes the differential area of microfacets on a
// surface that are aligned with the given surface normal
// vector wh (the half-vector between wo and its specular
// reflection wi)
//float D(const MicrofacetDistribution& d, const float3& n, const float3 &wh) const {
//    switch (d) {
//        case BECKMANN:
////            const float cos2Theta = dot(n, wh); cos2Theta *= cos2Theta;
////            const float sin2Theta = max(0.f, 1.f - cos2Theta);
////            const float tan2Theta = sin2Theta / cos2Theta;
////            
////            if (isinf(tan2Theta)) return 0.f;
////            
////            const float cos4Theta = cos2Theta * cos2Theta;
////            
////            const sinPhi = (sinTheta == 0) ? 1 : clamp(w.x / sinTheta, -1.f, 1.f);
////            
////            float e =
////            (Cos2Phi(wh) / (alphax * alphax) + Sin2Phi(wh) / (alphay * alphay)) *
////            tan2Theta;
////            return 1 / (Pi * alphax * alphay * cos4Theta * (1 + e) * (1 + e));
//            
//        case TOWBRIDGE_REITZ:
//            break
//    }
//}
//
////
//float Lambda(const MicrofacetDistribution& d, const float3 &w) const {
//    switch (d) {
//        case BECKMANN:
//            break;
//        case TOWBRIDGE_REITZ:
//            break
//    }
//}
//
//// Computes the geometric self-shadowing and interreflection term
//float G(const MicrofacetDistribution& d, const float3 &wo, const float3 &wi) const {
//    return 1 / (1 + Lambda(d, wo) + Lambda(d, wi));
//}
//
//// Samples the distribution of microfacet normals to generate one
//// about which to reflect wo to create a wi.
//float3 Sample_wh(const MicrofacetDistribution& d, const Vector3f &wo, const Point2f &xi) const {
//    switch (d) {
//        case BECKMANN:
//            break
//        case TOWBRIDGE_REITZ:
//            break
//    }
//}
//
//// Computes the PDF of the given half-vector normal based on the
//// given incident ray direction
//float Pdf(const MicrofacetDistribution& d, const float3 &wo, const float3 &wh, const float3& n) const {
//    float dotWo = dot(n, wo);
//    float absCosTheta = fabs(dotWo) * InvPi;
//    
//    if (false) {
//        // If (sampleVisibleArea)
//        // Provides better results but is harder,
//        // especially with this code structure
//    } else {
//        return D(d, n, wh) * absCosTheta;
//    }
//}

