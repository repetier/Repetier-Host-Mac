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


#import "ThreeDContainer.h"
#include <GLUT/GLUT.h>
#include <OpenGL/gl.h>
#include "PrinterConnection.h"
#include "PrinterConfiguration.h"
#include "ThreeDConfig.h"
#include "STL.h"
#include "RHMatrix.h"

@implementation ThreeDContainer

-(id)init {
    if((self=[super init])) {
        [self resetView];
        //showPrintbed = YES;
        white[0] = white[1] = white[2] = white[3] = 1;
        ambient[0] = ambient[1] = ambient[2] = 0.2;
        ambient[3] = 1;
        models = [RHLinkedList new];
        
        testPoints[0] = testPoints[1] = 0;
       /*
        STL *stl = [STL new];
        if([stl load:@"/Users/littwin/Documents/openscad/gears/Repetier-pulley.stl"]) {
            [stl centerX:connection->config->width/2 y:connection->config->depth/2];
            [models addLast:stl];
        }*/
    }
    return self;
}
-(void)dealloc {
    [models release];
    [super dealloc];
}
-(void)clearGraphicContext {
    for(ThreeDModel *mod in models)
        [mod clearGraphicContext];
}
-(void)resetView {
    rotX = 20;
    rotZ = 0;
    zoom = 1.0f;
    PrinterConfiguration *conf = connection->config;
    viewCenter[0] = 0;//0.25 * conf->width;
    viewCenter[1] = 0;// conf->depth * 0.25;
    viewCenter[2] = 0;//0.0f * conf->height;
    userPosition[0] = 0;
    userPosition[1] = -1.7*sqrt(conf->depth*conf->depth+conf->width*conf->width);
    userPosition[2] = 0;
//    gl.Invalidate();
}
-(void)topView {
    rotX = 90;
    rotZ = 0;
    zoom = 1.0f;
    PrinterConfiguration *conf = connection->config;
    viewCenter[0] = 0;//0.25 * conf->width;
    viewCenter[1] = 0;// conf->depth * 0.25;
    viewCenter[2] = 0;//0.0f * conf->height;
    userPosition[0] = 0;
    userPosition[1] = -1.7*sqrt(conf->depth*conf->depth+conf->width*conf->width);
    userPosition[2] = 0;
    //    gl.Invalidate();
}
-(void)setupViewportWidth:(double)width height:(double)height
{
    glViewport(0,0,width,height); // Use all of the glControl painting area
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    float dx = viewCenter[0] - userPosition[0];
    float dy = viewCenter[1] - userPosition[1];
    float dz = viewCenter[2] - userPosition[2];
    dist = (float)sqrt(dx * dx + dy * dy + dz * dz);
    PrinterConfiguration *conf = connection->config;
    
    gluPerspective((zoom*30), width/height,  MAX(10,dist-2*conf->depth), dist+ 2*conf->depth);      
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
}
// Draws the current view online
// All operations must be thread safe, so the model doesn't change
// unexpectedly during draw operation
-(void)paintWidth:(double)width height:(double)height {
    PrinterConfiguration *conf = connection->config;
    glClearColor(conf3d->backgroundColor[0], conf3d->backgroundColor[1],conf3d->backgroundColor[2],conf3d->backgroundColor[3]);
    glClearDepth(1.0f);
    glDepthFunc(GL_LESS);

    // Set up a hint telling the computer to create the nicest (aka "costliest" or "most correct")
    // image it can
    // This hint is for the quality of color and texture mapping
  //  glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
    
    // This hint is for antialiasing
   // glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST);

    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glEnable(GL_DEPTH_TEST);
    glDisable(GL_BLEND);
    [self setupViewportWidth:width height:height];
    gluLookAt(userPosition[0],userPosition[1],userPosition[2],
              viewCenter[0],viewCenter[1],viewCenter[2],0,0,1);
    glShadeModel(GL_SMOOTH);
    glEnable(GL_NORMALIZE);
        //Enable lighting
    GLfloat global_ambient[] = { 0.2f, 0.2f, 0.2f, 1.0f };
    glLightModelfv(GL_LIGHT_MODEL_AMBIENT, global_ambient);
    int i;
    for(i=0;i<4;i++) {
        glLightfv(GL_LIGHT0+i,GL_AMBIENT, conf3d->lights[i].ambient);
        glLightfv(GL_LIGHT0+i,GL_DIFFUSE,conf3d->lights[i].diffuse);
        glLightfv(GL_LIGHT0+i,GL_SPECULAR, conf3d->lights[i].specular);
        glLightfv(GL_LIGHT0+i, GL_POSITION,conf3d->lights[i].position);
        if(conf3d->lights[i].enabled)
            glEnable(GL_LIGHT0+i);
        else
            glDisable(GL_LIGHT0+i);
    }
    glEnable(GL_LIGHTING);
    //glEnable(GL_LINE_SMOOTH);
    //glEnable(GL_BLEND);
    glLineWidth(2.0f);
    //glHint(GL_LINE_SMOOTH_HINT,GL_NICEST);
    //glBlendFunc(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_MULTISAMPLE);
    //Enable Backfaceculling
        
    // Draw viewpoint
               
    glRotated(rotX, 1, 0, 0);
    glRotated(rotZ, 0, 0, 1);
    glTranslated(-conf->width*0.5,-conf->depth*0.5,-0.5*conf->height);
    glMaterialfv(GL_FRONT_AND_BACK,GL_SPECULAR,white);
        
    double dx1 = conf->dumpAreaLeft;
    double dx2 = dx1 + conf->dumpAreaWidth;
    double dy1 = conf->dumpAreaFront;
    double dy2 = dy1 + conf->dumpAreaDepth;
    if (conf3d->showPrintbed)
    {
        glMaterialfv(GL_FRONT_AND_BACK,GL_AMBIENT_AND_DIFFUSE,conf3d->blackColor);
        glMaterialfv(GL_FRONT_AND_BACK,GL_EMISSION,conf3d->blackColor);
        glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR,conf3d->blackColor);
        glMaterialfv(GL_FRONT_AND_BACK,GL_EMISSION,conf3d->printerColor);
        
        
        
        glColor3b(255,0,0);
        float vertexBuffer[] = {0,60,0,120,60,0,60,80,40};
        GLuint indicesBuffer[] = {0,1,2};
        if(testPoints[0]==0) {
            glGenBuffers(2,testPoints);
            glBindBuffer(GL_ARRAY_BUFFER, testPoints[0]);
            glBufferData(GL_ARRAY_BUFFER,9*4, vertexBuffer,GL_STATIC_DRAW);
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,testPoints[1]);
            glBufferData(GL_ELEMENT_ARRAY_BUFFER,sizeof(GLuint)*3, indicesBuffer,GL_STATIC_DRAW);
        }
       /* glDisable(GL_CULL_FACE);
        glEnableClientState( GL_VERTEX_ARRAY );
        //gl.glEnableClientState(GL.GL_NORMAL_ARRAY );
       // glEnableVertexAttribArray(0);
       // glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,0,vertexBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, testPoints[0]);
        glVertexPointer( 3 , GL_FLOAT , 0 , 0 );
        //gl.glNormalPointer( GL.GL_FLOAT , 0 , normalBuffer );
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER,testPoints[1]);
        glDrawElements( GL_TRIANGLES , 3 , GL_UNSIGNED_INT, 0);
        glDisableClientState(GL_VERTEX_ARRAY);
       // glDisableVertexAttribArray(0);
        glFlush();*/
        
        glBegin(GL_LINES);
        int i;
        // Print cube
        glVertex3d(0, 0, 0);
        glVertex3d(0, 0, conf->height);
        glVertex3d(conf->width, 0, 0);
        glVertex3d(conf->width, 0, conf->height);
        glVertex3d(0, conf->depth, 0);
        glVertex3d(0, conf->depth, conf->height);
        glVertex3d(conf->width, conf->depth, 0);
        glVertex3d(conf->width, conf->depth, conf->height);
        glVertex3d(0, 0, conf->height);
        glVertex3d(conf->width, 0, conf->height);
        glVertex3d(conf->width, 0, conf->height);
        glVertex3d(conf->width, conf->depth, conf->height);
        glVertex3d(conf->width, conf->depth, conf->height);
        glVertex3d(0, conf->depth, conf->height);
        glVertex3d(0, conf->depth, conf->height);
        glVertex3d(0, 0, conf->height);
        if (conf->hasDumpArea)
        {
            if (dy1 != 0)
            {
                glVertex3d(dx1, dy1, 0);
                glVertex3d(dx2, dy1, 0);
            }
            glVertex3d(dx2, dy1, 0);
            glVertex3d(dx2, dy2, 0);
            glVertex3d(dx2, dy2, 0);
            glVertex3d(dx1, dy2, 0);
            glVertex3d(dx1, dy2, 0);
            glVertex3d(dx1, dy1, 0);
        }
        double dx = 10; //conf->width / 20;
        double dy = 10; //conf->depth / 20;
        double x,y;
        for (i = 0; i < 201; i++)
        {
            x = (double)i*dx;
            if(x>conf->width) x = conf->width;
            if (conf->hasDumpArea && x >= dx1 && x <= dx2)
            {
                glVertex3d(x, 0, 0);
                glVertex3d(x, dy1, 0);
                glVertex3d(x, dy2, 0);
                glVertex3d(x, conf->depth, 0);
            }
            else
            {
                glVertex3d(x, 0, 0);
                glVertex3d(x, conf->depth, 0);
            }
            if(x >=conf->width) break;
        }
        for (i = 0; i < 21; i++)
        {
            y = (double)i*dy;
            if(y>conf->depth) y = conf->depth;
            if (conf->hasDumpArea && y >= dy1 && y <= dy2)
            {
                glVertex3d(0, y, 0);
                glVertex3d(dx1, y, 0);
                glVertex3d(dx2, y, 0);
                glVertex3d(conf->width, y, 0);
            }
            else
            {
                glVertex3d(0, y, 0);
                glVertex3d(conf->width, y, 0);
            }
            if(y>=conf->depth) break;
        }
        glEnd();
    }
    glEnable(GL_CULL_FACE);

    for (ThreeDModel *model in models) {
        glPushMatrix();
        [model animationBefore];
        glTranslatef(model->position[0], model->position[1],model->position[2]);
        glRotatef(model->rotation[2],0,0,1);
        glRotatef(model->rotation[1],0,1,0);
        glRotatef(model->rotation[0],1,0,0);
        glScalef(model->scale[0],model->scale[1],model->scale[2]);
        [model paint];
        [model animationAfter];
        glPopMatrix();
     }

    if (conf3d->showPrintbed)
    {
        glDisable(GL_CULL_FACE);
        glEnable(GL_BLEND);	// Turn Blending On
        glBlendFunc (GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
       // glDisable(GL_LIGHTING);
        // Draw bottom
        GLfloat transblack[] = {0,0,0,0};
        glMaterialfv(GL_FRONT_AND_BACK,GL_AMBIENT,conf3d->printerBottomColor);
        glMaterialfv(GL_FRONT_AND_BACK,GL_DIFFUSE,conf3d->printerBottomColor);
        glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR,transblack);
        glMaterialfv(GL_FRONT_AND_BACK,GL_EMISSION,transblack);
        glPushMatrix();
        glTranslatef(0,0,-0.04);
        glBegin(GL_QUADS);
        glNormal3d(0,0,1);

        if (conf->hasDumpArea) {
            if(dy1>0) {
                glVertex3d(0,0,0);
                glVertex3d(conf->width, 0,0);
                glVertex3d(conf->width,dy1,0);
                glVertex3d(0,dy1,0);                
            }
           if(dy2<conf->depth) {
                glVertex3d(0,dy2,0);
                glVertex3d(conf->width, dy2,0);
                glVertex3d(conf->width,conf->depth,0);
                glVertex3d(0,conf->depth,0);
            }
            if(dx1>0) {
                glVertex3d(0,dy1,0);
                glVertex3d(dx1, dy1,0);
                glVertex3d(dx1,dy2,0);
                glVertex3d(0,dy2,0);                
            }
            if(dx2<conf->width) {
                glVertex3d(dx2,dy1,0);
                glVertex3d(conf->width, dy1,0);
                glVertex3d(conf->width,dy2,0);
                glVertex3d(dx2,dy2,0);
            }
        } else {
            glVertex3d(0,0,0);
            glVertex3d(conf->width, 0,0);
            glVertex3d(conf->width,conf->depth,0);
            glVertex3d(0,conf->depth,0);
        }

        glEnd();
        glPopMatrix();
        glDisable(GL_BLEND);
        
    }
    /*glBegin(GL_TRIANGLES);
    glVertex3d(0,60,0);
    glVertex3d(120,60,0);
    glVertex3d(60,80,40);
    glEnd();*/

//        gl.SwapBuffers();
}
-(void)gluPickMatrix:(float*)result x:(float)x y:(float)y width:(float)width height:(float)height viewport:(int *)viewport
{
    matrix4Identity(result);
    if ((width <= 0.0f) || (height <= 0.0f))
    {
        return;
    }
    
    float translateX = (viewport[2] - (2.0f * (x - viewport[0]))) / width;
    float translateY = (viewport[3] - (2.0f * (y - viewport[1]))) / height;
    float m1[16],m2[16];
    matrix4Translatef(m1,translateX,translateY,0);
    float scaleX = viewport[2] / width;
    float scaleY = viewport[3] / height;
    matrix4Scalef(m2, scaleX, scaleY, 1);
    matrix4MulMatf(result,m2, m1);
}
-(ThreeDModel*)PicktestX:(float)x Y:(float)y width:(float)width height:(float)height
{
    GLuint selectBuffer[128];
    glSelectBuffer(128, selectBuffer);
    glRenderMode(GL_SELECT);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glEnable(GL_DEPTH_TEST);
    glMatrixMode(GL_PROJECTION);
    glDisable(GL_MULTISAMPLE);
    glPushMatrix();
    glLoadIdentity();
    
    int viewport[4];
    glGetIntegerv(GL_VIEWPORT, viewport);
    
    gluPickMatrix(x, y, 1, 1, viewport);
    gluPerspective((zoom*30), width/height,  MAX(10,dist-2*currentPrinterConfiguration->depth), dist+ 2*currentPrinterConfiguration->depth);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    gluLookAt(userPosition[0],userPosition[1],userPosition[2],
              viewCenter[0],viewCenter[1],viewCenter[2],0,0,1);
    glRotated(rotX, 1, 0, 0);
    glRotated(rotZ, 0, 0, 1);
    glTranslated(-currentPrinterConfiguration->width*0.5,-currentPrinterConfiguration->depth*0.5,-0.5*currentPrinterConfiguration->height);
    
    glInitNames();
    GLuint pos = 0;
    for (ThreeDModel *model in models)
    {
        glPushName(pos++);
        glPushMatrix();
        [model animationBefore];
        glTranslatef(model->position[0], model->position[1],model->position[2]);
        glRotatef(model->rotation[2],0,0,1);
        glRotatef(model->rotation[1],0,1,0);
        glRotatef(model->rotation[0],1,0,0);
        glScalef(model->scale[0],model->scale[1],model->scale[2]);
        [model paint];
        [model animationAfter];
        glPopMatrix();
        glPopName();
    }
    glMatrixMode(GL_PROJECTION);
    glPopMatrix();
    glMatrixMode(GL_MODELVIEW);
    glFlush();
    int hits = glRenderMode(GL_RENDER);
    ThreeDModel *selected = nil;
    //NSLog(@"Object hits: %d",hits);
    if (hits > 0)
    {
        selected = [models objectAtIndex:selectBuffer[3]];
        uint depth = selectBuffer[1];
        for (int i = 1; i < hits; i++)
        {
            if (selectBuffer[4 * i + 1] < depth)
            {
                depth = selectBuffer[i * 4 + 1];
                selected = [models objectAtIndex:selectBuffer[i * 4 + 3]];
            }
        }
    }
    //PrinterConnection.logInfo("Hits: " + hits);
    return selected;
}
/*
private void ThreeDControl_Load(object sender, EventArgs e)
{
    loaded = true;
    SetupViewport();
}

private void gl_Resize(object sender, EventArgs e)
{
    SetupViewport();
    gl.Invalidate();
}
*/
@end
