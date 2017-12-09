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


//#define scene_file "cornell"
//#define scene_file "cornell-reflect"
//#define scene_file "cornell-refract"
//#define scene_file "environment-scene-sss"
#define scene_file "cornell-subsurface"

/*************************************
 *************************************
 ******* Select Scene Integrator: ****
 *************************************
 *************************************/

#define integrator "Naive"
//#define integrator "MIS"
//#define integrator "Direct"

// TODO: MIS and Direct do not sample any data from environment maps, so "environment-scene" will have no lighting on objects


#endif /* SceneParameters_h */
