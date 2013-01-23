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

#import "GCodeAnalyzer.h"
#import "PrinterConfiguration.h"
#import "RHAppDelegate.h"
#import "RHFileHistory.h"
#import "ThreadedNotification.h"
#import "PrinterConnection.h"
#import "RHLogger.h"

@implementation GCodeAnalyzer


-(id)init {
    if((self=[super init])) {
        delegate = nil;
        activeExtruder = 0;
        extruderTemp=[NSMutableDictionary new];
        uploading = NO;
        bedTemp = 0;
        x = y = z = e = emax = 0;
        f = 1000;
        lastX = lastY = lastZ = lastE = 0;
        xOffset = yOffset = zOffset = eOffset = 0;
        fanOn = NO;
        fanVoltage = 0;
        powerOn = YES;
        relative = NO;
        eRelative = NO;
        debugLevel = 6;
        lastline = 0;
        lastZPrint = 0;
        printingTime = 0;
        layer=0;
        hasXHome = hasYHome = hasZHome = NO;
        privateAnalyzer = NO;
        tempMonitor = -1;
        drawing = YES;
    }
    return self;
}
-(void)dealloc {
    [extruderTemp release];
    [super dealloc];
}
-(void)fireChanged {
    if(privateAnalyzer) return;
    [ThreadedNotification notifyASAP:@"RHPrinterStateChanged" object:self];
    [delegate printerStateChanged:self];
}
-(void) start {
    [extruderTemp removeAllObjects];
    relative = NO;
    eRelative = NO;
    activeExtruder = 0;
    bedTemp = 0;
    layer = 0;
    fanOn = NO;
    powerOn = YES;
    drawing = YES;
    fanVoltage = 0;
    lastline = 0;
    lastZPrint = 0;
    printingTime = 0;
    tempMonitor = -1;
    x = y = z = e = emax = 0;
    f = 1000;
    lastX = lastY = lastZ = lastE = 0;
    xOffset = yOffset = zOffset = eOffset = 0;
    hasXHome = hasYHome = hasZHome = NO;
    printerWidth = currentPrinterConfiguration->width;
    printerDepth = currentPrinterConfiguration->depth;
    printerHeight = currentPrinterConfiguration->height;
    [self fireChanged];
}
-(void) startJob {
    layer = 0;
    drawing = YES;
    lastline = 0;
    lastZPrint = 0;
    printingTime = 0;
    x = y = z = e = emax = 0;
    lastX = lastY = lastZ = lastE = 0;
    xOffset = yOffset = zOffset = eOffset = 0;
}
-(float)getExtruderTemperature:(int)extruder {
    if(extruder<0) extruder = activeExtruder;
    NSNumber *en = [NSNumber numberWithInt:extruder];
    id res = [extruderTemp objectForKey:en];
    if(res==nil) return 0;
    return ((NSNumber*)res).floatValue;
}
-(void)setExtruder:(int)extruder temperature:(float)temp {
    if(extruder<0) extruder = activeExtruder;
    NSNumber *en = [NSNumber numberWithInt:extruder];
    NSNumber *etemp = [NSNumber numberWithFloat:temp];
    [extruderTemp setObject:etemp forKey:en];
}
-(void) analyze:(GCode*) code
{
    isG1Move = false;
    if (code->hostCommand)
    {
        NSString *hc = code.hostCommand;
        if ([hc compare:@"@hide"]==NSOrderedSame)
            drawing = NO;
        else if ([hc compare:@"@show"]==NSOrderedSame)
            drawing = YES;
        else if ([hc compare:@"@isathome"]==NSOrderedSame)
        {
            hasXHome = hasYHome = hasZHome = YES;
            x = (currentPrinterConfiguration->homeXMax?currentPrinterConfiguration->xMax:currentPrinterConfiguration->xMin);
            xOffset = 0;
            y = (currentPrinterConfiguration->homeYMax?currentPrinterConfiguration->yMax:currentPrinterConfiguration->yMin);
            yOffset = 0;
            z = (currentPrinterConfiguration->homeZMax?currentPrinterConfiguration->height:0);
            zOffset = 0;
        } 
        return;
    }
    actCode = code;
    if (code.hasN)
        lastline = code.getN;
    if (uploading && !code.hasM && code.getM != 29) return; // ignore upload commands
    if (code.hasG)
    {
        switch (code.getG)
        {
            case 0:
            case 1:
                isG1Move = YES;
                eChanged = NO;
                if(code.hasF) f = code.getF;
                if (relative)
                {
                    if(code.hasX) x += code.getX;
                    if(code.hasY) y += code.getY;
                    if(code.hasZ) z += code.getZ;
                    if(code.hasE) {
                        eChanged = code->e!=0;
                        e += code.getE;
                    }
                }
                else
                {
                    if (code.hasX) x = xOffset+code.getX;
                    if (code.hasY) y = yOffset+code.getY;
                    if (code.hasZ) {
                        z = zOffset+code.getZ;
                    }
                    if (code.hasE)
                    {
                        if (eRelative) {
                            eChanged = code->e!=0;
                            e += code->e;
                        } else {
                            eChanged = (eOffset+code->e)!=e;
                            e = eOffset + code->e;
                        }
                    }
                }
                if (x < currentPrinterConfiguration->xMin) { x = currentPrinterConfiguration->xMin; hasXHome = NO; }
                if (y < currentPrinterConfiguration->yMin) { y = currentPrinterConfiguration->yMin; hasYHome = NO; }
                if (z < 0) { z = 0; hasZHome = NO; }
                if (x > currentPrinterConfiguration->xMax) { hasXHome = NO; }
                if (y > currentPrinterConfiguration->yMax) { hasYHome = NO; }
                if (z > printerHeight) { hasZHome = NO; }
                if (e > emax) {
                    
                emax = e;
                if(z!=lastZPrint) {
                    lastZPrint = z;
                    layer++;
                    if(!privateAnalyzer && connection->job->dataComplete && connection->job->maxLayer>=0) {
                        [rhlog addInfo:[NSString stringWithFormat:@"Printing layer %d of %d",layer,connection->job->maxLayer]];
                    }                            
                    }
                }
                float dx = abs(x - lastX);
                float dy = abs(y - lastY);
                float dz = abs(z - lastZ);
                float de = abs(e - lastE);
                if (dx + dy + dz > 0.001)
                {
                    printingTime += sqrt(dx * dx + dy * dy + dz * dz) * 60.0f / f;
                }
                else printingTime += de * 60.0f / f;
                lastX = x;
                lastY = y;
                lastZ = z;
                lastE = e;
                [delegate positionChanged:self];
                break;
            case 28:
            case 161:
            {
                bool homeAll = !(code.hasX || code.hasY || code.hasZ);
                if (code.hasX || homeAll) { xOffset = 0; x = (currentPrinterConfiguration->homeXMax?currentPrinterConfiguration->xMax:currentPrinterConfiguration->xMin); hasXHome = YES; }
                if (code.hasY || homeAll) { yOffset = 0; y = (currentPrinterConfiguration->homeYMax?currentPrinterConfiguration->yMax:currentPrinterConfiguration->yMin); hasYHome = YES; }
                if (code.hasZ || homeAll) { zOffset = 0; z = (currentPrinterConfiguration->homeZMax?currentPrinterConfiguration->height:0); hasZHome = YES; }
                if (code.hasE) { eOffset = 0; e = 0; emax = 0; }
                [delegate positionChanged:self];
            }
                break;
            case 162:
            {
                bool homeAll = !(code.hasX || code.hasY || code.hasZ);
                if (code.hasX || homeAll) { xOffset = 0; x = currentPrinterConfiguration->xMax; hasXHome = YES; }
                if (code.hasY || homeAll) { yOffset = 0; y = currentPrinterConfiguration->yMax; hasYHome = YES; }
                if (code.hasZ || homeAll) { zOffset = 0; z = currentPrinterConfiguration->height; hasZHome = YES; }
                [delegate positionChanged:self];
            }
                break;
            case 90:
                relative = false;
                break;
            case 91:
                relative = true;
                break;
            case 92:
                if (code.hasX) { xOffset = x-code.getX; x = xOffset; }
                if (code.hasY) { yOffset = y-code.getY; y = yOffset; }
                if (code.hasZ) { zOffset = z-code.getZ; z = zOffset; }
                if (code.hasE) { eOffset = e-code.getE; lastE = e = eOffset; }
                [delegate positionChanged:self];
                break;
        }
    }
    else if (code.hasM)
    {
        switch (code.getM)
        {
            case 28:
                uploading = YES;
                break;
            case 29:
                uploading = NO;
                break;
            case 80:
                powerOn = YES;
                [self fireChanged];
                break;
            case 81:
                powerOn = NO;
                [self fireChanged];
                break;
            case 82:
                eRelative = NO;
                break;
            case 83:
                eRelative = YES;
                break;
            case 104:
            case 109:
            {
                int t = -1;
                if(code.hasT) t = code->t;
                if (code.hasS) [self setExtruder:t temperature:code.getS];
                [self fireChanged];
            }
                break;
            case 106:
                fanOn = YES;
                if (code.hasS) fanVoltage = code.getS;
                [self fireChanged];
                break;
            case 107:
                fanOn = NO;
                [self fireChanged];
                break;
            case 110:
                lastline = code.getN;
                break;
            case 111:
                if (code.hasS)
                {
                    debugLevel = code.getS;
                }
                break;
            case 140:
            case 190:
                if (code.hasS) bedTemp = code.getS;
                [self fireChanged];
                break;
            case 203: // Temp monitor
                tempMonitor = code.getS;
                break;
        }
    }
    else if (code.hasT)
    {
        activeExtruder = code.getT;
        [self fireChanged];
    }
}
-(void) analyzeShort:(GCodeShort*) code
{
    isG1Move = NO;
    switch (code.compressedCommand)
    {
        case 1:
            isG1Move = YES;
            eChanged = NO;
            if(code.hasF) f = code->f;
            if (relative) {
                if(code.hasX) {
                    x += code->x;
                    //if (x < 0) { x = 0; hasXHome = NO; }
                    //if (x > printerWidth) { hasXHome = NO; }
                }
                if(code.hasY) {
                    y += code->y;
                    //if (y < 0) { y = 0; hasYHome = NO; }
                    //if (y > printerDepth) { hasYHome = NO; }
                }
                if(code.hasZ) {
                    z += code->z;
                    //if (z < 0) { z = 0; hasZHome = NO; }
                    //if (z > printerHeight) { hasZHome = NO; }
                }
                if(code.hasE) {
                    eChanged = code->e!=0;
                    e += code->e;
                    if (e > emax) {
                        emax = e;
                        if(z>lastZPrint) {
                            lastZPrint = z;
                            layer++;
                        }
                    }
                }
            } else {
                if (code->x!=-99999) {
                    x = xOffset+code->x;
                    //if (x < 0) { x = 0; hasXHome = NO; }
                    //if (x > printerWidth) { hasXHome = NO; }
                }
                if (code->y!=-99999) {
                    y = yOffset+code->y;
                    //if (y < 0) { y = 0; hasYHome = NO; }
                    //if (y > printerDepth) { hasYHome = NO; }
                }
                if (code->z!=-99999) {
                    z = zOffset+code->z;
                    //if (z < 0) { z = 0; hasZHome = NO; }
                    //if (z > printerHeight) { hasZHome = NO; }
                }
                if (code->e!=-99999) {
                    if (eRelative) {
                        eChanged = code->e!=0;
                        e += code->e;
                    } else {
                        eChanged = (eOffset+code->e)!=e;
                        e = eOffset + code->e;
                    }
                    if (e > emax) {
                        emax = e;
                        if(z!=lastZPrint) {
                            lastZPrint = z;
                            layer++;
                        }
                    }
                }
            }
            float dx = abs(x - lastX);
            float dy = abs(y - lastY);
            float dz = abs(z - lastZ);
            float de = abs(e - lastE);
            if (dx + dy + dz > 0.001)
            {
                printingTime += sqrt(dx * dx + dy * dy + dz * dz) * 60.0f / f;
            }
            else printingTime += de * 60.0f / f;
            lastX = x;
            lastY = y;
            lastZ = z;
            lastE = e;
            [delegate positionChangedFastX:x y:y z:z e:e];
            break;
        case 4:
            {
                bool homeAll = !(code.hasX || code.hasY || code.hasZ);
                if (code.hasX || homeAll) { xOffset = 0; x = 0; hasXHome = YES; }
                if (code.hasY || homeAll) { yOffset = 0; y = 0; hasYHome = YES; }
                if (code.hasZ || homeAll) { zOffset = 0; z = 0; hasZHome = YES; }
                if (code.hasE) { eOffset = 0; e = 0; emax = 0; }
                // [delegate positionChangedFastX:x y:y z:z e:e];
            }
            break;
        case 5:
            {
                bool homeAll = !(code.hasX || code.hasY || code.hasZ);
                if (code.hasX || homeAll) { xOffset = 0; x = (currentPrinterConfiguration->homeXMax?currentPrinterConfiguration->xMax:currentPrinterConfiguration->xMin); hasXHome = YES; }
                if (code.hasY || homeAll) { yOffset = 0; y = (currentPrinterConfiguration->homeYMax?currentPrinterConfiguration->yMax:currentPrinterConfiguration->yMin); hasYHome = YES; }
                if (code.hasZ || homeAll) { zOffset = 0; z = currentPrinterConfiguration->height; hasZHome = YES; }
                //[delegate positionChangedFastX:x y:y z:z e:e];
            }
            break;
        case 6:
            relative = false;
            break;
        case 7:
            relative = true;
            break;
        case 8:
            if (code.hasX) { xOffset = x-code->x; x = xOffset; }
            if (code.hasY) { yOffset = y-code->y; y = yOffset; }
            if (code.hasZ) { zOffset = z-code->z; z = zOffset; }
            if (code.hasE) { eOffset = e-code->e; lastE = e = eOffset; }
            break;
        case 12: // Host command
            {
                NSString *hc = code->text;
                if ([hc compare:@"@hide"]==NSOrderedSame)
                    drawing = NO;
                else if ([hc compare:@"@show"]==NSOrderedSame)
                    drawing = YES;
                else if ([hc compare:@"@isathome"]==NSOrderedSame)
                {
                    hasXHome = hasYHome = hasZHome = YES;
                    x = (currentPrinterConfiguration->homeXMax?currentPrinterConfiguration->xMax:currentPrinterConfiguration->xMin);
                    xOffset = 0;
                    y = (currentPrinterConfiguration->homeYMax?currentPrinterConfiguration->yMax:currentPrinterConfiguration->yMin);
                    yOffset = 0;
                    z = (currentPrinterConfiguration->homeZMax?currentPrinterConfiguration->height:0);
                    zOffset = 0;
                }
            }
            break;
        case 9:
            eRelative = NO;
            break;
        case 10:
            eRelative = YES;
            break;
        case 11:
            activeExtruder = code.tool;
            break;
    }
    code->emax = emax;
    [code setLayer:layer];
    [code setTool:activeExtruder];
}


@end
