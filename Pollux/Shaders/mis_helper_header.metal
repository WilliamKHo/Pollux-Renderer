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

float3 sampleCube(device Geom& light,
                  device Material& m,
                  thread float3& ref,
                  thread Loki& rng,
                  thread float3& wi,
                  thread float& pdf_li);

float3 sampleSphere(thread Geom& light,
                    thread Loki& rng);

float powerHeuristic(thread float& nf,
                     thread float& fpdf,
                     thread float& gf,
                     thread float& gpdf);

float calculatePDF(thread int& bsdf,
                   thread float3& n,
                   thread float3& wo);
