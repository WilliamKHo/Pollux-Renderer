////
////  ray_compaction.metal
////  Pollux
////
////  Created by William Ho on 11/24/17.
////  Copyright © 2017 William Ho. All rights reserved.
////
//
//#include <metal_stdlib>
//#include "../Data_Types/PolluxTypes.h"
//using namespace metal;
//
//#define TG_SIZE 64// must match RayCompaction.swift
////#define NUM_BANKS 16
//
//// Helper function to calculate offsetted indices to avoid bank conflicts
////device uint bankConflictOffset(uint x) {
//////    return x + (x / NUM_BANKS) * 3;
////    return x;
////}
//
//// Performs prefix-sum scan on an array of uints using shared memory
////
//kernel void kern_PrefixSum    (/* The size of the buffer */
//                               device const uint *count      [[  buffer(0)  ]],
//                               device uint *input            [[  buffer(1)  ]],
//                               device uint *output           [[  buffer(3)  ]],
//                               // Leave Buffers 2 & 3, no need to continuously reset it
//                               /* The Buffer containing the sum of each block's summation */
//                               device uint *block_sums       [[  buffer(4)  ]],
//
//                               // A bool that determines whether we need to write to y
//                               constant uint*  write_y        [[  buffer(5)  ]],
//                               device uint  *  sums_y         [[  buffer(6)  ]],
//
//                               const  uint2 tid2D            [[thread_position_in_threadgroup]],
//                               const  uint2 tid_absolute2D   [[thread_position_in_grid]],
//                               const  uint2 threadGroupId2D  [[threadgroup_position_in_grid]],
//
//                               const  uint2 threadGroupDim   [[threads_per_threadgroup]],
//                               const  uint2 gridDim          [[threadgroups_per_grid]]) {
//
//    // Allocated Threadgroup buffer containing sum of all values of this threadgroup
//    threadgroup uint temp[TG_SIZE];
//    uint offset = 1;
//
//    // Flatten out indices to access 1D Array
//    const uint tid           = tid2D.x           + tid2D.y           * threadGroupDim.x;
//    const uint tid_absolute  = tid_absolute2D.x  + tid_absolute2D.y  * threadGroupDim.x * gridDim.x;
//    const uint threadGroupId = threadGroupId2D.x + threadGroupId2D.y * gridDim.x;
//
//    // Flattens out the 2D Indices to access the 1D array
//    const uint row_width = threadGroupDim.x * gridDim.x;
//    const bool needsBlockSum = row_width > TG_SIZE;
//
//    //Load in one value at the start of the kernel
//    temp[tid] = input[tid_absolute];
//    uint ai;
//
//    // upsweep
//    for(uint d = TG_SIZE >> 1; d > 0; d /= 2) {
//        threadgroup_barrier(mem_flags::mem_threadgroup);
//        if (tid < d) {
//                 ai = offset*(2 * tid + 1)-1;
//            uint bi = offset*(2 * tid + 2)-1;
////            ai = bankConflictOffset(ai);
////            bi = bankConflictOffset(bi);
//            temp[bi] += temp[ai];
//        }
//        offset *= 2;
//    }
//
//    threadgroup_barrier(mem_flags::mem_threadgroup);
//
//    if (tid == 0) {
//        if (needsBlockSum) {
//            block_sums[threadGroupId] = temp[TG_SIZE-1];
//        }
//
//        temp[TG_SIZE-1] = 0;
//    }
//
//    // downsweep
//    for (uint d = 1; d < TG_SIZE; d *= 2) {
//        offset /= 2;
//        threadgroup_barrier(mem_flags::mem_threadgroup);
//        if (tid < d) {
//                 ai = offset*(2 * tid + 1)-1;
//            uint bi = offset*(2 * tid + 2)-1;
//            // "Swap"
//            uint t = temp[ai];
//            temp[ai] = temp[bi];
//            temp[bi] += t;
//        }
//    }
//    threadgroup_barrier(mem_flags::mem_threadgroup);
//
//    // Write result out if we are still within the input
//    output[tid_absolute]  = temp[tid];
//
//    // Write the column sums to the sums_y buffer
//    // Slight divergence happens here, but overall should make up
//    // because we save a lot of time in global memory writes in
//    // the scatter phase
//    const bool is_last_thread = ((tid2D.x           + 1)  == threadGroupDim.x);
//    const bool is_last_block  = ((tid_absolute2D.x  + 1)  == row_width);
//
//
//    if (write_y && is_last_thread && is_last_block) {
//        if (*write_y == 1) {
//            sums_y[tid_absolute2D.y] = temp[tid];
//        } else if (*write_y == 2) {
//            sums_y[tid_absolute2D.y] += temp[tid];
//        }
//    }
//}
//
//
//kernel void kern_AdjustAndScatter(device const uint *count               [[  buffer(0)  ]],
//                                  device const uint *validation_buffer   [[  buffer(1)  ]],
//                                  device const Ray* rays                 [[  buffer(2)  ]],
//                                  device       uint *scan_result_buffer  [[  buffer(3)  ]],
//                                  device const uint *block_sums          [[  buffer(4)  ]],
//                                  device       Ray* device_rays          [[  buffer(5)  ]],
//                                  device const uint *sums_y              [[  buffer(6)  ]],
//                                  device const uint *block_sums_y        [[  buffer(7)  ]],
////                                  device       uint *count_buffer        [[  buffer(8)  ]],
//                                         const uint2 position            [[thread_position_in_grid]],
//                                         const uint2 threadGroupId       [[threadgroup_position_in_grid]],
//                                         const uint2 threadGroupDim      [[threads_per_threadgroup]],
//                                         const uint2 gridDim             [[threadgroups_per_grid]]) {
//    // The Flattened 1D Index
//    const uint absolute_idx = position.x  + position.y  * threadGroupDim.x * gridDim.x;
//
//    if (absolute_idx >= *count) { return; };
//
//    // Get scan_result_idx for the offset within the threadgroup
//    const uint scan_result_idx   = scan_result_buffer[absolute_idx];
//
//    // Get the block_sums_idx of this block for the offset within the row
//    const uint block_sums_idx    = block_sums[threadGroupId.x + threadGroupId.y * gridDim.x];
//
//    // Get the sums_y of this column, for the offset within the column threadgroup
//    const uint sums_y_idx        = sums_y[threadGroupId.y];
//
//    // Get the block_sums_y of this column for the offset within the columns (across the entire grid)
//    const uint block_sums_y_idx  = block_sums_y[threadGroupId.y / TG_SIZE];
//
//    // Bug Fix Offset, I need to think about why this is needed
//    const uint bfo = position.y;
//
//    // The final idx in the new buffer
//    const uint compacted_idx = scan_result_idx + block_sums_idx + sums_y_idx + block_sums_y_idx + bfo;
//
//    if (validation_buffer[absolute_idx]) {
//        device_rays[compacted_idx] = rays[absolute_idx];
//    } else {
//        device_rays[compacted_idx] = rays[absolute_idx];
//    }
//
//    // Set the new count to the last element in scan_result
//    if (absolute_idx == (gridDim.x * threadGroupDim.x * gridDim.y - 1)) {
//        scan_result_buffer[absolute_idx] = compacted_idx;
//    }
//}
//
//
