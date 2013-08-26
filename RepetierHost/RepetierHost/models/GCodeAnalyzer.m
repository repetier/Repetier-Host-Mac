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


@implementation ExtruderData
-(id)initWithId:(int)_id {
    if((self = [super init])) {
        extruderId = _id;
        temperature = 0;
        e = 0;
        emax = 0;
        lastE = 0;
        eOffset = 0;
        retracted = NO;
    }
    return self;
}
@end

@implementation GCodeAnalyzer


-(id)init {
    if((self=[super init])) {
        delegate = nil;
        extruder=[NSMutableDictionary new];
        activeExtruder = [self getExtruderDataFor:0];
        // activeExtruder = [[ExtruderData alloc] initWithId:0];
        //[extruder setObject:activeExtruder forKey:[NSNumber numberWithInt:0]];
        uploading = NO;
        bedTemp = 0;
        x = y = z = 0;
        f = 1000;
        lastX = lastY = lastZ = 0;
        xOffset = yOffset = zOffset = 0;
        fanOn = NO;
        fanVoltage = 0;
        powerOn = YES;
        relative = NO;
        eRelative = NO;
        debugLevel = 6;
        lastline = 0;
        lastZPrint = 0;
        printingTime = 0;
        layer = lastlayer = 0;
        hasXHome = hasYHome = hasZHome = NO;
        privateAnalyzer = NO;
        tempMonitor = -1;
        drawing = YES;
        lastlayer = 0;
        layerZ = 0;
        unchangedLayer = [RHLinkedList new];
    }
    return self;
}
-(void)dealloc {
    [extruder release];
    [unchangedLayer release];
    [super dealloc];
}
-(void)fireChanged {
    if(privateAnalyzer) return;
    [ThreadedNotification notifyASAP:@"RHPrinterStateChanged" object:self];
    [delegate printerStateChanged:self];
}
-(void) start {
    [extruder removeAllObjects];
    relative = NO;
    eRelative = NO;
    activeExtruder = [self getExtruderDataFor:0];
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
    x = y = z = 0;
    f = 1000;
    lastlayer = 0;
    layerZ = 0;
    lastX = lastY = lastZ = 0;
    xOffset = yOffset = zOffset = 0;
    hasXHome = hasYHome = hasZHome = NO;
    printerWidth = currentPrinterConfiguration->width;
    printerDepth = currentPrinterConfiguration->depth;
    printerHeight = currentPrinterConfiguration->height;
    [self fireChanged];
}
-(ExtruderData*)getExtruderDataFor:(int)ex {
    NSNumber *en = [NSNumber numberWithInt:ex];
    ExtruderData *exData = [extruder objectForKey:en];
    if(exData == nil) {
        exData = [[[ExtruderData alloc] initWithId:ex] autorelease];
        [extruder setObject:exData forKey:en];
    }
    return exData;
}
-(void) startJob {
    layer = 0;
    drawing = YES;
    lastline = 0;
    lastZPrint = 0;
    printingTime = 0;
    x = y = z = 0;
    lastX = lastY = lastZ = 0;
    xOffset = yOffset = zOffset = 0;
    lastlayer = 0;
    layerZ = 0;
}
-(float)getExtruderTemperature:(int)ext {
    ExtruderData *data;
    if(ext<0) data = activeExtruder;
    else data = [self getExtruderDataFor:ext];
    return data->temperature;
}
-(void)setExtruder:(int)ext temperature:(float)temp {
    ExtruderData *data;
    if(ext<0) data = activeExtruder;
    else data = [self getExtruderDataFor:ext];
    data->temperature = temp;
}
-(bool)isAnyExtruderEnabled {
    for(ExtruderData *data in extruder.allValues)
        if(data->temperature>20) return YES;
    return NO;
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
            x = [currentPrinterConfiguration xHomePosition];
            xOffset = 0;
            y = [currentPrinterConfiguration yHomePosition];
            yOffset = 0;
            z = [currentPrinterConfiguration zHomePosition];
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
                        if(eChanged) {
                            if(code->e<0) activeExtruder->retracted = YES;
                            else if(activeExtruder->retracted) {
                                activeExtruder->retracted = NO;
                                activeExtruder->e = activeExtruder->emax;
                            } else
                                activeExtruder->e += code->e;
                        }
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
                            if(eChanged) {
                                if(code->e<0) activeExtruder->retracted = YES;
                                else if(activeExtruder->retracted) {
                                    activeExtruder->retracted = NO;
                                    activeExtruder->e = activeExtruder->emax;
                                } else
                                    activeExtruder->e += code->e;
                            }
                        } else {
                            eChanged = (activeExtruder->eOffset+code->e)!=activeExtruder->e;
                            if(eChanged) {
                                activeExtruder->e = activeExtruder->eOffset + code->e;
                                if(activeExtruder->e < activeExtruder->lastE)
                                    activeExtruder->retracted = YES;
                                else if(activeExtruder->retracted) {
                                    activeExtruder->retracted = NO;
                                    activeExtruder->e = activeExtruder->emax;
                                    activeExtruder->eOffset = activeExtruder->e-code->e;
                                }
                            }
                        }
                    }
                }
                if (x < currentPrinterConfiguration->xMin) { x = currentPrinterConfiguration->xMin; hasXHome = NO; }
                if (y < currentPrinterConfiguration->yMin) { y = currentPrinterConfiguration->yMin; hasYHome = NO; }
                if (z < 0) { z = 0; hasZHome = NO; }
                if (x > currentPrinterConfiguration->xMax) { hasXHome = NO; }
                if (y > currentPrinterConfiguration->yMax) { hasYHome = NO; }
                if (z > printerHeight) { hasZHome = NO; }
                if (activeExtruder->e > activeExtruder->emax) {
                    
                activeExtruder->emax = activeExtruder->e;
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
                float de = abs(activeExtruder->e - activeExtruder->lastE);
                if (dx + dy + dz > 0.001)
                {
                    printingTime += sqrt(dx * dx + dy * dy + dz * dz) * 60.0f / f;
                }
                else printingTime += de * 60.0f / f;
                [delegate positionChanged:self x:x y:y z:z];
                lastX = x;
                lastY = y;
                lastZ = z;
                activeExtruder->lastE = activeExtruder->e;
                break;
            case 2:
            case 3:
            {
                isG1Move = true;
                eChanged = false;
                if (code.hasF) f = code.getF;
                if (relative)
                {
                    if (code.hasX)
                    {
                        x += code.getX;
                    }
                    if (code.hasY)
                    {
                        y += code.getY;
                    }
                    if (code.hasZ)
                    {
                        z += code.getZ;
                    }
                    if (code.hasE)
                    {
                        eChanged = code.getE != 0;
                        if(eChanged) {
                            if(code->e<0) activeExtruder->retracted = YES;
                            else if(activeExtruder->retracted) {
                                activeExtruder->retracted = NO;
                                activeExtruder->e = activeExtruder->emax;
                            } else
                                activeExtruder->e += code->e;
                        }
                    }
                }
                else
                {
                    if (code.hasX)
                    {
                        x = xOffset + code.getX;
                    }
                    if (code.hasY)
                    {
                        y = yOffset + code.getY;
                    }
                    if (code.hasZ)
                    {
                        z = zOffset + code.getZ;
                        //if (z < 0) { z = 0; hasZHome = NO; }
                        //if (z > printerHeight) { hasZHome = NO; }
                    }
                    if (code.hasE )
                    {
                        if (eRelative) {
                            eChanged = code->e!=0;
                            if(eChanged) {
                                if(code->e<0) activeExtruder->retracted = YES;
                                else if(activeExtruder->retracted) {
                                    activeExtruder->retracted = NO;
                                    activeExtruder->e = activeExtruder->emax;
                                } else
                                    activeExtruder->e += code->e;
                            }
                        } else {
                            eChanged = (activeExtruder->eOffset+code->e)!=activeExtruder->e;
                            if(eChanged) {
                                activeExtruder->e = activeExtruder->eOffset + code->e;
                                if(activeExtruder->e < activeExtruder->lastE)
                                    activeExtruder->retracted = YES;
                                else if(activeExtruder->retracted) {
                                    activeExtruder->retracted = NO;
                                    activeExtruder->e = activeExtruder->emax;
                                    activeExtruder->eOffset = activeExtruder->e-code->e;
                                }
                            }
                        }
                    }
                }
                
                float offset[] = { code.getI, code.getJ};
                /* if(unit_inches) {
                 offset[0]*=25.4;
                 offset[1]*=25.4;
                 }*/
                float position[] = { lastX, lastY };
                float target[] = { x, y };
                float r = code.getR;
                if (r > 0)
                {
                    /*
                     We need to calculate the center of the circle that has the designated radius and passes
                     through both the current position and the target position. This method calculates the following
                     set of equations where [x,y] is the vector from current to target position, d == magnitude of
                     that vector, h == hypotenuse of the triangle formed by the radius of the circle, the distance to
                     the center of the travel vector. A vector perpendicular to the travel vector [-y,x] is scaled to the
                     length of h [-y/d*h, x/d*h] and added to the center of the travel vector [x/2,y/2] to form the new point
                     [i,j] at [x/2-y/d*h, y/2+x/d*h] which will be the center of our arc.
                     
                     d^2 == x^2 + y^2
                     h^2 == r^2 - (d/2)^2
                     i == x/2 - y/d*h
                     j == y/2 + x/d*h
                     
                     O <- [i,j]
                     -  |
                     r      -     |
                     -        |
                     -           | h
                     -              |
                     [0,0] ->  C -----------------+--------------- T  <- [x,y]
                     | <------ d/2 ---->|
                     
                     C - Current position
                     T - Target position
                     O - center of circle that pass through both C and T
                     d - distance from C to T
                     r - designated radius
                     h - distance from center of CT to O
                     
                     Expanding the equations:
                     
                     d -> sqrt(x^2 + y^2)
                     h -> sqrt(4 * r^2 - x^2 - y^2)/2
                     i -> (x - (y * sqrt(4 * r^2 - x^2 - y^2)) / sqrt(x^2 + y^2)) / 2
                     j -> (y + (x * sqrt(4 * r^2 - x^2 - y^2)) / sqrt(x^2 + y^2)) / 2
                     
                     Which can be written:
                     
                     i -> (x - (y * sqrt(4 * r^2 - x^2 - y^2))/sqrt(x^2 + y^2))/2
                     j -> (y + (x * sqrt(4 * r^2 - x^2 - y^2))/sqrt(x^2 + y^2))/2
                     
                     Which we for size and speed reasons optimize to:
                     
                     h_x2_div_d = sqrt(4 * r^2 - x^2 - y^2)/sqrt(x^2 + y^2)
                     i = (x - (y * h_x2_div_d))/2
                     j = (y + (x * h_x2_div_d))/2
                     
                     */
                    //if(unit_inches) r*=25.4;
                    // Calculate the change in position along each selected axis
                    float cx = target[0] - position[0];
                    float cy = target[1] - position[1];
                    
                    float h_x2_div_d = -(float)sqrt(4 * r * r - cx * cx - cy * cy) / (float)sqrt(cx * cx + cy * cy); // == -(h * 2 / d)
                                                                                                                               // If r is smaller than d, the arc is now traversing the complex plane beyond the reach of any
                                                                                                                               // real CNC, and thus - for practical reasons - we will terminate promptly:
                                                                                                                               // if(isnan(h_x2_div_d)) { OUT_P_LN("error: Invalid arc"); break; }
                                                                                                                               // Invert the sign of h_x2_div_d if the circle is counter clockwise (see sketch below)
                    if (code.getG == 3) { h_x2_div_d = -h_x2_div_d; }
                    
                    /* The counter clockwise circle lies to the left of the target direction. When offset is positive,
                     the left hand circle will be generated - when it is negative the right hand circle is generated.
                     
                     
                     T  <-- Target position
                     
                     ^
                     Clockwise circles with this center         |          Clockwise circles with this center will have
                     will have > 180 deg of angular travel      |          < 180 deg of angular travel, which is a good thing!
                     \         |          /
                     center of arc when h_x2_div_d is positive ->  x <----- | -----> x <- center of arc when h_x2_div_d is negative
                     |
                     |
                     
                     C  <-- Current position                                 */
                    
                    
                    // Negative R is g-code-alese for "I want a circle with more than 180 degrees of travel" (go figure!),
                    // even though it is advised against ever generating such circles in a single line of g-code. By
                    // inverting the sign of h_x2_div_d the center of the circles is placed on the opposite side of the line of
                    // travel and thus we get the unadvisably long arcs as prescribed.
                    if (r < 0)
                    {
                        h_x2_div_d = -h_x2_div_d;
                        r = -r; // Finished with r. Set to positive for mc_arc
                    }
                    // Complete the operation by calculating the actual center of the arc
                    offset[0] = 0.5f * (cx - (cy * h_x2_div_d));
                    offset[1] = 0.5f * (cy + (cx * h_x2_div_d));
                    
                }
                else
                { // Offset mode specific computations
                    r = (float)sqrt(offset[0] * offset[0] + offset[1] * offset[1]); // Compute arc radius for mc_arc
                }
                
                // Set clockwise/counter-clockwise sign for mc_arc computations
                bool isclockwise = code.getG == 2;
                
                // Trace the arc
                [self arcPosition:position target:target offset:offset radius:r clockwise:isclockwise gcode:code];
                lastX = x;
                lastY = y;
                lastZ = z;
                activeExtruder->lastE = activeExtruder->e;
                if (x < currentPrinterConfiguration->xMin) { x = currentPrinterConfiguration->xMin; hasXHome = NO; }
                if (y < currentPrinterConfiguration->yMin) { y = currentPrinterConfiguration->yMin; hasYHome = NO; }
                if (z < 0) { z = 0; hasZHome = NO; }
                if (x > currentPrinterConfiguration->xMax) { hasXHome = NO; }
                if (y > currentPrinterConfiguration->yMax) { hasYHome = NO; }
                if (z > printerHeight) { hasZHome = NO; }
                if (activeExtruder->e > activeExtruder->emax)
                {
                    activeExtruder->emax = activeExtruder->e;
                    if (z > lastZPrint)
                    {
                        lastZPrint = z;
                        layer++;
                    }
                }
                
            }
                break;
            case 28:
            case 161:
            {
                bool homeAll = !(code.hasX || code.hasY || code.hasZ);
                if (code.hasX || homeAll) { xOffset = 0; x = [currentPrinterConfiguration xHomePosition]; hasXHome = YES; }
                if (code.hasY || homeAll) { yOffset = 0; y = [currentPrinterConfiguration yHomePosition]; hasYHome = YES; }
                if (code.hasZ || homeAll) { zOffset = 0; z = [currentPrinterConfiguration zHomePosition]; hasZHome = YES; }
                if (code.hasE) { activeExtruder->eOffset = 0; activeExtruder->e = 0; activeExtruder->emax = 0; }
                [delegate positionChanged:self x:x y:y z:z];
            }
                break;
            case 162:
            {
                bool homeAll = !(code.hasX || code.hasY || code.hasZ);
                if (code.hasX || homeAll) { xOffset = 0; x = currentPrinterConfiguration->xMax; hasXHome = YES; }
                if (code.hasY || homeAll) { yOffset = 0; y = currentPrinterConfiguration->yMax; hasYHome = YES; }
                if (code.hasZ || homeAll) { zOffset = 0; z = currentPrinterConfiguration->height; hasZHome = YES; }
                [delegate positionChanged:self x:x y:y z:z];
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
                if (code.hasE) { activeExtruder->eOffset = activeExtruder->e-code.getE;
                    activeExtruder->lastE = activeExtruder->e = activeExtruder->eOffset; }
                [delegate positionChanged:self x:x y:y z:z];
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
        activeExtruder = [self getExtruderDataFor:code.getT];
        [self fireChanged];
    }
}
-(void) analyzeShort:(GCodeShort*) code
{
    isG1Move = NO;
    switch (code.compressedCommand)
    {
        case 0:
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
                    if(eChanged) {
                        if(code->e<0) activeExtruder->retracted = YES;
                        else if(activeExtruder->retracted) {
                            activeExtruder->retracted = NO;
                            activeExtruder->e = activeExtruder->emax;
                        } else
                            activeExtruder->e += code->e;
                    }
                    if (activeExtruder->e > activeExtruder->emax) {
                        activeExtruder->emax = activeExtruder->e;
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
                        if(eChanged) {
                            if(code->e<0) activeExtruder->retracted = YES;
                            else if(activeExtruder->retracted) {
                                activeExtruder->retracted = NO;
                                activeExtruder->e = activeExtruder->emax;
                            } else
                            activeExtruder->e += code->e;
                        }
                    } else {
                        eChanged = (activeExtruder->eOffset+code->e)!=activeExtruder->e;
                        if(eChanged) {
                            activeExtruder->e = activeExtruder->eOffset + code->e;
                            if(activeExtruder->e < activeExtruder->lastE)
                                activeExtruder->retracted = YES;
                            else if(activeExtruder->retracted) {
                                activeExtruder->retracted = NO;
                                activeExtruder->e = activeExtruder->emax;
                                activeExtruder->eOffset = activeExtruder->e-code->e;
                            }
                        }
                    }
                    if (activeExtruder->e > activeExtruder->emax) {
                        activeExtruder->emax = activeExtruder->e;
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
            float de = abs(activeExtruder->e - activeExtruder->lastE);
            if (dx + dy + dz > 0.001)
            {
                printingTime += sqrt(dx * dx + dy * dy + dz * dz) * 60.0f / f;
            }
            else printingTime += de * 60.0f / f;
            if(z!=lastZ) [unchangedLayer clear];
            lastX = x;
            lastY = y;
            lastZ = z;
            activeExtruder->lastE = activeExtruder->e;
            [delegate positionChangedFastX:x y:y z:z e:activeExtruder->e];
            break;
        case 2:
        case 3:
        {
            isG1Move = true;
            eChanged = false;
            if (code.hasF) f = code->f;
            if (relative)
            {
                if (code.hasX)
                {
                    x += code->x;
                    //if (x < 0) { x = 0; hasXHome = NO; }
                    //if (x > printerWidth) { hasXHome = NO; }
                }
                if (code.hasY)
                {
                    y += code->y;
                    //if (y < 0) { y = 0; hasYHome = NO; }
                    //if (y > printerDepth) { hasYHome = NO; }
                }
                if (code.hasZ)
                {
                    z += code->z;
                    //if (z < 0) { z = 0; hasZHome = NO; }
                    //if (z > printerHeight) { hasZHome = NO; }
                }
                if (code.hasE)
                {
                    eChanged = code->e != 0;
                    if(eChanged) {
                        if(code->e<0) activeExtruder->retracted = YES;
                        else if(activeExtruder->retracted) {
                            activeExtruder->retracted = NO;
                            activeExtruder->e = activeExtruder->emax;
                        } else
                            activeExtruder->e += code->e;
                    }
                }
            }
            else
            {
                if (code->x != -99999)
                {
                    x = xOffset + code->x;
                    //if (x < 0) { x = 0; hasXHome = NO; }
                    //if (x > printerWidth) { hasXHome = NO; }
                }
                if (code->y != -99999)
                {
                    y = yOffset + code->y;
                    //if (y < 0) { y = 0; hasYHome = NO; }
                    //if (y > printerDepth) { hasYHome = NO; }
                }
                if (code->z != -99999)
                {
                    z = zOffset + code->z;
                    //if (z < 0) { z = 0; hasZHome = NO; }
                    //if (z > printerHeight) { hasZHome = NO; }
                }
                if (code->e != -99999)
                {
                    if (eRelative) {
                        eChanged = code->e!=0;
                        if(eChanged) {
                            if(code->e<0) activeExtruder->retracted = YES;
                            else if(activeExtruder->retracted) {
                                activeExtruder->retracted = NO;
                                activeExtruder->e = activeExtruder->emax;
                            } else
                                activeExtruder->e += code->e;
                        }
                    } else {
                        eChanged = (activeExtruder->eOffset+code->e)!=activeExtruder->e;
                        if(eChanged) {
                            activeExtruder->e = activeExtruder->eOffset + code->e;
                            if(activeExtruder->e < activeExtruder->lastE)
                                activeExtruder->retracted = YES;
                            else if(activeExtruder->retracted) {
                                activeExtruder->retracted = NO;
                                activeExtruder->e = activeExtruder->emax;
                                activeExtruder->eOffset = activeExtruder->e-code->e;
                            }
                        }
                    }
                }
            }
            
            float offset[] = { [code getValueFor:@"I" default:0], [code getValueFor:@"J" default:0] };
            /* if(unit_inches) {
             offset[0]*=25.4;
             offset[1]*=25.4;
             }*/
            float position[] = { lastX, lastY };
            float target[] = { x, y };
            float r = [code getValueFor:@"R" default:-1000000];
            if (r > 0)
            {
                /*
                 We need to calculate the center of the circle that has the designated radius and passes
                 through both the current position and the target position. This method calculates the following
                 set of equations where [x,y] is the vector from current to target position, d == magnitude of
                 that vector, h == hypotenuse of the triangle formed by the radius of the circle, the distance to
                 the center of the travel vector. A vector perpendicular to the travel vector [-y,x] is scaled to the
                 length of h [-y/d*h, x/d*h] and added to the center of the travel vector [x/2,y/2] to form the new point
                 [i,j] at [x/2-y/d*h, y/2+x/d*h] which will be the center of our arc.
                 
                 d^2 == x^2 + y^2
                 h^2 == r^2 - (d/2)^2
                 i == x/2 - y/d*h
                 j == y/2 + x/d*h
                 
                 O <- [i,j]
                 -  |
                 r      -     |
                 -        |
                 -           | h
                 -              |
                 [0,0] ->  C -----------------+--------------- T  <- [x,y]
                 | <------ d/2 ---->|
                 
                 C - Current position
                 T - Target position
                 O - center of circle that pass through both C and T
                 d - distance from C to T
                 r - designated radius
                 h - distance from center of CT to O
                 
                 Expanding the equations:
                 
                 d -> sqrt(x^2 + y^2)
                 h -> sqrt(4 * r^2 - x^2 - y^2)/2
                 i -> (x - (y * sqrt(4 * r^2 - x^2 - y^2)) / sqrt(x^2 + y^2)) / 2
                 j -> (y + (x * sqrt(4 * r^2 - x^2 - y^2)) / sqrt(x^2 + y^2)) / 2
                 
                 Which can be written:
                 
                 i -> (x - (y * sqrt(4 * r^2 - x^2 - y^2))/sqrt(x^2 + y^2))/2
                 j -> (y + (x * sqrt(4 * r^2 - x^2 - y^2))/sqrt(x^2 + y^2))/2
                 
                 Which we for size and speed reasons optimize to:
                 
                 h_x2_div_d = sqrt(4 * r^2 - x^2 - y^2)/sqrt(x^2 + y^2)
                 i = (x - (y * h_x2_div_d))/2
                 j = (y + (x * h_x2_div_d))/2
                 
                 */
                //if(unit_inches) r*=25.4;
                // Calculate the change in position along each selected axis
                float cx = target[0] - position[0];
                float cy = target[1] - position[1];
                
                float h_x2_div_d = -(float)sqrt(4 * r * r - cx * cx - cy * cy) / (float)sqrt(cx * cx + cy * cy); // == -(h * 2 / d)
                                                                                                                           // If r is smaller than d, the arc is now traversing the complex plane beyond the reach of any
                                                                                                                           // real CNC, and thus - for practical reasons - we will terminate promptly:
                                                                                                                           // if(isnan(h_x2_div_d)) { OUT_P_LN("error: Invalid arc"); break; }
                                                                                                                           // Invert the sign of h_x2_div_d if the circle is counter clockwise (see sketch below)
                if (code.compressedCommand == 3) { h_x2_div_d = -h_x2_div_d; }
                
                /* The counter clockwise circle lies to the left of the target direction. When offset is positive,
                 the left hand circle will be generated - when it is negative the right hand circle is generated.
                 
                 
                 T  <-- Target position
                 
                 ^
                 Clockwise circles with this center         |          Clockwise circles with this center will have
                 will have > 180 deg of angular travel      |          < 180 deg of angular travel, which is a good thing!
                 \         |          /
                 center of arc when h_x2_div_d is positive ->  x <----- | -----> x <- center of arc when h_x2_div_d is negative
                 |
                 |
                 
                 C  <-- Current position                                 */
                
                
                // Negative R is g-code-alese for "I want a circle with more than 180 degrees of travel" (go figure!),
                // even though it is advised against ever generating such circles in a single line of g-code. By
                // inverting the sign of h_x2_div_d the center of the circles is placed on the opposite side of the line of
                // travel and thus we get the unadvisably long arcs as prescribed.
                if (r < 0)
                {
                    h_x2_div_d = -h_x2_div_d;
                    r = -r; // Finished with r. Set to positive for mc_arc
                }
                // Complete the operation by calculating the actual center of the arc
                offset[0] = 0.5f * (cx - (cy * h_x2_div_d));
                offset[1] = 0.5f * (cy + (cx * h_x2_div_d));
                
            }
            else
            { // Offset mode specific computations
                r = (float)sqrt(offset[0] * offset[0] + offset[1] * offset[1]); // Compute arc radius for mc_arc
            }
            
            // Set clockwise/counter-clockwise sign for mc_arc computations
            bool isclockwise = code.compressedCommand == 2;
            
            // Trace the arc
            [self arcPosition:position target:target offset:offset radius:r clockwise:isclockwise gcode:nil];
            lastX = x;
            lastY = y;
            lastZ = z;
            activeExtruder->lastE = activeExtruder->e;
            if (activeExtruder->e > activeExtruder->emax)
            {
                activeExtruder->emax = activeExtruder->e;
                if (z > lastZPrint)
                {
                    lastZPrint = z;
                    layer++;
                }
            }
            
        }
            break;
        case 4:
            {
                bool homeAll = !(code.hasX || code.hasY || code.hasZ);
                if (code.hasX || homeAll) { xOffset = 0; x = 0; hasXHome = YES; }
                if (code.hasY || homeAll) { yOffset = 0; y = 0; hasYHome = YES; }
                if (code.hasZ || homeAll) { zOffset = 0; z = 0; hasZHome = YES; }
                if (code.hasE) { activeExtruder->eOffset = 0; activeExtruder->e = 0; activeExtruder->emax = 0; }
                // [delegate positionChangedFastX:x y:y z:z e:e];
            }
            break;
        case 5:
            {
                bool homeAll = !(code.hasX || code.hasY || code.hasZ);
                if (code.hasX || homeAll) { xOffset = 0; x = [currentPrinterConfiguration xHomePosition]; hasXHome = YES; }
                if (code.hasY || homeAll) { yOffset = 0; y = [currentPrinterConfiguration yHomePosition]; hasYHome = YES; }
                if (code.hasZ || homeAll) { zOffset = 0; z = [currentPrinterConfiguration zHomePosition]; hasZHome = YES; }
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
            if (code.hasE) { activeExtruder->eOffset = activeExtruder->e-code->e; activeExtruder->lastE = activeExtruder->e = activeExtruder->eOffset; }
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
                    x = [currentPrinterConfiguration xHomePosition];
                    xOffset = 0;
                    y = [currentPrinterConfiguration yHomePosition];
                    yOffset = 0;
                    z = [currentPrinterConfiguration zHomePosition];
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
            activeExtruder = [self getExtruderDataFor:code.tool];
            break;
    }
    if(layer!=lastlayer) {
        for(GCodeShort *c in unchangedLayer) {
            [c setLayer:layer];
        }
        [unchangedLayer clear];
        layerZ = z;
        lastlayer = layer;
    } else if(z!=layerZ)
        [unchangedLayer addLast:code];
    code->emax = activeExtruder->emax;
    [code setLayer:layer];
    [code setTool:activeExtruder->extruderId];
}

-(void) arcPosition:(float[])position target:(float[]) target offset:(float[]) offset radius:(float) radius clockwise:(BOOL) isclockwise gcode:(GCode*) code
{
    //   int acceleration_manager_was_enabled = plan_is_acceleration_manager_enabled();
    //   plan_set_acceleration_manager_enabled(false); // disable acceleration management for the duration of the arc
    float center_axis0 = position[0] + offset[0];
    float center_axis1 = position[1] + offset[1];
    //float linear_travel = 0; //target[axis_linear] - position[axis_linear];
    float r_axis0 = -offset[0];  // Radius vector from center to current location
    float r_axis1 = -offset[1];
    float rt_axis0 = target[0] - center_axis0;
    float rt_axis1 = target[1] - center_axis1;
    
    // CCW angle between position and target from circle center. Only one atan2() trig computation required.
    float angular_travel = (float)atan2(r_axis0 * rt_axis1 - r_axis1 * rt_axis0, r_axis0 * rt_axis0 + r_axis1 * rt_axis1);
    if (angular_travel < 0) { angular_travel += 2 * (float)M_PI; }
    if (isclockwise) { angular_travel -= 2 * (float)M_PI; }
    
    float millimeters_of_travel = fabs(angular_travel) * radius; //hypot(angular_travel*radius, fabs(linear_travel));
    if (millimeters_of_travel < 0.001) { return; }
    printingTime += millimeters_of_travel * 60.0f / f;
    //uint16_t segments = (radius>=BIG_ARC_RADIUS ? floor(millimeters_of_travel/MM_PER_ARC_SEGMENT_BIG) : floor(millimeters_of_travel/MM_PER_ARC_SEGMENT));
    // Increase segment size if printing faster then computation speed allows
    int segments = (int)MIN(millimeters_of_travel,millimeters_of_travel*10/radius);
    if (segments > 32) segments = 32;
    if (segments == 0) segments = 1;
    /*
     // Multiply inverse feed_rate to compensate for the fact that this movement is approximated
     // by a number of discrete segments. The inverse feed_rate should be correct for the sum of
     // all segments.
     if (invert_feed_rate) { feed_rate *= segments; }
     */
    float theta_per_segment = angular_travel / segments;
    //float linear_per_segment = linear_travel / segments;
    float extruder_per_segment = (activeExtruder->e - activeExtruder->lastE) / segments;
    // Vector rotation matrix values
    
    float arc_target_e = activeExtruder->lastE;
    float sin_Ti;
    float cos_Ti;
    int i;
    
    for (i = 1; i < segments; i++)
    { // Increment (segments-1)
      // Arc correction to radius vector. Computed only every N_ARC_CORRECTION increments.
      // Compute exact location by applying transformation matrix from initial radius vector(=-offset).
        cos_Ti = (float)cos(i * theta_per_segment);
        sin_Ti = (float)sin(i * theta_per_segment);
        r_axis0 = -offset[0] * cos_Ti + offset[1] * sin_Ti;
        r_axis1 = -offset[0] * sin_Ti - offset[1] * cos_Ti;
        
        // Update arc_target location
        //arc_target[axis_linear] += linear_per_segment;
        arc_target_e += extruder_per_segment;
        if (arc_target_e > activeExtruder->emax)
        {
            activeExtruder->emax = arc_target_e;
            if (z > lastZPrint)
            {
                lastZPrint = z;
                layer++;
                if (code!=nil)
                {
                    if(!privateAnalyzer && connection->job->dataComplete && connection->job->maxLayer>=0) {
                        [rhlog addInfo:[NSString stringWithFormat:@"Printing layer %d of %d",layer,connection->job->maxLayer]];
                    }
                }
            }
        }
        if (code!=nil)
        {
            [delegate positionChanged:self x:center_axis0 + r_axis0 y:center_axis1 + r_axis1 z:z];
        } else
            [delegate positionChangedFastX:center_axis0 + r_axis0 y:center_axis1 + r_axis1 z:z e:arc_target_e];
    }
    // Ensure last segment arrives at target location.
    if (activeExtruder->e > activeExtruder->emax)
    {
        activeExtruder->emax = activeExtruder->e;
        if (z > lastZPrint)
        {
            lastZPrint = z;
            layer++;
            if (code!=nil)
            {
                if(!privateAnalyzer && connection->job->dataComplete && connection->job->maxLayer>=0) {
                    [rhlog addInfo:[NSString stringWithFormat:@"Printing layer %d of %d",layer,connection->job->maxLayer]];
                }
            }
        }
    }
    if (code!=nil)
    {
        [delegate positionChanged:self x:x y:y z:z];
    }
    else
        [delegate positionChangedFastX:x y:y z:z e:activeExtruder->e];
    
}
@end
