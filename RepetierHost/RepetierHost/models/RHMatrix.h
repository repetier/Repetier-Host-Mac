/*
 Copyright 2011 repetier repetierdev@googlemail.com
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */


#ifndef RepetierHost_RHMatrix_h
#define RepetierHost_RHMatrix_h

// Matrix format is column based
/*
 0 4  8 12
 1 5  9 13
 2 6 10 14
 3 7 11 15
 */
typedef float Matrix4f[16];
#define MAT4POS(row,col) (4*col+row)
extern void matrix4Translatef(float *mat,float tx,float ty,float tz);
extern void matrix4RotateXf(float *mat,float rot);
extern void matrix4RotateYf(float *mat,float rot);
extern void matrix4RotateZf(float *mat,float rot);
extern void matrix4Scalef(float *mat,float sx,float sy,float sz);
extern void matrix4MulMatf(float *res,float *a,float *b);
extern float vector4Dotf(float *a,float *b);
extern void matrix4Identity(float *mat);
extern void matrix4MulVecf(float *mat,float *v,float *out);
extern void matrix4MulVecRes3f(float *mat,float *v,float *out);
#endif
