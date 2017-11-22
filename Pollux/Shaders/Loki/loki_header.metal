/*
 * Loki Random Number Generator
 * Copyright (c) 2017 Youssef Victor All rights reserved.
 *
 *      Function                        Result
 *      ------------------------------------------------------------------
 *
 *      TausStep                        Combined Tausworthe Generator or
 *                                      Linear Feedback Shift Register (LFSR)
 *                                      random number generator. This is a
 *                                      helper method for rng, which uses
 *                                      a hybrid approach combining LFSR with
 *                                      a Linear Congruential Generator (LCG)
 *                                      in order to produce random numbers with
 *                                      periods of well over 2^121
 *
 *      rng                             A pseudo-random number based on the
 *                                      method outlined in "Efficient
 *                                      pseudo-random number generation
 *                                      for monte-carlo simulations using
 *                                      graphic processors" by Siddhant
 *                                      Mohanty et al 2012.
 *
 */

#include <metal_stdlib>
using namespace metal;

namespace Loki {
//    thread uint* last_seed();
    uint TausStep(const unsigned z, const int s1, const int s2, const int s3, const unsigned M);
    device float rng(const unsigned initial_seed, const unsigned second_seed = 1.f);
    device float rng(const    float initial_seed, const    float second_seed = 1.f);
//    device float rng();
};
