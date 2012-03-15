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

#import <Cocoa/Cocoa.h>
#import "PrinterConfiguration.h"
#import "PrinterConnection.h"
#import "IntegerTransformer.h"
#import "ThreeDConfig.h"
#import "RHLogger.h"
#import "DefaultsExtension.h"

int main(int argc, char *argv[])
{
    // Set default values
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    [d setObject:[NSNumber numberWithInt:1] forKey:@"threedFilamentVisualization"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor redColor]] forKey:@"threedFacesColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor magentaColor]] forKey:@"threedSelectedFacesColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor purpleColor]] forKey:@"threedEdgesColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor yellowColor]] forKey:@"threedSelectedEdgesColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor blueColor]] forKey:@"threedFilamentColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor redColor]] forKey:@"threedHotFilamentColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor blackColor]] forKey:@"threedBackgroundColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor whiteColor]] forKey:@"threedPrinterColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor whiteColor]] forKey:@"threedPrinterBottomColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor blackColor]] forKey:@"threedLight1AmbientColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor blackColor]] forKey:@"threedLight2AmbientColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor blackColor]] forKey:@"threedLight3AmbientColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor blackColor]] forKey:@"threedLight4AmbientColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.7 green:0.7 blue:0.7 alpha:1]] forKey:@"threedLight1DiffuseColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.7 green:0.7 blue:0.7 alpha:1]] forKey:@"threedLight2DiffuseColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.7 green:0.7 blue:0.7 alpha:1]] forKey:@"threedLight3DiffuseColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.7 green:0.7 blue:0.7 alpha:1]] forKey:@"threedLight4DiffuseColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.7 green:0.7 blue:0.7 alpha:1]] forKey:@"threedLight1SpecularColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.7 green:0.7 blue:0.7 alpha:1]] forKey:@"threedLight2SpecularColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.7 green:0.7 blue:0.7 alpha:1]] forKey:@"threedLight3SpecularColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.7 green:0.7 blue:0.7 alpha:1]] forKey:@"threedLight4SpecularColor"];
    [d setObject:[NSNumber numberWithDouble:30] forKey:@"threedBottomTransparency"];
    [d setObject:[NSNumber numberWithDouble:1000] forKey:@"threedHotFilamentLength"];
    [d setObject:[NSNumber numberWithDouble:-1] forKey:@"threedLight1XDir"];
    [d setObject:[NSNumber numberWithDouble:-2] forKey:@"threedLight1YDir"];
    [d setObject:[NSNumber numberWithDouble:2] forKey:@"threedLight1ZDir"];
    [d setObject:[NSNumber numberWithDouble:1] forKey:@"threedLight2XDir"];
    [d setObject:[NSNumber numberWithDouble:2] forKey:@"threedLight2YDir"];
    [d setObject:[NSNumber numberWithDouble:3] forKey:@"threedLight2ZDir"];
    [d setObject:[NSNumber numberWithDouble:1] forKey:@"threedLight3XDir"];
    [d setObject:[NSNumber numberWithDouble:-2] forKey:@"threedLight3YDir"];
    [d setObject:[NSNumber numberWithDouble:2] forKey:@"threedLight3ZDir"];
    [d setObject:[NSNumber numberWithDouble:1.7] forKey:@"threedLight4XDir"];
    [d setObject:[NSNumber numberWithDouble:-1] forKey:@"threedLight4YDir"];
    [d setObject:[NSNumber numberWithDouble:-2.5] forKey:@"threedLight4ZDir"];
    [d setObject:[NSNumber numberWithInt:1] forKey:@"threedLight1Enabled"];
    [d setObject:[NSNumber numberWithInt:1] forKey:@"threedLight2Enabled"];
    [d setObject:[NSNumber numberWithInt:0] forKey:@"threedLight3Enabled"];
    [d setObject:[NSNumber numberWithInt:0] forKey:@"threedLight4Enabled"];
    [d setObject:[NSNumber numberWithInt:1] forKey:@"threedShowPrintbed"];
    [d setObject:[NSNumber numberWithInt:0] forKey:@"threedAccelerationMethod"];
    [d setObject:[NSNumber numberWithInt:0] forKey:@"threedDrawEdges"];
    [d setObject:[NSNumber numberWithInt:0] forKey:@"threedHeightMethod"];
    [d setObject:[NSNumber numberWithDouble:0.38] forKey:@"threedLayerHeight"];
    [d setObject:[NSNumber numberWithDouble:1.6] forKey:@"threedWidthOverHeight"];
    [d setObject:[NSNumber numberWithDouble:2.87] forKey:@"threedFilamentDiameter"];
    [d setObject:[NSNumber numberWithInt:0] forKey:@"disableFilamentVisualization"];
    // Skeinforge defaults
    [d setObject:@"" forKey:@"skeinforgeApplication"];
    [d setObject:@"" forKey:@"skeinforgeCraft"];
    [d setObject:@"/usr/bin/pythonw" forKey:@"skeinforgePython"];
    [d setObject:@".gcode" forKey:@"skeinforgeExtension"];
    [d setObject:@"_export" forKey:@"skeinforgePostfix"];
        
    //Slic3r defaults
    [d setObject:@"" forKey:@"slic3rExternalPath"];
    [d setObject:@"" forKey:@"slic3rExternalConfig"];
    [d setObject:[NSNumber numberWithBool:YES] forKey:@"slic3rInternalBundled"];
    [d setObject:[NSNumber numberWithInt:1] forKey:@"activeSlicer"];

    // Editor colors
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0 green:0 blue:0.5 alpha:1]] forKey:@"editorCommandColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.5 green:0 blue:0 alpha:1]] forKey:@"editorParameterIndicatorColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0 green:0 blue:0 alpha:1]] forKey:@"editorParameterValueColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.42 green:0.556 blue:0.176 alpha:1]] forKey:@"editorCommentColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.18 green:0.55 blue:0.34 alpha:1]] forKey:@"editorHostCommandColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor whiteColor]] forKey:@"editorSelectedTextColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.125 green:0.698 blue:0.667 alpha:1]] forKey:@"editorSelectedBackgroundColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor whiteColor]] forKey:@"editorLineTextColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.372 green:0.62 blue:0.627 alpha:1]] forKey:@"editorLineBackgroundColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor whiteColor]] forKey:@"editorBackgroundOddColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.98 green:0.94 blue:0.9 alpha:1]] forKey:@"editorBackgroundEvenColor"];
    // Temp monitor colors
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0 green:0 blue:0 alpha:1]] forKey:@"tempBackgroundColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0 green:0.275 blue:0 alpha:1]] forKey:@"tempGridColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:1 green:1 blue:1 alpha:1]] forKey:@"tempAxisColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.9 green:0.9 blue:0.9 alpha:1]] forKey:@"tempFontColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:1 green:0.01 blue:0.24 alpha:1]] forKey:@"tempExtruderColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.874 green:0.45 blue:0.043 alpha:0.7]] forKey:@"tempAvgExtruderColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0 green:0.81 blue:0.82 alpha:1]] forKey:@"tempBedColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0 green:0.48 blue:0.65 alpha:0.7]] forKey:@"tempAvgBedColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.6 green:0.4 blue:0.8 alpha:1]] forKey:@"tempTargetExtruderColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.6 green:0.4 blue:0.8 alpha:1]] forKey:@"tempTargetBedColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0 green:0.5 blue:1 alpha:1]] forKey:@"tempAvgOutputColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.05 green:0.5 blue:0.06 alpha:0.7]] forKey:@"tempOutputColor"];
    [d setObject:[NSNumber numberWithInt:3] forKey:@"tempAverageSeconds"];
    [d setObject:[NSNumber numberWithInt:3] forKey:@"tempZoomLevel"];
    [d setObject:[NSNumber numberWithBool:YES] forKey:@"tempShowExtruder"];
    [d setObject:[NSNumber numberWithBool:YES] forKey:@"tempShowAverage"];
    [d setObject:[NSNumber numberWithBool:YES] forKey:@"tempShowBed"];
    [d setObject:[NSNumber numberWithBool:YES] forKey:@"tempAutoscroll"];
    [d setObject:[NSNumber numberWithBool:NO] forKey:@"tempShowOutput"];
    [d setObject:[NSNumber numberWithBool:YES] forKey:@"tempShowTarget"];
    [d setObject:[NSNumber numberWithDouble:2] forKey:@"tempExtruderWidth"];
    [d setObject:[NSNumber numberWithDouble:7] forKey:@"tempAvgExtruderWidth"];
    [d setObject:[NSNumber numberWithDouble:1] forKey:@"tempTargetExtruderWidth"];
    [d setObject:[NSNumber numberWithDouble:2] forKey:@"tempBedWidth"];
    [d setObject:[NSNumber numberWithDouble:7] forKey:@"tempAvgBedWidth"];
    [d setObject:[NSNumber numberWithDouble:1] forKey:@"tempTargetBedWidth"];
    [d setObject:[NSNumber numberWithDouble:2] forKey:@"tempAvgOutputWidth"];
    // Logs
    [d setObject:[NSNumber numberWithBool:NO] forKey:@"log.sendEnabled"];
    [d setObject:[NSNumber numberWithBool:YES] forKey:@"log.infoEnabled"];
    [d setObject:[NSNumber numberWithBool:YES] forKey:@"log.warningsEnabled"];
    [d setObject:[NSNumber numberWithBool:YES] forKey:@"log.errorsEnabled"];
    [d setObject:[NSNumber numberWithBool:NO] forKey:@"logs.ackEnabled"];
    [d setObject:[NSNumber numberWithBool:YES] forKey:@"logs.autoscrollEnabled"];
    [d setObject:[NSNumber numberWithBool:YES] forKey:@"logsWriteToFile"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0 green:0 blue:0 alpha:1]] forKey:@"logDefaultColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.054 green:0.133 blue:0.576 alpha:1]] forKey:@"logInformationColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.65 green:0.47 blue:0 alpha:1]] forKey:@"logWarningColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.733 green:0.067 blue:0.106 alpha:1]] forKey:@"logErrorColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor whiteColor]] forKey:@"logSelectedTextColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.125 green:0.698 blue:0.667 alpha:1]] forKey:@"logSelectedBackgroundColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor whiteColor]] forKey:@"logLineTextColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.372 green:0.62 blue:0.627 alpha:1]] forKey:@"logLineBackgroundColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor whiteColor]] forKey:@"logBackgroundOddColor"];
    [d setObject:(NSData*)[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.98 green:0.94 blue:0.9 alpha:1]] forKey:@"logBackgroundEvenColor"];

    // Slic3r default
    [d setObject:@"Default" forKey:@"slic3rCurrent"];
    [d setObject:@"Default" forKey:@"slic3rConfigs"]; // Tab seperated list
    [d setObject:[NSNumber numberWithDouble:0.5] forKey:@"slic3r#Default#nozzleDiameter"];
    [d setObject:[NSNumber numberWithBool:NO] forKey:@"slic3r#Default#useRealtiveE"];
    [d setObject:[NSNumber numberWithDouble:0] forKey:@"slic3r#Default#zOffset"];
    [d setObject:[NSNumber numberWithDouble:3] forKey:@"slic3r#Default#filamentDiameter"];
    [d setObject:[NSNumber numberWithDouble:1] forKey:@"slic3r#Default#extrusionMultiplier"];
    [d setObject:[NSNumber numberWithInt:200] forKey:@"slic3r#Default#temperature"];
    [d setObject:[NSNumber numberWithDouble:30] forKey:@"slic3r#Default#perimeterSpeed"];
    [d setObject:[NSNumber numberWithDouble:30] forKey:@"slic3r#Default#smallPerimeterSpeed"];
    [d setObject:[NSNumber numberWithDouble:60] forKey:@"slic3r#Default#infillSpeed"];
    [d setObject:[NSNumber numberWithDouble:60] forKey:@"slic3r#Default#solidInfillSpeed"];
    [d setObject:[NSNumber numberWithDouble:60] forKey:@"slic3r#Default#bridgesSpeed"];
    [d setObject:[NSNumber numberWithDouble:130] forKey:@"slic3r#Default#travelSpeed"];
    [d setObject:[NSNumber numberWithDouble:0.3] forKey:@"slic3r#Default#bottomLayerSpeedRatio"];
    [d setObject:[NSNumber numberWithDouble:0.4] forKey:@"slic3r#Default#layerHeight"];
    [d setObject:[NSNumber numberWithDouble:1] forKey:@"slic3r#Default#firstLayerHeightRatio"];
    [d setObject:[NSNumber numberWithDouble:1] forKey:@"slic3r#Default#infillEveryNLayers"];
    [d setObject:[NSNumber numberWithInt:1] forKey:@"slic3r#Default#skirtLoops"];
    [d setObject:[NSNumber numberWithDouble:6] forKey:@"slic3r#Default#skirtDistance"];
    [d setObject:[NSNumber numberWithInt:1] forKey:@"slic3r#Default#skirtHeight"];
    [d setObject:[NSNumber numberWithInt:3] forKey:@"slic3r#Default#perimeters"];
    [d setObject:[NSNumber numberWithInt:3] forKey:@"slic3r#Default#solidLayers"];
    [d setObject:[NSNumber numberWithDouble:0.4] forKey:@"slic3r#Default#fillDensity"];
    [d setObject:[NSNumber numberWithDouble:45] forKey:@"slic3r#Default#fillAngle"];
    [d setObject:[NSNumber numberWithDouble:3] forKey:@"slic3r#Default#retractLength"];
    [d setObject:[NSNumber numberWithDouble:0] forKey:@"slic3r#Default#retractZLift"];
    [d setObject:[NSNumber numberWithDouble:30] forKey:@"slic3r#Default#retractSpeed"];
    [d setObject:[NSNumber numberWithDouble:0] forKey:@"slic3r#Default#retractExtraLength"];
    [d setObject:[NSNumber numberWithDouble:2] forKey:@"slic3r#Default#retractMinTravel"];
    [d setObject:[NSNumber numberWithDouble:0] forKey:@"slic3r#Default#extrusionWidth"];
    [d setObject:[NSNumber numberWithDouble:1] forKey:@"slic3r#Default#bridgeFlowRatio"];
    [d setObject:@"rectilinear" forKey:@"slic3r#Default#fillPattern"];
    [d setObject:@"rectilinear" forKey:@"slic3r#Default#solidFillPattern"];
    [d setObject:[NSNumber numberWithBool:NO] forKey:@"slic3r#Default#comments"];
    [d setObject:[NSNumber numberWithInt:100] forKey:@"slic3r#Default#coolBridgeFanSpeed"];
    [d setObject:[NSNumber numberWithInt:1] forKey:@"slic3r#Default#coolDisplayLayer"];
    [d setObject:[NSNumber numberWithInt:60] forKey:@"slic3r#Default#coolEnableBelow"];
    [d setObject:[NSNumber numberWithInt:100] forKey:@"slic3r#Default#coolMaxFanSpeed"];
    [d setObject:[NSNumber numberWithInt:35] forKey:@"slic3r#Default#coolMinFanSpeed"];
    [d setObject:[NSNumber numberWithInt:10] forKey:@"slic3r#Default#coolMinPrintSpeed"];
    [d setObject:[NSNumber numberWithInt:15] forKey:@"slic3r#Default#coolSlowDownBelow"];
    [d setObject:@"RepRap (Repetier/Marlin/Sprinter)" forKey:@"slic3r#Default#GCodeFlavor"];
    [d setObject:@"Primary" forKey:@"slic3r#Default#supportMaterialTool"];
    [d setObject:[NSNumber numberWithInt:200] forKey:@"slic3r#Default#firstLayerTemperature"];
    [d setObject:[NSNumber numberWithBool:NO] forKey:@"slic3r#Default#coolEnable"];
    [d setObject:[NSNumber numberWithBool:NO] forKey:@"slic3r#Default#generateSupportMaterial"];
    [d setObject:[NSNumber numberWithBool:NO] forKey:@"slic3r#Default#keepFanAlwaysOn"];
    [d setObject:[NSNumber numberWithInt:0] forKey:@"slic3r#Default#bedtemperature"];
    [d setObject:[NSNumber numberWithInt:0] forKey:@"slic3r#Default#firstLayerBedTemperature"];
    // Other data
    [d setObject:[NSNumber numberWithDouble:60] forKey:@"extruder.Speed"];
    [d setObject:[NSNumber numberWithDouble:10] forKey:@"extruder.extrudeLength"];
    [d setObject:[NSNumber numberWithDouble:3] forKey:@"extruder.retract"];
    [d setObject:[NSNumber numberWithBool:YES] forKey:@"showFirstSteps"];
    [d setObject:[NSNumber numberWithFloat:170] forKey:@"logSplitterHeight"];
    [d setObject:[NSNumber numberWithFloat:516] forKey:@"editorSplitterWidth"];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:d];

    connection = nil;
    [PrinterConfiguration initPrinter];
    conf3d = [ThreeDConfig new];
    //rhlog = [[RHLogger alloc] init];
    connection = [[PrinterConnection alloc] init];
    [pool release];
    return NSApplicationMain(argc, (const char **)argv);
}
