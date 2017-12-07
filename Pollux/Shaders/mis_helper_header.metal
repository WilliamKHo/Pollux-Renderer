//
//  mis_helper_header.metal
//  Pollux
//
//  Created by William Ho on 12/1/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#include <metal_stdlib>
#include "../Data_Types/PolluxTypes.h"
#include "../Data_Types/Constants.h"
#include "Loki/loki_header.metal"

// TODO: Add comments describing what this file does


using namespace metal;

/**
 * Weighs a BSDF based sample and a Light
 * based sample using their pdf's
 * - Used in MIS for determining sample contribution
 */
float powerHeuristic(const thread float& nf,
                     const thread float& fpdf,
                     const thread float& gf,
                     const thread float& gpdf);

float          pdf(const thread int& bsdf,
                   const thread float3& n,
                   const thread float3& wi,
                   const thread float3& wo);


float3 f(const thread Material& m,
         const thread float3& wi,
         const thread float3& wo);

bool isSpecular(const thread Material& m);
