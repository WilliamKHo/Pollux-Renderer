//
//  bsdf_interactions_header.metal
//  Pollux
//
//  Created by Youssef Kamal Victor on 11/22/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#include <metal_stdlib>
#include "../Data_Types/PolluxTypes.h"
#include "../Data_Types/Constants.h"
#include "Loki/loki_header.metal"

// TODO: Add comments describing what this file does


using namespace metal;


void SnS_diffuse(device Ray& ray,
                 thread Intersection& isect,
                 thread Material &m,
                 thread float& random,
                 thread float& pdf);

void SnS_specular(device Ray& ray,
                  thread Intersection& isect,
                  thread Material &m,
                  thread float& random,
                  thread float& pdf);

void SnS_fresnel(device Ray& ray,
                 thread Intersection& isect,
                 thread Material &m,
                 thread float& random,
                 thread float& pdf);

// Helper Method for SnS_diffuse
float3 cosRandomDirection(const float3 normal,
                          thread float&  random);
