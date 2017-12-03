//
//  light_behavior_header.metal
//  Pollux
//
//  Created by William Ho on 12/3/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#include <metal_stdlib>
#include "../Data_Types/PolluxTypes.h"
#include "../Data_Types/Constants.h"
#include "Loki/loki_header.metal"


using namespace metal;

void refract(const float3 incoming,
             const float3 surfaceNormal,
             const float ior,
             thread float3& output);

void reflect(const float3 incoming,
             const float3 surfaceNormal,
             thread float3& output);

