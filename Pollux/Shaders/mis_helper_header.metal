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
#include "intersections_header.metal"
#include "shapes_header.metal"
#include "Loki/loki_header.metal"

/*********
 **
 ** This file contains helper methods for Multiple Importance Sampling (MIS)
 **
 **********/


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


/**
 * Calculates and returns the probability of selecting
 * a ray direction given the bsdf using the following parameters:
 *
 * - bsdf: The bsdf type of the material
 *
 * - normal: the surface normal at the point of intersection
 *
 * - wi: The direction of the incoming ray
 *
 * - wo: The direction of the outgoing ray
 *
 */
float          pdf(const thread int& bsdf,
                   const thread float3& n,
                   const thread float3& wi,
                   const thread float3& wo);

/**
 * Calculates and returns the probability of selecting
 * a ray direction given the bsdf using the following parameters:
 *
 * - bsdf: The bsdf type of the material
 *
 * - normal: the surface normal at the point of intersection
 *
 * - wi: The direction of the incoming ray
 *
 * - wo: The direction of the outgoing ray
 *
 */
float pdfLi(constant Geom& randlight,
            const thread float3& pisect,
            const thread float3& wi);


/**
 * Calculates and returns the color of the material given
 * wi, wo. An observer new to graphics might see the unused
 * parameters wi and wo in the function implementation and
 * see this as an oversight on our behalf. This is actually
 * intentional as some surfaces return different colors based
 * on the direction of the incoming and outgoing rays.
 * Including them allows are code to be extendable with many
 * other potential BSDF types in the future.
 *
 * - m: The material intersected
 *
 * - wi: The direction of the incoming ray
 *
 * - wo: The direction of the outgoing ray
 *
 */
float3 f(const thread Material& m,
         const thread float3& wi,
         const thread float3& wo);

/**
 *
 * Returns whether or not a given material, `m`, isSpecular.
 *
 * This is needed because MIS needs to avoid sampling for specular materials
 * as they are colored by their reflections' color.
 *
 */
bool isSpecular(const thread Material& m);
