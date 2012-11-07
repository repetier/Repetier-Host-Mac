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


#import "RHTempertuareController.h"
#import "PrinterConnection.h"
#import "RHAppDelegate.h"
#import "TemperatureHistory.h"

@implementation RHTempertuareController

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if ([NSBundle loadNibNamed:@"TemperatureView" owner:self])
    {
        [_view setFrame:[self bounds]];
        [self addSubview:_view];
        tempertureView->hist = connection->tempHistory;
        [[NSNotificationCenter defaultCenter] addObserver:self                                             selector:@selector(connectionChanged:) name:@"RHConnectionOpen" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self                                             selector:@selector(connectionChanged:) name:@"RHConnectionClosed" object:nil];

    }
    return self;
}
-(void)awakeFromNib {
    [[NSApp mainMenu] insertItem:temperatureMenuItem atIndex:5];
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d addObserver:self forKeyPath:@"tempZoomLevel" options:NSKeyValueObservingOptionNew context:NULL];
    [d addObserver:self forKeyPath:@"tempAverageSeconds" options:NSKeyValueObservingOptionNew context:NULL];
    [tempertureView->hist initMenu];
    [self updateCheckmarks];
}
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    [self updateCheckmarks];
    [self refresh];
}
-(void)refresh {
    [tempertureView setNeedsDisplay:YES];
}
-(void)updateCheckmarks {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    int zoom = (int)[d integerForKey:@"tempZoomLevel"];
    [timerperiod60 setState:zoom==0];
    [timeperiod30 setState:zoom==1];
    [timeperiod15 setState:zoom==2];
    [timeperiod10 setState:zoom==3];
    [timeperiod5 setState:zoom==4];
    [timeperiod1 setState:zoom==5];
    [monitorExtruder1 setState:connection->analyzer->tempMonitor==0];
    [monitorExtruder2 setState:connection->analyzer->tempMonitor==1];
    [monitorHeatedBed setState:connection->analyzer->tempMonitor==100];
    [monitorMenuItem setEnabled:connection->connected];
    int avg = (int)[d integerForKey:@"tempAverageSeconds"];
    [average30 setState:avg==30];
    [average60 setState:avg==60];
    [average120 setState:avg==120];
    [average300 setState:avg==300];
}
-(void)connectionChanged:(NSNotification*)event {
    [self updateCheckmarks];
}
- (IBAction)showExtruderAction:(id)sender {
}

- (IBAction)showHeatedBedAction:(id)sender {
}

- (IBAction)showTargetAction:(id)sender {
}

- (IBAction)showAverageAction:(id)sender {
}

- (IBAction)showOutputAction:(id)sender {
}

- (IBAction)autoscrollAction:(id)sender {
}

- (IBAction)setTimePeriodAction:(NSMenuItem *)sender {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d setInteger:sender.tag forKey:@"tempZoomLevel"];
}
- (IBAction)selectPeriod:(NSMenuItem *)sender {
    int p = (int)(sender.tag);
    tempertureView->hist->currentHistory = [tempertureView->hist->lists objectAtIndex:p];
    [tempertureView setNeedsDisplay:YES];
}
- (IBAction)monitorDisableAction:(id)sender {
    if(connection->connected)
        [connection injectManualCommand:@"M203 S255"];
}

- (IBAction)monitorExtruder1Action:(id)sender {
    if(connection->connected)
        [connection injectManualCommand:@"M203 S0"];
}

- (IBAction)monitorExtruder2Action:(id)sender {
    if(connection->connected)
        [connection injectManualCommand:@"M203 S1"];
}

- (IBAction)monitorHeatedBedAction:(id)sender {
    if(connection->connected)
        [connection injectManualCommand:@"M203 S100"];
}

- (IBAction)setAverageAction:(NSMenuItem *)sender {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d setInteger:sender.tag forKey:@"tempAverageSeconds"];
}
@end
