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
#import "HistoryTextField.h"

@interface RHManualControl : NSView {
    @public
    IBOutlet NSView *view;
    IBOutlet NSButton *debugEchoButton;
    IBOutlet NSButton *debugInfoButton;
    IBOutlet NSButton *debugErrorButton;
    IBOutlet NSButton *debugDryRunButton;
    IBOutlet NSButton *powerButton;
    IBOutlet NSButton *sendButton;
    IBOutlet NSButton *xHomeButton;
    IBOutlet NSSegmentedControl *xMoveButtons;
    IBOutlet NSButton *yHomeButton;
    IBOutlet NSSegmentedControl *yMoveButtons;
    IBOutlet NSButton *zHomeButton;
    IBOutlet NSSegmentedControl *zMoveButtons;
    IBOutlet NSButton *homeAllButton;
    IBOutlet NSButton *goDumpAreaButton;
    IBOutlet NSButton *stopMotorButton;
    IBOutlet NSButton *fakeOkButton;
    IBOutlet NSButton *extruderOnButton;
    IBOutlet NSButton *extruderSetTempButton;
    IBOutlet NSButton *extruderReverseButton;
    IBOutlet NSButton *extruderExtrudeButton;
    IBOutlet NSButton *heatedBedOnButton;
    IBOutlet NSButton *heatedBedSetTempButton;
    IBOutlet NSButton *setHomeButton;
    IBOutlet NSButton *fanOnButton;
    IBOutlet NSSlider *fanSpeedSlider;
    IBOutlet NSSlider *extruderLengthSlider;
    IBOutlet NSSlider *extruderSpeedSlider;
    IBOutlet HistoryTextField *gcodeText;
    IBOutlet NSTextField *extruderTempText;
    IBOutlet NSTextField *heatedBedTempText;
    IBOutlet NSTextField *xLabel;
    IBOutlet NSTextField *yLabel;
    IBOutlet NSTextField *zLabel;
    IBOutlet NSTextField *extruderSpeedText;
    IBOutlet NSTextField *extrudeDistanceText;
    IBOutlet NSTextField *retractDistanceText;
    IBOutlet NSTextField *extruderTargetTempLabel;
    IBOutlet NSTextField *heatedBedTargetTempLabel;
    IBOutlet NSButton *retractExtruderButton;
    NSTimer *timer;
    float lastx,lasty,lastz;
    IBOutlet NSSlider *speedMultiplySlider;
    IBOutlet NSTextField *speedMultiplyLabel;
    BOOL dontsend;
}
-(void)updateConnectionStatus:(BOOL)c;

-(void)updatePrinterState;
- (void)timerTick:(NSTimer*)theTimer;
- (IBAction)debugEchoAction:(NSButton *)sender;
- (IBAction)debugInfoAction:(NSButton *)sender;
- (IBAction)debugErrorsAction:(NSButton *)sender;
- (IBAction)debugDryRunAction:(NSButton *)sender;
- (IBAction)speedMultiplyChanged:(id)sender;
- (IBAction)powerAction:(NSButton *)sender;
- (IBAction)sendAction:(NSButton *)sender;
- (IBAction)xHomeAction:(NSButton *)sender;
- (IBAction)yHomeAction:(NSButton *)sender;
- (IBAction)zHomeAction:(NSButton *)sender;
- (IBAction)xMoveAction:(NSSegmentedControl *)sender;
- (IBAction)yMoveAction:(NSSegmentedControl *)sender;
- (IBAction)zMoveAction:(NSSegmentedControl *)sender;
- (IBAction)homeAllAction:(NSButton *)sender;
- (IBAction)goDumpAreaAction:(NSButton *)sender;
- (IBAction)stopMotorAction:(NSButton *)sender;
- (IBAction)fakeOKAction:(NSButton *)sender;
- (IBAction)heatOnAction:(NSButton *)sender;
- (IBAction)extruderSetTempAction:(NSButton *)sender;
- (IBAction)extruderExtrudeAction:(NSButton *)sender;
- (IBAction)heatedBedOnAction:(NSButton *)sender;
- (IBAction)heatedBedSetTempAction:(NSButton *)sender;
- (IBAction)fanOnAction:(NSButton *)sender;
- (IBAction)fanSpeedChangedAction:(NSSlider *)sender;
- (IBAction)retractExtruderAction:(NSButton *)sender;
- (IBAction)setHomeAction:(id)sender;

-(void)sendDebug;

@end
