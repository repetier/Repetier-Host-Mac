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


#include <stdio.h>
#include <math.h>
#include "RHMatrix.h"

void matrix4Identity(float *mat) {
    mat[0] = mat[5] = mat[10] = mat[15] = 1;
    mat[1] = mat[2] = mat[3] = mat[4] = mat[6] =
    mat[7] = mat[8] = mat[9] = mat[11] = 
    mat[12] = 
    mat[13] = 
    mat[14] = 0;
    
}
void matrix4Translatef(float *mat,float tx,float ty,float tz) {
    mat[0] = mat[5] = mat[10] = mat[15] = 1;
    mat[1] = mat[2] = mat[3] = mat[4] = mat[6] =
    mat[7] = mat[8] = mat[9] = mat[11] = 0;
    mat[12] = tx;
    mat[13] = ty;
    mat[14] = tz;
}
void matrix4RotateXf(float *mat,float rot) {
    mat[0] = mat[15] = 1;
    mat[1] = mat[2] = mat[3] = mat[4] = mat[7] = mat[8] = mat[11] = 
    mat[12] = mat[13] = mat[14] = 0;
    mat[5] = mat[10] = (float)cos(rot);
    mat[9] = -(mat[6] = (float)sin(rot));
}
void matrix4RotateYf(float *mat,float rot) {
    mat[5] = mat[15] = 1;
    mat[1] = mat[3] = mat[4] = mat[6] = mat[7] = mat[9] = mat[11] = 
    mat[12] = mat[13] = mat[14] = 0;
    mat[0] = mat[10] = (float)cos(rot);
    mat[2] = -(mat[8] = (float)sin(rot));    
}
void matrix4RotateZf(float *mat,float rot) {
    mat[10] = mat[15] = 1;
    mat[2] = mat[3] = mat[6] = mat[7] = mat[8] = mat[9] = mat[11] = 
    mat[12] = mat[13] = mat[14] = 0;
    mat[5] = mat[0] = (float)cos(rot);
    mat[1] = -(mat[4] = (float)sin(rot));    
}
void matrix4Scalef(float *mat,float sx,float sy,float sz) {
    mat[15] = 1;
    mat[1] = mat[2] = mat[3] = 
    mat[4] = mat[6] = mat[7] = mat[8] = mat[9] =
    mat[11] = mat[12] = mat[13] = mat[14] = 0;
    mat[0] = sx;
    mat[5] = sy;
    mat[10] = sz;    
}
void matrix4MulMatf(float *res,float *a,float *b) {
    for(int x=0;x<4;x++)
        for(int y=0;y<4;y++)
            res[MAT4POS(y,x)] = a[MAT4POS(y,0)]*b[MAT4POS(0,x)]+a[MAT4POS(y,1)]*b[MAT4POS(1,x)]+
            a[MAT4POS(y,2)]*b[MAT4POS(2,x)]+a[MAT4POS(y,3)]*b[MAT4POS(3,x)];
}
void matrix4MulVecf(float *mat,float *v,float *out) {
    out[0] = mat[0]*v[0]+mat[4]*v[1]+mat[8]*v[2]+mat[12]*v[3];
    out[1] = mat[1]*v[0]+mat[5]*v[1]+mat[9]*v[2]+mat[13]*v[3];
    out[2] = mat[2]*v[0]+mat[6]*v[1]+mat[10]*v[2]+mat[14]*v[3];
    out[3] = mat[3]*v[0]+mat[7]*v[1]+mat[11]*v[2]+mat[15]*v[3];
}
void matrix4MulVecRes3f(float *mat,float *v,float *out) {
    float s = mat[3]*v[0]+mat[7]*v[1]+mat[11]*v[2]+mat[15]*v[3];
    out[0] = (mat[0]*v[0]+mat[4]*v[1]+mat[8]*v[2]+mat[12]*v[3])/s;
    out[1] = (mat[1]*v[0]+mat[5]*v[1]+mat[9]*v[2]+mat[13]*v[3])/s;
    out[2] = (mat[2]*v[0]+mat[6]*v[1]+mat[10]*v[2]+mat[14]*v[3])/s;
}
float vector4Dotf(float *a,float *b) {
    return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]+a[3]*b[3];
}

