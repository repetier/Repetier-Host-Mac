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
#import "TemperatureView.h"

@interface RHTempertuareController : NSView {
    @public
     IBOutlet NSView *_view;
    IBOutlet TemperatureView *tempertureView;
    IBOutlet NSMenuItem *timerperiod60;
    IBOutlet NSMenuItem *timeperiod30;
    IBOutlet NSMenuItem *timeperiod15;
    IBOutlet NSMenuItem *timeperiod10;
    IBOutlet NSMenuItem *timeperiod5;
    IBOutlet NSMenuItem *timeperiod1;
    IBOutlet NSMenuItem *monitorExtruder1;
    IBOutlet NSMenuItem *monitorExtruder2;
    IBOutlet NSMenuItem *monitorHeatedBed;
    IBOutlet NSMenu *temperatureMenu;
    IBOutlet NSMenuItem *temperatureMenuItem;
    IBOutlet NSMenuItem *monitorMenuItem;
    IBOutlet NSMenuItem *average30;
    IBOutlet NSMenuItem *average60;
    IBOutlet NSMenuItem *average120;
    IBOutlet NSMenuItem *average300;
    IBOutlet NSMenu *timeperiodMenu;
    IBOutlet NSMenuItem *timeperiodMenuItem;
}
-(void)refresh;
-(void)updateCheckmarks;
-(void)connectionChanged:(NSNotification*)event;
- (IBAction)showExtruderAction:(id)sender;
- (IBAction)showHeatedBedAction:(id)sender;
- (IBAction)showTargetAction:(id)sender;
- (IBAction)showAverageAction:(id)sender;
- (IBAction)showOutputAction:(id)sender;
- (IBAction)autoscrollAction:(id)sender;
- (IBAction)setTimePeriodAction:(NSMenuItem *)sender;
- (IBAction)monitorDisableAction:(id)sender;
- (IBAction)monitorExtruder1Action:(id)sender;
- (IBAction)monitorExtruder2Action:(id)sender;
- (IBAction)monitorHeatedBedAction:(id)sender;
- (IBAction)setAverageAction:(NSMenuItem *)sender;
@end
