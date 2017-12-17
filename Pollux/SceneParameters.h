//
//  SceneParameters.h
//  Pollux
//
//  Created by Youssef Victor on 12/6/17.
//  Copyright © 2017 Youssef Victor. All rights reserved.
//

#ifndef SceneParameters_h
#define SceneParameters_h

/*************************************
 *************************************
 ******* Select Scene File:     ******
 *************************************
 *************************************/

// TODO:
//
// 1 - In the intersection function, add:
//    a - GetUV()
//    b - Compute TBN
//    c - add TangentToWorld/WorldToTangent
// 2 - In the shadeAndScatter function, add:
//    a - Texture Map Adjustment
//    b - Normal Map Adjustment
//    c - Roughness (Oren-Nayer) Adjustment
//
//


#define scene_file "cornell"
//#define scene_file "cornell-reflect"
//#define scene_file "cornell-refract"
//#define scene_file "environment-scene"
//#define scene_file "cornell-mesh"
//#define scene_file "mars"
//#define scene_file "marsMIS"
//#define scene_file "lion-mesh"
//#define scene_file "dragon-mesh"  -- WORK IN PROGRESS


/*************************************
 *************************************
 ******* Select Scene Integrator: ****
 *************************************
 *************************************/

#define integrator "Naive"
//#define integrator "MIS"
//#define integrator "Direct"


/****************************************
 ****************************************
 ******* Select Antialiasing Amount: ****
 ****************************************
 ****************************************/
#define AA_SIZE 2.f


#endif /* SceneParameters_h */
