//
//  shapes.metal
//  Pollux-macOS
//
//  Created by Youssef Victor on 12/8/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//


#include "shapes_header.metal"


float3 sampleCube(constant Geom&       light,
                  const thread float3&   ref,
                  thread Loki&           rng,
                  thread float3&          wi,
                  thread float&          pdf){
    
    //Get a sample point
    float3 sample_li = float3(rng.rand() - 0.5f, 0, rng.rand() - 0.5f);
    sample_li = float3(light.transform * float4(sample_li, 1));
    
    const float3 normal_li = float3(0, 0, -1);
    
    wi = normalize(sample_li - ref);
    
    //Get shape area and convert it to Solid angle
    const float cosT = fabs(dot(-wi, normal_li));
    const float solid_angle = (length_squared(sample_li - ref) / cosT);
    const float cubeArea = shapeSurfaceArea(light);
    
    pdf = solid_angle / cubeArea;
    
    //Check if dividing by 0.f
    pdf = isnan(pdf) ? 0.f : pdf;
    
    return sample_li;
}

float3 sampleSphereInside(constant Geom& sphere,
                          const thread float3&   ref,
                          thread float3&     wi,
                          thread Loki&      rng,
                          thread float&     pdf)
{
    
    // Get a random point on the entire sphere
    const float z = 1.f - 2.f * rng.rand();
    const float r = sqrt(max(0.f, 1.f - z * z));
    const float phi = 2.f * PI * rng.rand();
    
    float3 sphere_point = float3(r * cos(phi), r * sin(phi), z);
    sphere_point = float3(sphere.transform * float4(sphere_point, 1.f));
    
    wi = -normalize(sphere_point-ref);
    
    const float sphereArea = shapeSurfaceArea(sphere);
    
    pdf = 1.f / sphereArea;
    
    return sphere_point;
}


float3 sampleSphere(constant Geom&      sphere,
                    const thread float3&   ref,
                    thread Loki&           rng,
                    thread float3&          wi,
                    thread float&       pdf_li) {
    const float radius = 0.5f;
    float3 center = sphere.translation;
    float3 norm = normalize(center - ref);
    float3 tan_vector, bit;
    
    if (abs(norm.x) > abs(norm.y)) {
        tan_vector = float3(-norm.z, 0, norm.x) / sqrt(norm.x * norm.x + norm.z * norm.z);
    } else {
        tan_vector = float3(0, norm.z, -norm.y) / sqrt(norm.y * norm.y + norm.z * norm.z);
    }
    bit = cross(norm, tan_vector);
    
    const float distance_sqrd = distance_squared(ref, center);
    
    //r=1 in obj space, inside sphere test
    if (distance_sqrd < (0.5f*0.5f) + EPSILON) {// r^2 also 1
        return sampleSphereInside(sphere, ref, wi, rng, pdf_li);
    }
    
    const float xi_x = rng.rand();
    const float xi_y = rng.rand();
    
    const float sinThetaMax2 = 1.f / distance_sqrd; // r is 1
    const float cosThetaMax = sqrt(fmax(0.f, 1.f - sinThetaMax2));
    const float cosTheta = (1.f - xi_x) + xi_x * cosThetaMax;
    const float sinTheta = sqrt(max(0.f, 1.f - cosTheta * cosTheta));
    const float phi = xi_y * 2.f * PI;
    
    const float dc = sqrt(distance_sqrd);
    const float ds = dc * cosTheta - sqrt(fmax(0.f, 1.f - dc * dc * sinTheta * sinTheta));
    
    const float cosAlpha = (dc * dc + 1.f - ds * ds) / (2.f * dc * 1.f);
    const float sinAlpha = sqrt(fmax(0.f, 1.f - cosAlpha * cosAlpha));
    
    const float3 point_normal = normalize(sinAlpha * cos(phi) * -tan_vector + sinAlpha * sin(phi) * -bit + (cosAlpha * -norm));
    const float3 point_sample = point_normal * radius; // Scale Up/Down by radius size
    
    const float3 sample = float3(sphere.transform * float4(point_sample, 1.f));
    
    wi = normalize(sample - ref);
    
    pdf_li = radius * radius / (2.f * PI * (1.f - cosThetaMax));
    
    return sample;
}


float3  samplePlane(constant Geom&       light,
                    const thread float3&   ref,
                    thread Loki&           rng,
                    thread float3&          wi,
                    thread float&       pdf_li) {
    //Get a sample point
    const float3 sample_li_local = float3(rng.rand() - 0.5f, rng.rand() - 0.5f, 0);
    const float3 sample_li = float3(light.transform * float4(sample_li_local, 1));
    
    wi = normalize(sample_li - ref);
    
    const float3 normal_li = float3(light.invTranspose * float4(0, 0, 1, 0));
    pdf_li = 1 / shapeSurfaceArea(light);
    
    //Get shape area and convert it to Solid angle
    const float cosT = abs(dot(-wi, normal_li));
    const float solid_angle = (length_squared(sample_li - ref) / cosT);
    
    pdf_li *= solid_angle;
    
    return sample_li;
}

float  shapeSurfaceArea(constant Geom&  shape) {
    switch (shape.type) {
        case CUBE:
            return 2 * shape.scale.x * shape.scale.y *
                   2 * shape.scale.z * shape.scale.y *
                   2 * shape.scale.x * shape.scale.z;
        case SPHERE:
            return 4.f * PI * shape.scale.x * shape.scale.x; // We're assuming uniform scale
        case PLANE:
            return shape.scale.x * shape.scale.y;
    }
}
