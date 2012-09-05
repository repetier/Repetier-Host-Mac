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


#import "ThreeDConfig.h"
#import "RHAppDelegate.h"
#import "DefaultsExtension.h"
#import "RHOpenGLView.h"

@implementation ThreeDConfig


-(id)init {
    if((self=[super init])) {
        drawMethod = 2;
        useVBOs = NO;
        //threedFilamentVisualization
        NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
        //threedFacesColor
        NSArray *arr = [NSArray arrayWithObjects:@"threedFilamentVisualization",
                 @"threedFacesColor",@"threedSelectedFacesColor",@"threedShowPrintbed",  
                @"threedAccelerationMethod",@"disableFilamentVisualization",
                @"threedDrawEdges",@"threedHeightMethod",@"threedBottomTransparency",@"threedLayerHeight",
                @"threedWidthOverHeight",@"threedFilamentDiameter",@"threedHotFilamentLength",
                @"threedLight1XDir",@"threedLight1YDir",@"threedLight1ZDir",@"threedLight1Enabled",
                @"threedLight2XDir",@"threedLight2YDir",@"threedLight2ZDir",@"threedLight2Enabled",
                @"threedLight3XDir",@"threedLight3YDir",@"threedLight3ZDir",@"threedLight3Enabled",
                @"threedLight4XDir",@"threedLight4YDir",@"threedLight4ZDir",@"threedLight4Enabled",
                @"threedEdgesColor",@"threedSelectedEdgesColor",@"threedFilamentColor",@"threedHotFilamentColor",
                @"threedBackgroundColor",@"threedPrinterColor",@"threedPrinterBottomColor",
                @"threedLight1AmbientColor",@"threedLight1DiffuseColor",@"threedLight1SpecularColor",        
                @"threedLight2AmbientColor",@"threedLight2DiffuseColor",@"threedLight2SpecularColor",        
                @"threedLight3AmbientColor",@"threedLight3DiffuseColor",@"threedLight3SpecularColor",        
                @"threedLight4AmbientColor",@"threedLight4DiffuseColor",@"threedLight4SpecularColor",
                @"threedFilamentColor2",@"threedFilamentColor3",@"threedSelectedFilamentColor",
                        nil];
        bindingsArray = arr.retain;
        for(NSString *key in arr)
        [d addObserver:self forKeyPath:key options:NSKeyValueObservingOptionNew context:NULL];
        drawMethodSelector = (int)[d integerForKey:@"threedAccelerationMethod"];
        disableFilamentVisualization = [d integerForKey:@"disableFilamentVisualization"];
        filamentVisualization = (int)[d integerForKey:@"threedFilamentVisualization"];
        showPrintbed = [d boolForKey:@"threedShowPrintbed"];
        showEdges = [d integerForKey:@"threedDrawEdges"];
        useLayerHeight = 0==[d integerForKey:@"threedHeightMethod"];
        printerBottomAlpha = [d doubleForKey:@"threedBottomTransparency"];
        layerHeight = [d doubleForKey:@"threedLayerHeight"];
        widthOverHeight = [d doubleForKey:@"threedWidthOverHeight"];
        filamentDiameter = [d doubleForKey:@"threedFilamentDiameter"];
        hotFilamentLength = [d doubleForKey:@"threedHotFilamentLength"];
        lights[0].position[0] = [d floatForKey:@"threedLight1XDir"];
        lights[0].position[1] = [d floatForKey:@"threedLight1YDir"];
        lights[0].position[2] = [d floatForKey:@"threedLight1ZDir"];
        lights[0].position[3] = 0;
        lights[1].position[0] = [d floatForKey:@"threedLight2XDir"];
        lights[1].position[1] = [d floatForKey:@"threedLight2YDir"];
        lights[1].position[2] = [d floatForKey:@"threedLight2ZDir"];
        lights[1].position[3] = 0;
        lights[2].position[0] = [d floatForKey:@"threedLight3XDir"];
        lights[2].position[1] = [d floatForKey:@"threedLight3YDir"];
        lights[2].position[2] = [d floatForKey:@"threedLight3ZDir"];
        lights[2].position[3] = 0;
        lights[3].position[0] = [d floatForKey:@"threedLight4XDir"];
        lights[3].position[1] = [d floatForKey:@"threedLight4YDir"];
        lights[3].position[2] = [d floatForKey:@"threedLight4ZDir"];
        lights[3].position[3] = 0;
        lights[0].enabled = [d boolForKey:@"threedLight1Enabled"];
        lights[1].enabled = [d boolForKey:@"threedLight2Enabled"];
        lights[2].enabled = [d boolForKey:@"threedLight3Enabled"];
        lights[3].enabled = [d boolForKey:@"threedLight4Enabled"];
        [self setColor:@"threedFacesColor" color:objectColor];
        [self setColor:@"threedSelectedFacesColor" color:selectedObjectColor];
        [self setColor:@"threedEdgesColor" color:edgeColor];
        [self setColor:@"threedSelectedEdgesColor" color:selectedEdgeColor];
        [self setColor:@"threedFilamentColor" color:filamentColor];
        [self setColor:@"threedFilamentColor2" color:filament2Color];
        [self setColor:@"threedFilamentColor3" color:filament3Color];
        [self setColor:@"threedHotFilamentColor" color:hotFilamentColor];
        [self setColor:@"threedSelectedFilamentColor" color:selectedFilamentColor];
        [self setColor:@"threedBackgroundColor" color:backgroundColor];
        [self setColor:@"threedPrinterColor" color:printerColor];
        [self setColor:@"threedPrinterBottomColor" color:printerBottomColor];
        [self setColor:@"threedLight1AmbientColor" color:lights[0].ambient];
        [self setColor:@"threedLight1DiffuseColor" color:lights[0].diffuse];
        [self setColor:@"threedLight1SpecularColor" color:lights[0].specular];
        [self setColor:@"threedLight2AmbientColor" color:lights[1].ambient];
        [self setColor:@"threedLight2DiffuseColor" color:lights[1].diffuse];
        [self setColor:@"threedLight2SpecularColor" color:lights[1].specular];
        [self setColor:@"threedLight3AmbientColor" color:lights[2].ambient];
        [self setColor:@"threedLight3DiffuseColor" color:lights[2].diffuse];
        [self setColor:@"threedLight3SpecularColor" color:lights[2].specular];
        [self setColor:@"threedLight4AmbientColor" color:lights[3].ambient];
        [self setColor:@"threedLight4DiffuseColor" color:lights[3].diffuse];
        [self setColor:@"threedLight4SpecularColor" color:lights[3].specular];
        printerBottomColor[3] = 0.01*printerBottomAlpha;

    }
    return self;
}
-(void)dealloc {
    for(NSString *key in bindingsArray)
    [NSUserDefaults.standardUserDefaults removeObserver:self
                        forKeyPath:key];
    [bindingsArray release];
    [super dealloc];
}
-(void)setColor:(NSString*)name color:(GLfloat*)col {
    NSColor *color = [[NSUserDefaults.standardUserDefaults colorForKey:name] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    col[0] = color.redComponent;
    col[1] = color.greenComponent;
    col[2] = color.blueComponent;
    col[3] = 1.0;
}
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    //NSLog(@"Key changed:%@",keyPath);
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    if ([keyPath isEqual:@"threedFilamentVisualization"]) {
        filamentVisualization = (int)[NSUserDefaults.standardUserDefaults integerForKey:keyPath];        
    } else if([keyPath isEqual:@"threedFacesColor"]) {
        [self setColor:keyPath color:objectColor];
    } else if([keyPath isEqual:@"threedSelectedFacesColor"]) {
        [self setColor:keyPath color:selectedObjectColor];
    } else if([keyPath isEqual:@"threedEdgesColor"]) {
        [self setColor:@"threedEdgesColor" color:edgeColor];
    } else if([keyPath isEqual:@"threedSelectedEdgesColor"]) {
        [self setColor:@"threedSelectedEdgesColor" color:selectedEdgeColor];
    } else if([keyPath isEqual:@"threedFilamentColor"]) {
        [self setColor:@"threedFilamentColor" color:filamentColor];
    } else if([keyPath isEqual:@"threedFilamentColor2"]) {
        [self setColor:@"threedFilamentColor2" color:filament2Color];
    } else if([keyPath isEqual:@"threedFilamentColor3"]) {
        [self setColor:@"threedFilamentColor3" color:filament3Color];
    } else if([keyPath isEqual:@"threedHotFilamentColor"]) {
        [self setColor:@"threedHotFilamentColor" color:hotFilamentColor];
    } else if([keyPath isEqual:@"threedSelectedFilamentColor"]) {
        [self setColor:@"threedSelectedFilamentColor" color:selectedFilamentColor];
    } else if([keyPath isEqual:@"threedBackgroundColor"]) {
        [self setColor:@"threedBackgroundColor" color:backgroundColor];
    } else if([keyPath isEqual:@"threedPrinterColor"]) {
        [self setColor:@"threedPrinterColor" color:printerColor];
    } else if([keyPath isEqual:@"threedPrinterBottomColor"]) {
        [self setColor:@"threedPrinterBottomColor" color:printerBottomColor];
        printerBottomColor[3] = 0.01*printerBottomAlpha;
    } else if([keyPath isEqual:@"threedLight1AmbientColor"]) {
        [self setColor:@"threedLight1AmbientColor" color:lights[0].ambient];
    } else if([keyPath isEqual:@"threedLight1DiffuseColor"]) {
        [self setColor:@"threedLight1DiffuseColor" color:lights[0].diffuse];
    } else if([keyPath isEqual:@"threedLight1SpecularColor"]) {
        [self setColor:@"threedLight1SpecularColor" color:lights[0].specular];
    } else if([keyPath isEqual:@"threedLight2AmbientColor"]) {
        [self setColor:@"threedLight2AmbientColor" color:lights[1].ambient];
    } else if([keyPath isEqual:@"threedLight2DiffuseColor"]) {
        [self setColor:@"threedLight2DiffuseColor" color:lights[1].diffuse];
    } else if([keyPath isEqual:@"threedLight2SpecularColor"]) {
        [self setColor:@"threedLight2SpecularColor" color:lights[1].specular];
    } else if([keyPath isEqual:@"threedLight3AmbientColor"]) {
        [self setColor:@"threedLight3AmbientColor" color:lights[2].ambient];
    } else if([keyPath isEqual:@"threedLight3DiffuseColor"]) {
        [self setColor:@"threedLight3DiffuseColor" color:lights[2].diffuse];
    } else if([keyPath isEqual:@"threedLight3SpecularColor"]) {
        [self setColor:@"threedLight3SpecularColor" color:lights[2].specular];
    } else if([keyPath isEqual:@"threedLight4AmbientColor"]) {
        [self setColor:@"threedLight4AmbientColor" color:lights[3].ambient];
    } else if([keyPath isEqual:@"threedLight4DiffuseColor"]) {
        [self setColor:@"threedLight4DiffuseColor" color:lights[3].diffuse];
    } else if([keyPath isEqual:@"threedLight4SpecularColor"]) {
        [self setColor:@"threedLight4SpecularColor" color:lights[3].specular];
    }
    //drawMethod = (int)[d integerForKey:@"threedAccelerationMethod"];
    disableFilamentVisualization = [d integerForKey:@"disableFilamentVisualization"];
    filamentVisualization = (int)[d integerForKey:@"threedFilamentVisualization"];
    showPrintbed = [d boolForKey:@"threedShowPrintbed"];
    showEdges = [d integerForKey:@"threedDrawEdges"];
    useLayerHeight = 0==[d integerForKey:@"threedHeightMethod"];
    printerBottomAlpha = [d doubleForKey:@"threedBottomTransparency"];
    printerBottomColor[3] = 0.01*printerBottomAlpha;
    layerHeight = [d doubleForKey:@"threedLayerHeight"];
    widthOverHeight = [d doubleForKey:@"threedWidthOverHeight"];
    filamentDiameter = [d doubleForKey:@"threedFilamentDiameter"];
    hotFilamentLength = [d doubleForKey:@"threedHotFilamentLength"];
    lights[0].position[0] = [d floatForKey:@"threedLight1XDir"];
    lights[0].position[1] = [d floatForKey:@"threedLight1YDir"];
    lights[0].position[2] = [d floatForKey:@"threedLight1ZDir"];
    lights[0].position[3] = 0;
    lights[1].position[0] = [d floatForKey:@"threedLight2XDir"];
    lights[1].position[1] = [d floatForKey:@"threedLight2YDir"];
    lights[1].position[2] = [d floatForKey:@"threedLight2ZDir"];
    lights[1].position[3] = 0;
    lights[2].position[0] = [d floatForKey:@"threedLight3XDir"];
    lights[2].position[1] = [d floatForKey:@"threedLight3YDir"];
    lights[2].position[2] = [d floatForKey:@"threedLight3ZDir"];
    lights[2].position[3] = 0;
    lights[3].position[0] = [d floatForKey:@"threedLight4XDir"];
    lights[3].position[1] = [d floatForKey:@"threedLight4YDir"];
    lights[3].position[2] = [d floatForKey:@"threedLight4ZDir"];
    lights[3].position[3] = 0;
    lights[0].enabled = [d boolForKey:@"threedLight1Enabled"];
    lights[1].enabled = [d boolForKey:@"threedLight2Enabled"];
    lights[2].enabled = [d boolForKey:@"threedLight3Enabled"];
    lights[3].enabled = [d boolForKey:@"threedLight4Enabled"];

    [app->openGLView redraw];
}
@end

ThreeDConfig *conf3d;