//
//  ray_compaction.metal
//  Pollux
//
//  Created by William Ho on 11/24/17.
//  Copyright © 2017 William Ho. All rights reserved.
//

#include <metal_stdlib>
#include "../../Data_Types/PolluxTypes.h"
using namespace metal;

#define THREADGROUP_SIZE 512 // must match RayCompaction.swift
#define NUM_BANKS 16

// Evaluate rays for termination
kernel void kern_evaluateRays(const device  Ray *rays               [[  buffer(0)  ]],
                              device        uint* valids_buffer     [[  buffer(1)  ]],
                              device        uint* invalids_buffer   [[  buffer(2)  ]],
                              constant      uint& numberOfRays      [[  buffer(3)  ]],
                              uint id [[thread_position_in_grid]]) {
    if (id >= numberOfRays) {
        valids_buffer[id] = 0;
        invalids_buffer[id] = 0;
        return;
    }
    // Quick and dirty
    if (rays[id].idx_bounces[2] > 0) {
        valids_buffer[id] = 1;
        invalids_buffer[id] = 0;
    } else {
        valids_buffer[id] = 0;
        invalids_buffer[id] = 1;
    }
    return;
}

// Helper function to calculate offsetted indices to avoid bank conflicts
device uint bankConflictOffset(uint x) {
    return x + (x / NUM_BANKS) * 3;
}

// Performs prefix-sum scan on an array of uints using shared memory
kernel void kern_prefixSumScan(device uint *inData      [[  buffer(0)  ]],
                               device uint *sums        [[  buffer(1)  ]],
                               uint threadGroupId [[threadgroup_position_in_grid]],
                               uint tid [[thread_position_in_threadgroup]],
                               uint threadGroupDim [[threads_per_threadgroup]]) {
    
    // allocate shared memory
    threadgroup uint temp[THREADGROUP_SIZE * 2 + 3 * (THREADGROUP_SIZE*2 / NUM_BANKS)];
    uint id = threadGroupId * threadGroupDim + tid;
    uint offset = 1;
    
    uint ai = 2*tid;
    uint bi = 2*tid+1;
    uint aiShared = bankConflictOffset(ai);
    uint biShared = bankConflictOffset(bi);
    
    temp[aiShared] = inData[2*id];
    temp[biShared] = inData[2*id + 1];
    
    // upsweep
    for(uint d = THREADGROUP_SIZE; d > 0; d /= 2) {
        threadgroup_barrier(mem_flags::mem_threadgroup);
        if (tid < d) {
            ai = offset*(2*tid + 1)-1;
            bi = offset*(2*tid + 2)-1;
            aiShared = bankConflictOffset(ai);
            biShared = bankConflictOffset(bi);
            temp[biShared] += temp[aiShared];
        }
        offset *= 2;
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    if (tid == 0) {
        temp[THREADGROUP_SIZE * 2 + 3 * (THREADGROUP_SIZE*2 / NUM_BANKS)-4] = 0;
    }
    
    // downsweep
    for (uint d = 1; d < THREADGROUP_SIZE + 1; d *= 2) {
        offset /= 2;
        threadgroup_barrier(mem_flags::mem_threadgroup);
        if (tid < d) {
            ai = offset*(2*tid + 1)-1;
            bi = offset*(2*tid + 2)-1;
            aiShared = bankConflictOffset(ai);
            biShared = bankConflictOffset(bi);
            uint t = temp[aiShared];
            temp[aiShared] = temp[biShared];
            temp[biShared] += t;
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    ai = 2*tid;
    bi = 2*tid+1;
    aiShared = bankConflictOffset(ai);
    biShared = bankConflictOffset(bi);
    
    if (tid == 0) {
        sums[threadGroupId] = temp[bankConflictOffset((THREADGROUP_SIZE-1) * 2 + 1)] + inData[THREADGROUP_SIZE * 2 * threadGroupId + THREADGROUP_SIZE * 2 - 1];
    }
    
    inData[2*id] = temp[aiShared];
    inData[2*id + 1] = temp[biShared];
}

// Adds the per-threadgroup sums to obtain final prefix sum reduction
kernel void kern_prefixPostSumAddition(device uint *data [[  buffer(0)  ]],
                                       device uint *sums [[  buffer(1)  ]],
                                       uint threadGroupId [[threadgroup_position_in_grid]],
                                       uint tid [[thread_position_in_threadgroup]],
                                       uint threadGroupDim [[threads_per_threadgroup]]) {
    uint sum = sums[threadGroupId + 1];
    data[THREADGROUP_SIZE * 2 * (threadGroupId + 1) + tid * 2] += sum;
    data[THREADGROUP_SIZE * 2 * (threadGroupId + 1) + tid * 2 + 1] += sum;
}

// Scatter rays into compacted buffer after prefix sum
kernel void kern_scatterRays(const device   Ray *rays1              [[  buffer(0)  ]],
                             device         Ray *rays2              [[  buffer(1)  ]],
                             const device   uint *valids_buffer     [[  buffer(2)  ]],
                             const device   uint *invalids_buffer   [[  buffer(3)  ]],
                             constant       uint& numberOfRays      [[  buffer(4)  ]],
                             uint id [[thread_position_in_grid]]) {
    uint invalidOffset = valids_buffer[numberOfRays];
    Ray ray = rays1[id];
    uint finalPosition = (ray.idx_bounces[2] > 0) ? valids_buffer[id] : invalids_buffer[id] + invalidOffset;
    rays2[finalPosition] = ray;
}

