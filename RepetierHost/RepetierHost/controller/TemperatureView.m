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

#import "TemperatureView.h"
#import "TemperatureHistory.h"

static double tempTickSizes[] = {100,50,25,20,10,5,1};
static double timeTickSizes[] = {1800,900,600,300,60,30,15,5,1};

@implementation TemperatureView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        hist = nil;
        tickExtra = 3;
        spaceExtra = 3;
        drawFont = [[NSFont userFixedPitchFontOfSize:10] retain];
        fontAttributes = [[NSMutableDictionary alloc] init];
        [fontAttributes setObject:drawFont forKey:NSFontAttributeName];
        NSSize sz = [@"00:00" sizeWithAttributes:fontAttributes];
        timeWidth = sz.width;
        timeHeight = sz.height;
        sz = [@"000" sizeWithAttributes:fontAttributes];
        tempWidth = sz.width;
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"mm:ss"];
    }
    
    return self;
}
-(void)awakeFromNib {
}
- (BOOL)acceptsFirstResponder
{
    return YES;
}
- (BOOL)becomeFirstResponder
{
    return YES;
}
-(BOOL)acceptsFirstMouse {
    return YES;
}
-(void)mouseDown:(NSEvent*)theEvent {
    NSPoint p = theEvent.locationInWindow;
    down = [self convertPoint:p fromView:nil];
}
-(void)mouseDragged:(NSEvent *)theEvent {
    NSPoint p = theEvent.locationInWindow;
    p = [self convertPoint:p fromView:nil];
    float dx = p.x-down.x;
    float delta = 100*dx*(righttime-lefttime)/(axisWidth*3600);
    hist->xpos -=delta;
    if(hist->xpos<0) hist->xpos = 0;
    if(hist->xpos>100) hist->xpos = 100;    
    [[NSUserDefaults standardUserDefaults] setBool:hist->xpos==100 forKey:@"tempAutoscroll"];
    down = p;
    [self setNeedsDisplay:YES];
}
-(void)drawGrid:(NSRect)rect temp:(BOOL)isTemp {
    // Draw grid lines
    NSGraphicsContext* theContext = [NSGraphicsContext currentContext];
    [theContext saveGraphicsState];
    [hist->gridColor set];
    double x = timeTick*(floor(lefttime/timeTick));
    while(x<lefttime) x+=timeTick;
    NSBezierPath *p = [NSBezierPath bezierPath];
    NSBezierPath *axis = [NSBezierPath bezierPath];
    float ybot = rect.origin.y;
    float ytop = rect.origin.y+NSHeight(rect);
    float xleft = rect.origin.x;
    axisWidth = NSWidth(rect);
    float xright = rect.origin.x+axisWidth;
    [fontAttributes setObject:hist->fontColor forKey:NSForegroundColorAttributeName];
    for(;x<righttime;x+=timeTick) {
        float xp = xleft+(x-lefttime)*timeScale;
        [p moveToPoint:NSMakePoint(xp, ybot)];
        [p lineToPoint:NSMakePoint(xp, ytop)];
        [axis moveToPoint:NSMakePoint(xp,ybot)];
        [axis lineToPoint:NSMakePoint(xp,ybot-tickExtra)];
        NSDate *d = [NSDate dateWithTimeIntervalSince1970:x];
        NSString *time = [dateFormatter stringFromDate:d];
        [time drawAtPoint:NSMakePoint(xp-0.5*timeWidth,ybot-tickExtra-timeHeight) withAttributes:fontAttributes];
    }
    if(isTemp) {
    float y = minTemp;
        for(;y<=maxTemp;y+=tempTick) {
            float yp = ybot+(y-minTemp)*tempScale;
            [p moveToPoint:NSMakePoint(xleft,yp)];
            [p lineToPoint:NSMakePoint(xright,yp)];
            [axis moveToPoint:NSMakePoint(xleft, yp)];
            [axis lineToPoint:NSMakePoint(xleft-tickExtra,yp)];
            [axis moveToPoint:NSMakePoint(xright, yp)];
            [axis lineToPoint:NSMakePoint(xright+tickExtra,yp)];
            NSString *tempText = [NSString stringWithFormat:@"%d",(int)y];
            [tempText drawAtPoint:NSMakePoint(xleft-tickExtra-tempWidth-spaceExtra,yp-0.5*timeHeight) withAttributes:fontAttributes];
            [tempText drawAtPoint:NSMakePoint(xright+tickExtra+spaceExtra,yp-0.5*timeHeight) withAttributes:fontAttributes];
        }
    } else {
        for(int i=0;i<110;i+=50) {
            float yp = (float)i*.01*(ytop-ybot)+ybot;
            [p moveToPoint:NSMakePoint(xleft,yp)];
            [p lineToPoint:NSMakePoint(xright,yp)];
            NSString *tempText = [NSString stringWithFormat:@"%d",i];
            [tempText drawAtPoint:NSMakePoint(xleft-tickExtra-tempWidth-spaceExtra,yp-0.5*timeHeight) withAttributes:fontAttributes];
            [tempText drawAtPoint:NSMakePoint(xright+tickExtra+spaceExtra,yp-0.5*timeHeight) withAttributes:fontAttributes];
        }
    }
    [axis moveToPoint:NSMakePoint(xleft,ytop)];
    [axis lineToPoint:NSMakePoint(xleft,ybot)];
    [axis lineToPoint:NSMakePoint(xright,ybot)];
    [axis lineToPoint:NSMakePoint(xright,ytop)];
    [axis lineToPoint:NSMakePoint(xleft,ytop)];
    [hist->gridColor set];
    [p setLineWidth:1];
    [p stroke];
    [hist->axisColor set];
    [axis setLineWidth:2];
    [axis stroke];
    // NSGraphicsContext* theContext = [NSGraphicsContext currentContext];
    NSRectClip(rect);
    if(isTemp) {
        NSBezierPath *pExt = nil;
        NSBezierPath *pAvgExt = nil;
        NSBezierPath *pTarExt = nil;
        NSBezierPath *pBed = nil;
        NSBezierPath *pTarBed = nil;
        NSBezierPath *pAvgBed = nil;
        if(hist->showExtruder) {
            pExt = [NSBezierPath bezierPath];
            if(hist->showAverage)
                pAvgExt = [NSBezierPath bezierPath];
            if(hist->showTarget)
                pTarExt = [NSBezierPath bezierPath];
        }
        if(hist->showBed) {
            pBed = [NSBezierPath bezierPath];
            if(hist->showAverage)
                pAvgBed = [NSBezierPath bezierPath];
            if(hist->showTarget)
                pTarBed = [NSBezierPath bezierPath];
        }
        for(TempertureEntry *e in hist->currentHistory->entries) {
            float xp = xleft+(e->time-lefttime)*timeScale;
            if(pExt && e->extruder>=0) {
                if(pExt.isEmpty)
                    [pExt moveToPoint:NSMakePoint(xp, ybot+(e->extruder-minTemp)*tempScale)];
                else
                    [pExt lineToPoint:NSMakePoint(xp, ybot+(e->extruder-minTemp)*tempScale)];
            }
            if(pAvgExt && e->avgExtruder>=0) {
                if(pAvgExt.isEmpty)
                    [pAvgExt moveToPoint:NSMakePoint(xp, ybot+(e->avgExtruder-minTemp)*tempScale)];
                else
                    [pAvgExt lineToPoint:NSMakePoint(xp, ybot+(e->avgExtruder-minTemp)*tempScale)];
            }
            if(pTarExt && e->targetExtruder>=0) {
                if(pTarExt.isEmpty)
                    [pTarExt moveToPoint:NSMakePoint(xp, ybot+(e->targetExtruder-minTemp)*tempScale)];
                else
                    [pTarExt lineToPoint:NSMakePoint(xp, ybot+(e->targetExtruder-minTemp)*tempScale)];
            }
            if(pBed && e->bed>=0) {
                if(pBed.isEmpty)
                    [pBed moveToPoint:NSMakePoint(xp, ybot+(e->bed-minTemp)*tempScale)];
                else
                    [pBed lineToPoint:NSMakePoint(xp, ybot+(e->bed-minTemp)*tempScale)];
            }
            if(pAvgBed && e->avgExtruder>=0) {
                if(pAvgBed.isEmpty)
                    [pAvgBed moveToPoint:NSMakePoint(xp, ybot+(e->avgBed-minTemp)*tempScale)];
                else
                    [pAvgBed lineToPoint:NSMakePoint(xp, ybot+(e->avgBed-minTemp)*tempScale)];
            }
            if(pTarBed && e->targetBed>=0) {
                if(pTarBed.isEmpty)
                    [pTarBed moveToPoint:NSMakePoint(xp, ybot+(e->targetBed-minTemp)*tempScale)];
                else
                    [pTarBed lineToPoint:NSMakePoint(xp, ybot+(e->targetBed-minTemp)*tempScale)];
            }
            if(e->time>righttime) break;
        }
        // Draw temperatures
        if(pTarExt) {
            [hist->targetExtruderColor set];
            [pTarExt setLineWidth:hist->targetExtruderWidth];
            [pTarExt stroke];
        }
        if(pAvgExt) {
            [hist->avgExtruderColor set];
            [pAvgExt setLineWidth:hist->avgExtruderWidth];
            [pAvgExt stroke];
        }
        if(pExt) {
            [hist->extruderColor set];
            [pExt setLineWidth:hist->extruderWidth];
            [pExt stroke];
        }
        if(pTarBed) {
            [hist->targetBedColor set];
            [pTarBed setLineWidth:hist->targetBedWidth];
            [pTarBed stroke];
        }
        if(pAvgBed) {
            [hist->avgBedColor set];
            [pAvgBed setLineWidth:hist->avgBedWidth];
            [pAvgBed stroke];
        }
        if(pBed) {
            [hist->bedColor set];
            [pBed setLineWidth:hist->bedWidth];
            [pBed stroke];
        }
    } else {
        NSBezierPath *pOut = nil;
        NSBezierPath *pAvgOut = nil;
        pOut = [NSBezierPath bezierPath];
        if(hist->showAverage)
            pAvgOut = [NSBezierPath bezierPath];

        float xp=0;
        for(TempertureEntry *e in hist->currentHistory->entries) {
            if(e->time<lefttime-1) continue;
            xp = xleft+(e->time-lefttime)*timeScale;
            if(pOut && e->output>=0) {
                float yp=(float)e->output/255*(ytop-ybot)+ybot;
                if(pOut.isEmpty) {
                    [pOut moveToPoint:NSMakePoint(xp, ybot)];
                    [pOut lineToPoint:NSMakePoint(xp, yp)];
                }
                else
                    [pOut lineToPoint:NSMakePoint(xp, yp)];
            }
            if(pAvgOut && e->avgOutput>=0) {
                float yp=(float)e->avgOutput/255*(ytop-ybot)+ybot;
                if(pAvgOut.isEmpty)
                    [pAvgOut moveToPoint:NSMakePoint(xp, yp)];
                else
                    [pAvgOut lineToPoint:NSMakePoint(xp, yp)];
            }
            if(e->time>righttime) break;
        }
        if(!pOut.isEmpty) {
            [pOut lineToPoint:NSMakePoint(xp, ybot)];
            [pOut closePath];
        }
        if(pOut) {
            [hist->outputColor set];
            //[pOut setLineWidth:2];
            [pOut fill];
        }
        if(pAvgOut) {
            [hist->avgOutputColor set];
            [pAvgOut setLineWidth:hist->avgOutputWidth];
            [pAvgOut stroke];
        }

    }
    [theContext restoreGraphicsState];
}
- (void)drawRect:(NSRect)dirtyRect
{
    if(hist == nil) return;
    NSRect bounds = [self bounds];
    float height = NSHeight(bounds);
    float width = NSWidth(bounds);
    float fontLeft = tempWidth+tickExtra+spaceExtra+5;
    float fontBottom = timeHeight+tickExtra+3;
    float marginTop = 5;
    [hist->backgroundColor set];
    [NSBezierPath fillRect:bounds];
    double timespan = [[hist->zoomLevel objectAtIndex:hist->currentZoomLevel] doubleValue];
    if(hist->autoscoll)
        hist->xpos = 100.0;
    righttime = (hist->currentHistory->maxTime)-(3600-timespan)*0.01*(100.0-hist->xpos);
    lefttime = righttime-timespan;
    NSRect outputRect,tempRect;
    minTemp = 0;maxTemp = 300;
    BOOL hasTemp = NO;
#define INCLUDETEMP(a) {if(a>=0) {if(!hasTemp) {minTemp = maxTemp = a;hasTemp=YES;} else {minTemp=MIN(a,minTemp);maxTemp=MAX(a,maxTemp);}}}
    for(TempertureEntry *e in hist->currentHistory->entries) {
        if(e->time<lefttime || e->time>righttime) continue;
        if(hist->showExtruder) {
            INCLUDETEMP(e->extruder);
            if(hist->showAverage)
                INCLUDETEMP(e->avgExtruder);
            if(hist->showTarget)
                INCLUDETEMP(e->targetExtruder);
        }
        if(hist->showBed) {
            INCLUDETEMP(e->bed);
            if(hist->showAverage)
                INCLUDETEMP(e->avgBed);
            if(hist->showTarget)
                INCLUDETEMP(e->targetBed);
        }
    }
    maxTemp+=4;
    minTemp-=4;
    maxTemp = ceil(maxTemp/10.0)*10.0;
    minTemp = floor(minTemp/10.0)*10.0;
    if(minTemp<0) minTemp = 0;
    int i;
    if(hist->showOutput && height>4*(fontBottom+marginTop)) {
        float h1 = 0.75*height;
        float h2 = 0.25*height;
        tempRect=  NSMakeRect(fontLeft, h2+fontBottom,width-2*fontLeft , h1-fontBottom-marginTop);
        outputRect=  NSMakeRect(fontLeft, fontBottom,width-2*fontLeft , h2-fontBottom-marginTop);
        outScale = 255.0/(h2-fontBottom-marginTop);
    } else {
        tempRect=  NSMakeRect(fontLeft, fontBottom,width-2*fontLeft , height-fontBottom-marginTop);
    }
    double theight = NSHeight(tempRect);
    tempScale = theight/(maxTemp-minTemp);
    int best = 0;
    for(i=0;i<7;i++) {
        double dist = tempScale*tempTickSizes[i];
        if(dist>20) best = i;
    }
    tempTick = tempTickSizes[best];
    best = 0;
    double twidth = NSWidth(tempRect);
    timeScale = twidth/timespan;
    for(i=0;i<9;i++) {
        double dist = timeScale*timeTickSizes[i];
        if(dist>40) best = i;
    }
    timeTick = timeTickSizes[best];
    [self drawGrid:tempRect temp:YES];
    if(hist->showOutput && height>4*(fontBottom+marginTop)) {
        [self drawGrid:outputRect temp:NO];
    }
}

@end
