#include <metal_stdlib>
using namespace metal;

namespace Loki {
    
//    thread unsigned* last_seed() {
//        thread uint last_seed = 1;
//        return &last_seed;
//    }
    
    unsigned TausStep(const unsigned z, const int s1, const int s2, const int s3, const unsigned M)
    {
        unsigned b=(((z << s1) ^ z) >> s2);
        return (((z & M) << s3) ^ b);
    }
    
    device float rng(const int initial_seed) {
        int seed = initial_seed * 1099087573UL;
        
        unsigned z1 = TausStep(seed,13,19,12,429496729UL);
        unsigned z2 = TausStep(seed,2,25,4,4294967288UL);
        unsigned z3 = TausStep(seed,3,11,17,429496280UL);
        unsigned z4 = (1664525*seed + 1013904223UL);
        
        // Round 2
        unsigned r1 = (z1^z2^z3^z4);
//        *last_seed() = r1;
        
        z1 = TausStep(r1,13,19,12,429496729UL);
        z2 = TausStep(r1,2,25,4,4294967288UL);
        z3 = TausStep(r1,3,11,17,429496280UL);
        z4 = (1664525*r1 + 1013904223UL);
        
        return (z1^z2^z3^z4) * 2.3283064365387e-10;
    }
    
//    device float rng() {
//        if (*last_seed() == 0) {
//            return 0.0;
//        } else {
//            unsigned z1 = TausStep(*last_seed(),13,19,12,429496729UL);
//            unsigned z2 = TausStep(*last_seed(),2,25,4,4294967288UL);
//            unsigned z3 = TausStep(*last_seed(),3,11,17,429496280UL);
//            unsigned z4 = (1664525*(*last_seed()) + 1013904223UL);
//
//            return (z1^z2^z3^z4) * 2.3283064365387e-10;
//        }
//    }
};
