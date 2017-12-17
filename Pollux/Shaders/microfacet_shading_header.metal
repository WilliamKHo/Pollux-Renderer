//
//  microfacet_shading_header.metal
//  Pollux-macOS
//
//  Created by Youssef Victor on 12/12/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#include <metal_stdlib>
#include "../Data_Types/PolluxTypes.h"
#include "../Data_Types/Constants.h"
#include "Loki/loki_header.metal"
using namespace metal;

// Computes the differential area of microfacets on a
// surface that are aligned with the given surface normal
// vector wh (the half-vector between wo and its specular
// reflection wi)
float D(constant MicrofacetDistribution& d,
        const thread float3& n,
        const thread float3 &wh) ;

//
float Lambda(constant MicrofacetDistribution& d,
             const thread float3 &w);

// Computes the geometric self-shadowing and interreflection term
float G(constant MicrofacetDistribution& d,
        const thread float3 &wo,
        const thread float3 &wi);

// Samples the distribution of microfacet normals to generate one
// about which to reflect wo to create a wi.
float3 Sample_wh(constant MicrofacetDistribution& d,
                 const thread float3 &wo,
                 const thread Loki &rng);

// Computes the PDF of the given half-vector normal based on the
// given incident ray direction
float Pdf(constant MicrofacetDistribution& d,
          const thread float3 &wo,
          const thread float3 &wh,
          const thread float3& n);
