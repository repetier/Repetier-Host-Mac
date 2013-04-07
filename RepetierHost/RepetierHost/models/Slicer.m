/*
 Copyright 2011 repetier repetierdev@gmail.com
 
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


#import "Slicer.h"
#import "RHAppDelegate.h"
#import "STL.h"
#import "PrinterConfiguration.h"
#import "RHAppDelegate.h"
#import "GCodeEditorController.h"
#import "StringUtil.h"
#import "RHLogger.h"
#import "../controller/RHSlicer.h"
#import "../controller/STLComposer.h"

@implementation Slicer

-(id)init {
    if((self=[super init])) {
        skeinforgeRun = skeinforgeSlice = nil;
        slic3rIntRun = slic3rIntSlice = nil;
        slic3rExtRun = slic3rExtSlice = nil;
        profileConfig = nil;
        exportConfig = nil;
        extrusionConfig = nil;
        multiplyConfig = nil;
        postprocess = nil;
        skipError = NO;
        slic3rInternalPath = [[[[NSBundle mainBundle] pathForResource:@"Slic3r" ofType:@"app"] stringByAppendingString:@"/Contents/MacOS/slic3r"] retain];
        emptyPath = [[[NSBundle mainBundle] pathForResource:@"empty" ofType:@"txt"] retain];
        //NSLog(@"Slic3r path:%@",slic3rInternalPath);
        NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
        //threedFacesColor
        NSArray *arr = [NSArray arrayWithObjects:@"slic3rExternalPath",
                        @"slic3rExternalConfig",@"slic3rInternalBundled",@"activeSlicer",  
                        @"skeinforgeApplication",@"skeinforgeCraft",
                        @"skeinforgePython",nil];
        bindingsArray = arr.retain;
        for(NSString *key in arr)
            [d addObserver:self forKeyPath:key options:NSKeyValueObservingOptionNew context:NULL];
        [[NSNotificationCenter defaultCenter] addObserver:self                                             selector:@selector(taskFinished:) name:@"RHTaskFinished" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(printerChanged:) name:@"RHPrinterChanged" object:nil];
    }
    return self;
}

-(void)dealloc {
    for(NSString *key in bindingsArray)
        [NSUserDefaults.standardUserDefaults removeObserver:self
                                                 forKeyPath:key];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [bindingsArray release];
    if(skeinforgeRun)
        [skeinforgeRun release];
    if(skeinforgeSlice)
        [skeinforgeSlice release];
    if(slic3rIntRun)
        [slic3rIntRun release];
    if(slic3rIntSlice)
        [slic3rIntSlice release];
    if(slic3rExtRun)
        [slic3rExtRun release];
    if(slic3rExtSlice)
        [slic3rIntSlice release];
    [slic3rInternalPath release];
    [emptyPath release];
    [self restoreSkeinforgeConfigs];
    
    [super dealloc];
}
-(void)awakeFromNib
{
    [self checkConfig];
}
+(BOOL)fileExists:(NSString*)fname {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir;
    BOOL exists = [fm fileExistsAtPath:fname isDirectory:&isDir];
    return exists & (!isDir);  
}
-(void)restoreSkeinforgeConfigs
{
    if (profileConfig != nil)
        [profileConfig writeOriginal];
    if (exportConfig != nil)
        [exportConfig writeOriginal ];
    if (extrusionConfig != nil)
        [extrusionConfig writeOriginal];
    if (multiplyConfig != nil)
        [multiplyConfig writeOriginal ];
    profileConfig = nil;
    exportConfig = nil;
    extrusionConfig = nil;
    multiplyConfig = nil;
}
// Checks configuration settings and enables/disables menus if necessary
-(void)checkConfig {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    activeSlicer = currentPrinterConfiguration.activeSlicer;
    BOOL skeinOK = self.skeinforgeConfigured;
    if(activeSlicer==3 && !skeinOK) activeSlicer=1;
    [app->rhslicer.skeinforgeActive setEnabled:skeinOK];
    
    NSString *exe = [d stringForKey:@"slic3rPath"];
    [[NSApplication sharedApplication] deactivate];
    BOOL isDir;
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL fileExists = [fm fileExistsAtPath:exe isDirectory:&isDir];
    fileExists&=!isDir;
    if(!fileExists)
        exe = slic3rInternalPath;
    fileExists = [fm fileExistsAtPath:exe isDirectory:&isDir];
    [app->rhslicer.slic3rActive setEnabled:fileExists];
    
    if(activeSlicer==2)
        activeSlicer=1;
    //[slic3rExtMenu setEnabled:slic3rExt];
    
    [app->rhslicer.slic3rActive setState:activeSlicer!=3];
    [app->rhslicer.skeinforgeActive setState:activeSlicer==3];
    if(activeSlicer==3) {
        NSString *path = [d objectForKey:@"skeinforgeProfiles"];
        if([path rangeOfString:@"sfact"].location!=NSNotFound) {
            [app->rhslicer.runSlice setTitle:@"Slice with SFACT"];
            [app->composer->generateButton setTitle:@"Slice with SFACT"];
        } else {
            [app->rhslicer.runSlice setTitle:@"Slice with Skeinforge"];
            [app->composer->generateButton setTitle:@"Slice with Skeinforge"];
        }

    } else {
        [app->rhslicer.runSlice setTitle:@"Slice with Slic3r"];
        [app->composer->generateButton setTitle:@"Slice with Slic3r"];
    }
    [app->rhslicer updateSelections];
}
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    [self checkConfig];
}
-(void)executePostprocess:(NSString*)file {
    if(currentPrinterConfiguration->enableFilterPrg) {
        NSString *content = [NSString stringWithContentsOfFile:file encoding:NSISOLatin1StringEncoding error:nil];
        NSString *target = [NSString stringWithFormat:@"%@postproc.gcode",rhlog.pathForLogFile];
        [content writeToFile:target atomically:YES encoding:NSISOLatin1StringEncoding error:nil];
        NSMutableArray *arr = [StringUtil explode:currentPrinterConfiguration->filterPrg sep:@" "];
        int i=0;
        if(arr.count<3) {
            [rhlog addError:@"Postprocessing aborted. Postprocessor command need at least 2 parameter #in and #out."];
            [app->gcodeView loadGCode:file];
            [app->rightTabView selectTabViewItem:app->gcodeTab];        
            return;
        }
        [rhlog addInfo:@"Starting postprocessor..."];
        NSString *prg = [arr objectAtIndex:0];
        [arr removeObjectAtIndex:0];
        for(NSString *s in arr) {
            s = [s stringByReplacingOccurrencesOfString:@"#in" withString:target];
            s = [s stringByReplacingOccurrencesOfString:@"#out" withString:file];
            [arr replaceObjectAtIndex:i withObject:s];
            i++;
        }
        postprocess = [[RHTask alloc] initProgram:prg args:arr logPrefix:@"<postproc> "];
    } else {
        [app->gcodeView loadGCodeGCode:file];
        [app->rightTabView selectTabViewItem:app->gcodeTab];        
    }
}
-(void)printerChanged:(NSNotification*)event {
}
-(void)taskFinished:(NSNotification*)event {
    RHTask *t = event.object;
    if(t==postprocess) {
        if(postprocess.finishedSuccessfull) {
            [app->gcodeView loadGCodeGCode:postprocessOut];
            [app->rightTabView selectTabViewItem:app->gcodeTab];        
        } else {
            [app showWarning:@"Postprocessing exited with error!" headline:@"Slicing failed"];
        }
        [postprocess release];
        [postprocessOut release];
        postprocess = nil;
        return;
    }
    if(t==slic3rExtSlice) {
        if(slic3rExtSlice.finishedSuccessfull) {
            [self executePostprocess:slic3rExtOut];
        } else {
            if(!skipError)
                [app showWarning:@"Slicing exited with error!" headline:@"Slicing failed"];
            skipError = NO;
        }
        [slic3rExtOut release];
        [slic3rExtSlice release];
        slic3rExtSlice = nil;
        [app->rhslicer.killButton setEnabled:NO];
    } else if(t==slic3rIntSlice) {
        if(slic3rIntSlice.finishedSuccessfull) {
            [self executePostprocess:slic3rIntOut];
        } else {
            if(!skipError)
                [app showWarning:@"Slicing exited with error!" headline:@"Slicing failed"];
            skipError = NO;
        }
        [slic3rIntOut release];
        [slic3rIntSlice release];
        slic3rIntSlice = nil;
        [app->rhslicer.killButton setEnabled:NO];
    } else if(t==skeinforgeSlice) {
        if(skeinforgeSlice.finishedSuccessfull) {
            if([Slicer fileExists:skeinforgeOut]) {
                [self executePostprocess:skeinforgeOut];
            } else
                [app showWarning:[NSString stringWithFormat:@"Couldn't find sliced file\n%@\nCheck if the Skeinforge naming scheme matches your Skeinforge configuration!",skeinforgeOut] headline:@"File not found"];            
        } else {
            if(!skipError)
                [app showWarning:@"Slicing exited with error!" headline:@"Slicing failed"];
            skipError = NO;
        }
        [skeinforgeOut release];
        [skeinforgeSlice release];
        skeinforgeSlice = nil;
        [self restoreSkeinforgeConfigs];
        [app->rhslicer.killButton setEnabled:NO];
    } else if(t==skeinforgeRun) {
        [skeinforgeRun release];
        skeinforgeRun = nil;
    } else if(t==slic3rExtRun) {
        [slic3rExtRun release];
        slic3rExtRun = nil;
    }
    [app->rhslicer updateSelections];
}
-(void)killSlicing {
    skipError = YES;
    if(skeinforgeSlice!=nil)
        [skeinforgeSlice kill];
    if(slic3rExtSlice!=nil)
        [slic3rExtSlice kill];
    [app->rhslicer.killButton setEnabled:NO];
}

-(BOOL)skeinforgeConfigured {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSString *python = [d stringForKey:@"skeinforgePython"];
    NSString *skein = [d stringForKey:@"skeinforgeApplication"];
    NSString *skein2 = [d stringForKey:@"skeinforgeCraft"];
    BOOL isDir;  
    BOOL fileExists = [fm fileExistsAtPath:python isDirectory:&isDir];
    fileExists&=!isDir;
    fileExists &= [fm fileExistsAtPath:skein isDirectory:&isDir];
    fileExists&=!isDir;
    fileExists &= [fm fileExistsAtPath:skein2 isDirectory:&isDir];
    fileExists&=!isDir;
    return fileExists;
}

- (IBAction)activateSlic3rInternal:(id)sender {
    currentPrinterConfiguration.activeSlicer = 1;
}

- (IBAction)activateSlic3rExternal:(id)sender {
    currentPrinterConfiguration.activeSlicer = 2;
}

- (IBAction)activateSkeinforge:(id)sender {
    currentPrinterConfiguration.activeSlicer = 3;
}
-(IBAction)runSkeinforge:(id)sender {
    if(skeinforgeRun!=nil) {
        if(skeinforgeRun->running) {
            [skeinforgeRun bringToFront];
            return;
        }
        [skeinforgeRun release];
    }
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSString *python = [d stringForKey:@"skeinforgePython"];
    NSString *skein = [d stringForKey:@"skeinforgeApplication"];
    NSArray *arr = [NSArray arrayWithObject:skein];
    [[NSApplication sharedApplication] deactivate];
    skeinforgeRun = [[RHTask alloc] initProgram:python args:arr logPrefix:@"<Skeinforge> "];
}

- (IBAction)configSlic3rInternal:(id)sender {
    [app->slic3r->configWindow makeKeyAndOrderFront:nil];  
}
- (IBAction)configSlic3r:(id)sender {
    if(slic3rExtRun!=nil) {
        if(slic3rExtRun->running) {
            [slic3rExtRun bringToFront];
            return;
        }
        [slic3rExtRun release];
    }
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSString *exe = [d stringForKey:@"slic3rPath"];
    [[NSApplication sharedApplication] deactivate];
    BOOL isDir;
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL fileExists = [fm fileExistsAtPath:exe isDirectory:&isDir];
    fileExists&=!isDir;
    if(!fileExists)
        exe = slic3rInternalPath;
    NSArray *arr;
    int version = [d integerForKey:@"slic3rVersionGroup"];
    if(version == 1)
        arr = [NSArray arrayWithObjects:@"--no-plater",@"--gui-mode",@"expert",nil];
    else
        arr = [NSArray arrayWithObjects:nil];
    slic3rExtRun = [[RHTask alloc] initProgram:exe args:arr logPrefix:@"<Slic3r> "];
}
- (IBAction)configSlic3rExternal:(id)sender {
    if(slic3rExtRun!=nil) {
        if(slic3rExtRun->running) {
            [slic3rExtRun bringToFront];
            return;
        }
        [slic3rExtRun release];
    }
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSString *exe = [d stringForKey:@"slic3rExternalPath"];
    [[NSApplication sharedApplication] deactivate];
    NSString *slic3rConfig = [d stringForKey:@"slic3rExternalConfig"];
    BOOL isDir;  
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL fileExists = [fm fileExistsAtPath:slic3rConfig isDirectory:&isDir];
    fileExists&=!isDir;
    NSArray *arr;
    if(!fileExists) 
        arr = [NSArray arrayWithObjects:nil];
    else
        arr = [NSArray arrayWithObjects:@"--load",slic3rConfig,nil];
    slic3rExtRun = [[RHTask alloc] initProgram:exe args:arr logPrefix:@"<Slic3r> "];
}
-(void)sliceSkeinforge:(NSString*)file {
    if(skeinforgeSlice!=nil) return;
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSString *python = [d stringForKey:@"skeinforgePythonCraft"];
    NSString *skein = [d stringForKey:@"skeinforgeCraft"];
    NSString *sdir = [d stringForKey:@"skeinforgeProfiles"];
    NSString *prof = currentPrinterConfiguration.skeinforgeProfile;
    profileConfig = [[SkeinConfig alloc] initWithPath:[NSString stringWithFormat:@"%@/skeinforge_profile.csv",sdir]];
    extrusionConfig = [[SkeinConfig alloc] initWithPath:[NSString stringWithFormat:@"%@/extrusion.csv",sdir]];
    exportConfig = [[SkeinConfig alloc] initWithPath:[NSString stringWithFormat:@"%@/extrusion/%@/export.csv",sdir,prof]];
    multiplyConfig = [[SkeinConfig alloc] initWithPath:[NSString stringWithFormat:@"%@/extrusion/%@/multiply.csv",sdir,prof]];
    // Set profile to extrusion
    /* cutting	False
     extrusion	True
     milling	False
     winding	False
     */
    [profileConfig setValue:@"False" key:@"cutting"];
    [profileConfig setValue:@"False" key:@"milling"];
    [profileConfig setValue:@"True" key:@"extrusion"];
    [profileConfig setValue:@"False" key:@"winding"];
    [profileConfig writeModified ];
    // Set used profile
    [extrusionConfig setValue:prof key:@"Profile Selection:"];
    [extrusionConfig writeModified];
    // Set export to correct values
    [exportConfig setValue:@"True" key:@"Activate Export"];
    [exportConfig setValue:@"False" key:@"Add Profile Extension"];
    [exportConfig setValue:@"False" key:@"Add Profile Name to Filename"];
    [exportConfig setValue:@"False" key:@"Add Timestamp Extension"];
    [exportConfig setValue:@"False" key:@"Add Timestamp to Filename"];
    [exportConfig setValue:@"False" key:@"Add Description to Filename"];
    [exportConfig setValue:@"False" key:@"Add Descriptive Extension"];
    [exportConfig writeModified];
    
    [multiplyConfig setValue:@"False" key:@"Activate Multiply:"];
    [multiplyConfig setValue:@"False" key:@"Activate Multiply: "];
    [multiplyConfig setValue:@"False" key:@"Activate Multiply"];
    [multiplyConfig writeModified ];
    
    NSArray *arr = [NSArray arrayWithObjects:skein,file,nil];
    NSString *extension = [exportConfig getValue:@"File Extension:"];
    if (extension == nil)
        extension = [exportConfig getValue:@"File Extension (gcode):"];
    if(extension == nil) extension = @"";
    NSString *export = [exportConfig getValue:@"Add Export Suffix"];
    if (export == nil)
        export = [exportConfig getValue:@"Add _export to filename (filename_export)"];
    if (export == nil || [export compare:@"True"]!=NSOrderedSame)
        export = @""; else export = @"_export";
    skeinforgeOut = [[NSString stringWithFormat:@"%@%@.%@",[file stringByDeletingPathExtension],export,extension] retain];
    if([Slicer fileExists:skeinforgeOut]) {
        [[NSFileManager defaultManager] removeItemAtPath:skeinforgeOut error:nil];
    }
    skeinforgeSlice = [[RHTask alloc] initProgram:python args:arr logPrefix:@"<Skeinforge> "];
    [app->rhslicer.killButton setEnabled:YES];
}
-(NSString*)patternName:(NSString*)pat {
    NSRange r = [pat rangeOfString:@" "];
    if(r.location==NSNotFound) return pat;
    return [pat substringToIndex:r.location];
}
-(void)sliceSlic3rInternal:(NSString*)file {
    if(slic3rIntSlice!=nil) {
        if(slic3rIntSlice->running) {
            return;
        }
        [slic3rIntSlice release];
    }
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSString *exe = [d stringForKey:@"slic3rExternalPath"];
    BOOL bundeled = [d boolForKey:@"slic3rInternalBundled"];
    if(bundeled) {
        exe = slic3rInternalPath;
    }
    BOOL isDir;  
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL fileExists = [fm fileExistsAtPath:file isDirectory:&isDir];
    fileExists&=!isDir;
    NSMutableArray *arr;
    if(!fileExists)
        return;
    STL *stl = [[STL alloc] init];
    [stl load:file];
    [stl updateBoundingBox];
    // User assigned valid position, so we use this
    double centerx = stl->xMin + (stl->xMax - stl->xMin) / 2;
    double centery = stl->yMin + (stl->yMax - stl->yMin) / 2;
    [stl release];
    slic3rIntOut = [[[file stringByDeletingPathExtension] stringByAppendingString:@".gcode"] retain];
    if([Slicer fileExists:slic3rIntOut]) {
        [[NSFileManager defaultManager] removeItemAtPath:slic3rIntOut error:nil];
    }
    arr = [NSMutableArray arrayWithObjects:@"--print-center",
           [NSString stringWithFormat:@"%d,%d",(int)centerx,(int)centery],nil];
    Slic3rSettings *s = app->slic3r->current;
    [arr addObject:@"--nozzle-diameter"];
    [arr addObject:[s getString:@"nozzleDiameter"]];
    if ([s getBool:@"useRealtiveE"])
        [arr addObject:@"--use-relative-e-distances"];
    if ([s getBool:@"comments"])
        [arr addObject:@"--gcode-comments"];
    [arr addObject:@"-j"];
    [arr addObject:[s getString:@"threads"]];
    if ([s getBool:@"randomizeStartingPoint"])
        [arr addObject:@"--randomize-start"];
    [arr addObject:@"--z-offset"];
    [arr addObject:[s getString:@"zOffset"]];
    [arr addObject:@"--filament-diameter"];
    [arr addObject:[s getString:@"filamentDiameter"]];
    [arr addObject:@"--extrusion-multiplier"];
    [arr addObject:[s getString:@"extrusionMultiplier"]];
    [arr addObject:@"--temperature"];
    [arr addObject:[s getString:@"temperature"]];
    [arr addObject:@"--infill-speed"];
    [arr addObject:[s getString:@"infillSpeed"]];
    [arr addObject:@"--solid-infill-speed"];
    [arr addObject:[s getString:@"solidInfillSpeed"]];
    [arr addObject:@"--travel-speed"];
    [arr addObject:[s getString:@"travelSpeed"]];
    [arr addObject:@"--bridge-speed"];
    [arr addObject:[s getString:@"bridgesSpeed"]];
    [arr addObject:@"--perimeter-speed" ];
    [arr addObject:[s getString:@"perimeterSpeed"]];
    [arr addObject:@"--small-perimeter-speed"];
    [arr addObject:[s getString:@"smallPerimeterSpeed"]];
    [arr addObject:@"--first-layer-speed"];
    [arr addObject:[s getString:@"firstLayerSpeed"]];
    [arr addObject:@"--bridge-flow-ratio"];
    [arr addObject:[s getString:@"bridgeFlowRatio"]];
    [arr addObject:@"--layer-height"];
    [arr addObject:[s getString:@"layerHeight"]];
    [arr addObject:@"--first-layer-height"];
    [arr addObject:[s getString:@"firstLayerHeight"]];
    [arr addObject:@"--infill-every-layers"];
    [arr addObject:[s getString:@"infillEveryNLayers"]];
    [arr addObject:@"--perimeters"];
    [arr addObject:[s getString:@"perimeters"]];
    [arr addObject:@"--solid-layers"];
    [arr addObject:[s getString:@"solidLayers"]];
    [arr addObject:@"--fill-density"];
    [arr addObject:[s getString:@"fillDensity"]];
    [arr addObject:@"--fill-angle"];
    [arr addObject:[s getString:@"fillAngle"]];
    [arr addObject:@"--fill-pattern"];
    [arr addObject:[self patternName:[s getString:@"fillPattern"]]];
    [arr addObject:@"--solid-fill-pattern"];
    [arr addObject:[self patternName:[s getString:@"solidFillPattern"]]];
    [arr addObject:@"--retract-length"];
    [arr addObject:[s getString:@"retractLength"]];
    [arr addObject:@"--retract-speed"];
    [arr addObject:[s getString:@"retractSpeed"]];
    [arr addObject:@"--retract-restart-extra"];
    [arr addObject:[s getString:@"retractExtraLength"]];
    [arr addObject:@"--retract-before-travel"];
    [arr addObject:[s getString:@"retractMinTravel"]];
    [arr addObject:@"--retract-lift"];
    [arr addObject:[s getString:@"retractZLift"]];
    [arr addObject:@"--skirts"];
    [arr addObject:[s getString:@"skirtLoops"]];
    [arr addObject:@"--skirt-distance"];
    [arr addObject:[s getString:@"skirtDistance"]];
    [arr addObject:@"--skirt-height"];
    [arr addObject:[s getString:@"skirtHeight"]];
    [arr addObject:@"--extrusion-width"];
    [arr addObject:[s getString:@"extrusionWidth"]];
    if ([s getBool:@"coolEnable"])
    {
        [arr addObject:@"--cooling"];
        [arr addObject:@"--bridge-fan-speed"];
        [arr addObject:[s getString:@"coolBridgeFanSpeed"]];
        [arr addObject:@"--disable-fan-first-layers"];
        [arr addObject:[s getString:@"coolDisplayLayer"]];
        [arr addObject:@"--fan-below-layer-time"];
        [arr addObject:[s getString:@"coolEnableBelow"]];
        [arr addObject:@"--max-fan-speed"];
        [arr addObject:[s getString:@"coolMaxFanSpeed"]];
        [arr addObject:@"--min-fan-speed"];
        [arr addObject:[s getString:@"coolMinFanSpeed"]];
        [arr addObject:@"--min-print-speed"];
        [arr addObject:[s getString:@"coolMinPrintSpeed"]];
        [arr addObject:@"--slowdown-below-layer-time"];
        [arr addObject:[s getString:@"coolSlowDownBelow"]];
    }
    if ([s getBool:@"generateSupportMaterial"])
    {
        [arr addObject:@"--support-material"];
        [arr addObject:@"--support-material-tool"];
        NSString *t = [s getString:@"supportMaterialTool"];
        if([t compare:@"Secondary"]==NSOrderedSame) {
            [arr addObject:@"1"];
        } else {
            [arr addObject:@"0"];            
        }
    }
    [arr addObject:@"--gcode-flavor"];
    NSString *t = [s getString:@"GCodeFlavor"];
    if([t compare:@"Teacup"])
        [arr addObject:@"teacup"];
    else if([t compare:@"MakerBot"])
        [arr addObject:@"makerbot"];
    else if([t compare:@"Mach3/EMC"])
        [arr addObject:@"mach3"];
    else if([t compare:@"No extrusion"])
        [arr addObject:@"no-extrusion"];
    else 
        [arr addObject:@"reprap"];
    [arr addObject:@"--first-layer-temperature"];
    [arr addObject:[s getString:@"firstLayerTemperature"]];
    [arr addObject:@"--bed-temperature"];
    [arr addObject:[s getString:@"bedtemperature"]];
    [arr addObject:@"--first-layer-bed-temperature"];
    [arr addObject:[s getString:@"firstLayerBedTemperature"]];
    if ([s getBool:@"keepFanAlwaysOn"])
    {
        [arr addObject:@"--fan-always-on"];
    }
    [arr addObject:@"--start-gcode"];
    [arr addObject:emptyPath];
    [arr addObject:@"--end-gcode"];
    [arr addObject:emptyPath];
    [arr addObject:@"-o"];
    [arr addObject:slic3rIntOut];
    [arr addObject:file];
    NSLog(@"Call %@ %@",exe,[StringUtil implode:arr sep:@" "]);
    slic3rIntSlice = [[RHTask alloc] initProgram:exe args:arr logPrefix:@"<Slic3r> "];    
}
-(void)sliceSlic3rExternal:(NSString*)file {
    if(slic3rExtSlice!=nil) {
        if(slic3rExtSlice->running) {
            return;
        }
        [slic3rExtSlice release];
    }
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSString *exe = [d stringForKey:@"slic3rExternalPath"];
    NSString *slic3rConfig = [d stringForKey:@"slic3rExternalConfig"];
    BOOL isDir;  
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL fileExists = [fm fileExistsAtPath:slic3rConfig isDirectory:&isDir];
    fileExists&=!isDir;
    NSArray *arr;
    if(!fileExists)
        return;
    STL *stl = [[STL alloc] init];
    [stl load:file];
    [stl updateBoundingBox];
        // User assigned valid position, so we use this
    double centerx = stl->xMin + (stl->xMax - stl->xMin) / 2;
    double centery = stl->yMin + (stl->yMax - stl->yMin) / 2;
    [stl release];
    slic3rExtOut = [[[file stringByDeletingPathExtension] stringByAppendingString:@".gcode"] retain];
    if([Slicer fileExists:slic3rExtOut]) {
        [[NSFileManager defaultManager] removeItemAtPath:slic3rExtOut error:nil];
    }
    arr = [NSArray arrayWithObjects:@"--load",slic3rConfig,@"--print-center",
           [NSString stringWithFormat:@"%d,%d",(int)centerx,(int)centery],@"-o",slic3rExtOut,file,nil];
    slic3rExtSlice = [[RHTask alloc] initProgram:exe args:arr logPrefix:@"<Slic3r> "];    
}
/** Build Slic3r configuration file, store stl file and start Slic3r */
-(void)sliceSlic3r:(NSString*)file {
    if(slic3rExtSlice!=nil) {
        if(slic3rExtSlice->running) {
            return;
        }
        [slic3rExtSlice release];
    }
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSString *exe = [d stringForKey:@"slic3rPath"];

    [[NSApplication sharedApplication] deactivate];
    BOOL isDir;
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL fileExists = [fm fileExistsAtPath:exe isDirectory:&isDir];
    fileExists&=!isDir;
    if(!fileExists)
        exe = slic3rInternalPath;

    NSArray *arr;
    
    NSString *sFilament = currentPrinterConfiguration.slic3rFilament1;
    NSString *sFilament2 = currentPrinterConfiguration.slic3rFilament2;
    NSString *sFilament3 = currentPrinterConfiguration.slic3rFilament3;
    NSString *sPrint = currentPrinterConfiguration.slic3rPrint;
    NSString *sPrinter = currentPrinterConfiguration.slic3rPrinter;

    NSString *dir = @"~/Library/Repetier";
    dir = [dir stringByExpandingTildeInPath];
    NSString *config = [NSString stringWithFormat:@"%@/slic3r.ini",dir];
    NSString *cdir = [RHSlicer slic3rConfigDir];
    IniFile *ini = [[[IniFile alloc] init] autorelease];
    NSString *fPrinter = [NSString stringWithFormat:@"%@/print/%@.ini",cdir,sPrint];
    [ini read:fPrinter];
    IniFile *ini2 = [[[IniFile alloc] init] autorelease];
    [ini2 read:[NSString stringWithFormat:@"%@/printer/%@.ini",cdir,sPrinter]];
    IniFile *ini3 = [[[IniFile alloc] init] autorelease];
    [ini3 read:[NSString stringWithFormat:@"%@/filament/%@.ini",cdir,sFilament]];
    IniFile *ini3_2 = nil;
    if(currentPrinterConfiguration->numberOfExtruder>1) {
        ini3_2 = [[[IniFile alloc] init] autorelease];
        [ini3_2 read:[NSString stringWithFormat:@"%@/filament/%@.ini",cdir,sFilament2]];
        [ini3 merge:ini3_2];
    }
    IniFile *ini3_3 = nil;
    if(currentPrinterConfiguration->numberOfExtruder>2) {
        ini3_3 = [[[IniFile alloc] init] autorelease];
        [ini3_3 read:[NSString stringWithFormat:@"%@/filament/%@.ini",cdir,sFilament3]];
        [ini3 merge:ini3_3];
    }
    [ini add:ini2];
    [ini add:ini3 ];
    [ini flatten];
    [ini write:config];
    
    STL *stl = [[STL alloc] init];
    [stl load:file];
    [stl updateBoundingBox];
    // User assigned valid position, so we use this
    double centerx = stl->xMin + (stl->xMax - stl->xMin) / 2;
    double centery = stl->yMin + (stl->yMax - stl->yMin) / 2;
    [stl release];
    slic3rExtOut = [[[file stringByDeletingPathExtension] stringByAppendingString:@".gcode"] retain];
    if([Slicer fileExists:slic3rExtOut]) {
        [[NSFileManager defaultManager] removeItemAtPath:slic3rExtOut error:nil];
    }
    arr = [NSArray arrayWithObjects:@"--load",config,@"--print-center",
           [NSString stringWithFormat:@"%d,%d",(int)centerx,(int)centery],@"-o",slic3rExtOut,file,nil];
    slic3rExtSlice = [[RHTask alloc] initProgram:exe args:arr logPrefix:@"<Slic3r> "];
    [app->rhslicer.killButton setEnabled:YES];
}
-(void)slice:(NSString*)file {
    switch(activeSlicer) {
        case 1:
        case 2:
            [self sliceSlic3r:file];
            break;
        case 3:
            [self sliceSkeinforge:file];
            break;
    }
}
@end
