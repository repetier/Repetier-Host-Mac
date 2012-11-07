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


#import <Foundation/Foundation.h>
#import <OpenGL/OpenGL.h>

typedef struct {
    GLfloat position[4]; 
    GLfloat diffuse[4]; 
    GLfloat specular[4];
    GLfloat ambient[4];
    BOOL enabled;
} RHLight;

@interface ThreeDConfig : NSObject {
    NSColor *background;
    NSColor *printer;
    NSArray *bindingsArray;
@public
    double printerBottomAlpha;
    GLfloat blackColor[4];
    GLfloat specularColor[4];
    GLfloat edgeColor[4];
    GLfloat selectedEdgeColor[4];
    GLfloat backgroundColor[4];
    GLfloat printerColor[4];
    GLfloat printerBottomColor[4];
    GLfloat objectColor[4];
    GLfloat selectedObjectColor[4];
    GLfloat filamentColor[4];
    GLfloat filament2Color[4];
    GLfloat filament3Color[4];
    GLfloat hotFilamentColor[4];
    GLfloat selectedFilamentColor[4];
    GLfloat outsidePrintbedColor[4];
    GLfloat selectionBoxColor[4];
    GLfloat travelColor[4];
    RHLight lights[4];
    BOOL showEdges;
    BOOL useVBOs;
    int drawMethod,drawMethodSelector;
    BOOL useLayerHeight;
    BOOL disableFilamentVisualization;
    BOOL showPrintbed;
    BOOL showTravel;
    BOOL showPerspective;
    float layerHeight;
    float filamentDiameter;
    float widthOverHeight;
    int filamentVisualization;
    float hotFilamentLength;
}
-(void)setColor:(NSString*)name color:(GLfloat*)col;
@end

extern ThreeDConfig *conf3d;
