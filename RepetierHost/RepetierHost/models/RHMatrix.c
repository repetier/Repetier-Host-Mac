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

void vector3Cross(float *r,float *a,float *b) {
    r[0] = a[1]*b[2]-a[2]*b[1];
    r[1] = a[2]*b[0]-a[0]*b[2];
    r[2] = a[0]*b[1]-a[1]*b[0];
}
void vector3Normalize(float *a) {
    float len = sqrt(a[0]*a[0]+a[1]*a[1]+a[2]*a[2]);
    a[0] /= len;
    a[1] /= len;
    a[2] /= len;
}
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
    mat[1] = mat[2] = mat[12] = mat[4] = mat[6] =
    mat[13] = mat[8] = mat[9] = mat[14] = 0;
    mat[3] = tx;
    mat[7] = ty;
    mat[11] = tz;
}
void matrix4RotateXf(float *mat,float rot) {
    mat[0] = mat[15] = 1;
    mat[1] = mat[2] = mat[3] = mat[4] = mat[7] = mat[8] = mat[11] = 
    mat[12] = mat[13] = mat[14] = 0;
    mat[5] = mat[10] = (float)cos(rot);
    mat[6] = -(mat[9] = (float)sin(rot));
}
void matrix4RotateYf(float *mat,float rot) {
    mat[5] = mat[15] = 1;
    mat[1] = mat[3] = mat[4] = mat[6] = mat[7] = mat[9] = mat[11] = 
    mat[12] = mat[13] = mat[14] = 0;
    mat[0] = mat[10] = (float)cos(rot);
    mat[8] = -(mat[2] = (float)sin(rot));
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
    out[0] = mat[0]*v[0]+mat[1]*v[1]+mat[2]*v[2]+mat[3]*v[3];
    out[1] = mat[4]*v[0]+mat[5]*v[1]+mat[6]*v[2]+mat[7]*v[3];
    out[2] = mat[8]*v[0]+mat[9]*v[1]+mat[10]*v[2]+mat[11]*v[3];
    out[3] = mat[12]*v[0]+mat[13]*v[1]+mat[14]*v[2]+mat[15]*v[3];
}
void matrix4MulVecRes3f(float *mat,float *v,float *out) {
/*    float s = mat[3]*v[0]+mat[7]*v[1]+mat[11]*v[2]+mat[15]*v[3];
    out[0] = (mat[0]*v[0]+mat[4]*v[1]+mat[8]*v[2]+mat[12]*v[3])/s;
    out[1] = (mat[1]*v[0]+mat[5]*v[1]+mat[9]*v[2]+mat[13]*v[3])/s;
    out[2] = (mat[2]*v[0]+mat[6]*v[1]+mat[10]*v[2]+mat[14]*v[3])/s;*/
    float s = mat[12]*v[0]+mat[13]*v[1]+mat[14]*v[2]+mat[15]*v[3];
    out[0] = (mat[0]*v[0]+mat[1]*v[1]+mat[2]*v[2]+mat[3]*v[3])/s;
    out[1] = (mat[4]*v[0]+mat[5]*v[1]+mat[6]*v[2]+mat[7]*v[3])/s;
    out[2] = (mat[8]*v[0]+mat[9]*v[1]+mat[10]*v[2]+mat[11]*v[3])/s;
}
float vector4Dotf(float *a,float *b) {
    return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]+a[3]*b[3];
}
float matrix4Cofactor(float m0, float m1, float m2,
                      float m3, float m4, float m5,
                      float m6, float m7, float m8)
{
    return m0 * (m4 * m8 - m5 * m7) -
    m1 * (m3 * m8 - m5 * m6) +
    m2 * (m3 * m7 - m4 * m6);
}
float matrix4DDeterminant(float *m)
{
    return m[0] * matrix4Cofactor(m[5],m[9],m[13], m[6],m[10],m[14], m[7],m[11],m[15]) -
    m[4] * matrix4Cofactor(m[1],m[9],m[13], m[2],m[10],m[14], m[3],m[11],m[15]) +
    m[8] * matrix4Cofactor(m[1],m[5],m[13], m[2],m[6], m[14], m[3],m[7],m[15]) -
    m[12] * matrix4Cofactor(m[1],m[5],m[9], m[2],m[6], m[10], m[3],m[7],m[11]);
}

void matrix4Invert(float *res,float *m) {
    float cofactor0 = matrix4Cofactor(m[5],m[9],m[13], m[6],m[10],m[14], m[7],m[11],m[15]);
    float cofactor1 = matrix4Cofactor(m[1],m[9],m[13], m[2],m[10],m[14], m[3],m[11],m[15]);
    float cofactor2 = matrix4Cofactor(m[1],m[5],m[13], m[2],m[6], m[14], m[3],m[7],m[15]);
    float cofactor3 = matrix4Cofactor(m[1],m[5],m[9], m[2],m[6], m[10], m[3],m[7],m[11]);
    
    // get determinant
    float determinant = m[0] * cofactor0 - m[4] * cofactor1 + m[8] * cofactor2 - m[12] * cofactor3;
    if(fabs(determinant) <= 0.00001f)
    {
        matrix4Identity(res);
        return;
    }
        
    float cofactor4 = matrix4Cofactor(m[4],m[8],m[12], m[6],m[10],m[14], m[7],m[11],m[15]);
    float cofactor5 = matrix4Cofactor(m[0],m[8],m[12], m[2],m[10],m[14], m[3],m[11],m[15]);
    float cofactor6 = matrix4Cofactor(m[0],m[4],m[12], m[2],m[6], m[14], m[3],m[7],m[15]);
    float cofactor7 = matrix4Cofactor(m[0],m[4],m[8], m[2],m[6], m[10], m[3],m[7],m[11]);
    
    float cofactor8 = matrix4Cofactor(m[4],m[8],m[12], m[5],m[9], m[13],  m[7],m[11],m[15]);
    float cofactor9 = matrix4Cofactor(m[0],m[8],m[12], m[1],m[9], m[13],  m[3],m[11],m[15]);
    float cofactor10= matrix4Cofactor(m[0],m[4],m[12], m[1],m[5], m[13],  m[3],m[7],m[15]);
    float cofactor11= matrix4Cofactor(m[0],m[4],m[8], m[1],m[5], m[9],  m[3],m[7],m[11]);
    
    float cofactor12= matrix4Cofactor(m[4],m[8],m[12], m[5],m[9], m[13],  m[6], m[10],m[14]);
    float cofactor13= matrix4Cofactor(m[0],m[8],m[12], m[1],m[9], m[13],  m[2], m[10],m[14]);
    float cofactor14= matrix4Cofactor(m[0],m[4],m[12], m[1],m[5], m[13],  m[2], m[6], m[14]);
    float cofactor15= matrix4Cofactor(m[0],m[4],m[8], m[1],m[5], m[9],  m[2], m[6], m[10]);
    float invDeterminant = 1.0f / determinant;
    res[0] =  invDeterminant * cofactor0;
    res[4] = -invDeterminant * cofactor4;
    res[8] =  invDeterminant * cofactor8;
    res[12] = -invDeterminant * cofactor12;
    
    res[1] = -invDeterminant * cofactor1;
    res[5] =  invDeterminant * cofactor5;
    res[9] = -invDeterminant * cofactor9;
    res[13] =  invDeterminant * cofactor13;
    
    res[2] =  invDeterminant * cofactor2;
    res[6] = -invDeterminant * cofactor6;
    res[10]=  invDeterminant * cofactor10;
    res[14]= -invDeterminant * cofactor14;
    
    res[3]= -invDeterminant * cofactor3;
    res[7]=  invDeterminant * cofactor7;
    res[11]= -invDeterminant * cofactor11;
    res[15]=  invDeterminant * cofactor15;
 
}
void matrix4LookAt(float *m,float *eye,float *center,float upx,float upy,float upz) {
    float f[3];
    f[0] = -center[0]+eye[0];
    f[1] = -center[1]+eye[1];
    f[2] = -center[2]+eye[2];
    vector3Normalize(f);
    float up[3] = {upx,upy,upz};
    vector3Normalize(up);
    float s[3];
    vector3Cross(s,up,f);
    vector3Normalize(s);
    float u[3];
    vector3Cross(u,f,s);
    vector3Normalize(u);
    /*  |  s[0]  s[1]  s[2]  0 |
    M = |  u[0]  u[1]  u[2]  0 |
        | -f[0] -f[1] -f[2]  0 |
        |   0     0     0    1 | */
    Matrix4f m2,trans;
    m2[0] = s[0];
    m2[4] = u[0];
    m2[8] = f[0];
    m2[12] = 0;
    m2[1] = s[1];
    m2[5] = u[1];
    m2[9] = f[1];
    m2[13] = 0;
    m2[2] = s[2];
    m2[6] = u[2];
    m2[10] = f[2];
    m2[14] = 0;
    m2[3] = 0;
    m2[7] = 0;
    m2[11] = 0;
    m2[15] = 1;
    matrix4Translatef(trans, -eye[0], -eye[1], -eye[2]);
    matrix4MulMatf(m, trans,m2);
}
