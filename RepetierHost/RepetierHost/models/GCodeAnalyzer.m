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

@implementation GCodeAnalyzer

@synthesize delegate;

-(id)init {
    if((self=[super init])) {
        activeExtruder = 0;
        extruderTemp=0;
        uploading = NO;
        bedTemp = 0;
        x = y = z = e = emax = 0;
        xOffset = yOffset = zOffset = eOffset = 0;
        fanOn = NO;
        fanVoltage = 0;
        powerOn = YES;
        relative = NO;
        eRelative = NO;
        debugLevel = 6;
        lastline = 0;
        hasXHome = hasYHome = hasZHome = NO;
        privateAnalyzer = NO;
        tempMonitor = -1;
        drawing = YES;
    }
    return self;
}
-(void)fireChanged {
    if(privateAnalyzer) return;
    [ThreadedNotification notifyASAP:@"RHPrinterStateChanged" object:self];
    [delegate printerStateChanged:self];
}
-(void) start {
    relative = NO;
    eRelative = NO;
    activeExtruder = 0;
    extruderTemp = 0;
    bedTemp = 0;
    fanOn = NO;
    powerOn = YES;
    drawing = YES;
    fanVoltage = 0;
    lastline = 0;
    tempMonitor = -1;
    x = y = z = e = emax = 0;
    xOffset = yOffset = zOffset = eOffset = 0;
    hasXHome = hasYHome = hasZHome = NO;
    printerWidth = currentPrinterConfiguration->width;
    printerDepth = currentPrinterConfiguration->depth;
    printerHeight = currentPrinterConfiguration->height;
    [self fireChanged];
}
-(void) analyze:(GCode*) code
{
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
            x = xOffset = 0;
            y = yOffset = 0;
            z = zOffset = 0;
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
                if (relative)
                {
                    if(code.hasX) x += code.getX;
                    if(code.hasY) y += code.getY;
                    if(code.hasZ) z += code.getZ;
                    if(code.hasE) e += code.getE;
                }
                else
                {
                    if (code.hasX) x = xOffset+code.getX;
                    if (code.hasY) y = yOffset+code.getY;
                    if (code.hasZ) z = zOffset+code.getZ;
                    if (code.hasE)
                    {
                        if (eRelative)
                            e += code.getE;
                        else
                            e = eOffset + code.getE;
                    }
                }
                if (x < 0) { x = 0; hasXHome = NO; }
                if (y < 0) { y = 0; hasYHome = NO; }
                if (z < 0) { z = 0; hasZHome = NO; }
                if (x > printerWidth) { hasXHome = NO; }
                if (y > printerDepth) { hasYHome = NO; }
                if (z > printerHeight) { hasZHome = NO; }
                if (e > emax) emax = e;
                [delegate positionChanged:self];
                break;
            case 28:
            case 161:
            {
                bool homeAll = !(code.hasX || code.hasY || code.hasZ);
                if (code.hasX || homeAll) { xOffset = 0; x = 0; hasXHome = YES; }
                if (code.hasY || homeAll) { yOffset = 0; y = 0; hasYHome = YES; }
                if (code.hasZ || homeAll) { zOffset = 0; z = 0; hasZHome = YES; }
                if (code.hasE) { eOffset = 0; e = 0; emax = 0; }
                [delegate positionChanged:self];
            }
                break;
            case 162:
            {
                bool homeAll = !(code.hasX || code.hasY || code.hasZ);
                if (code.hasX || homeAll) { xOffset = 0; x = currentPrinterConfiguration->width; hasXHome = YES; }
                if (code.hasY || homeAll) { yOffset = 0; y = currentPrinterConfiguration->depth; hasYHome = YES; }
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
                if (code.hasE) { eOffset = e-code.getE; e = eOffset; }
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
                if (code.hasS) extruderTemp = code.getS;
                [self fireChanged];
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
            case 141:
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
    }
}


@end
