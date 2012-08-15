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


#import "RHSlicer.h"
#import "../RHAppDelegate.h"
#import "STLComposer.h"

@implementation RHSlicer
@synthesize killButton;
@synthesize view;
@synthesize slic3rActive;
@synthesize skeinforgeActive;
@synthesize slic3rPrintSettings;
@synthesize slic3rFilamentSettings;
@synthesize slic3rPrinterSettings;
@synthesize skeinforgeProfile;
@synthesize slic3rFilamentList;
@synthesize slic3rPrinterList;
@synthesize slic3rPrintList;
@synthesize skeinforgeProfileList;
@synthesize runSlice;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        if ([NSBundle loadNibNamed:@"Slicer" owner:self])
        {
            self.slic3rPrintList = [[NSMutableArray new] autorelease];
            self.slic3rPrinterList = [[NSMutableArray new] autorelease];
            self.slic3rFilamentList = [[NSMutableArray new] autorelease];
            self.skeinforgeProfileList = [[NSMutableArray new] autorelease];
            [self updateSelections];
            [view setFrame:[self bounds]];
            [self addSubview:view];
        }
    }
    
    return self;
}
-(void)updateSelections {
    NSString *cdir = [RHSlicer slic3rConfigDir];
    NSString* file;
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSString *oldFilament = [d objectForKey:@"slic3rFilament"];
    NSString *oldPrint = [d objectForKey:@"slic3rPrint"];
    NSString *oldPrinter = [d objectForKey:@"slic3rPrinter"];
    NSString *oldProfile = [d objectForKey:@"skeinforgeSelectedProfile"];
    // Filament list
    NSDirectoryEnumerator* enumerator = [[NSFileManager defaultManager] enumeratorAtPath:[NSString stringWithFormat:@"%@/filament",cdir]];
    [slic3rFilamentList removeAllObjects];
    while (file = [enumerator nextObject])
    {
        // check if it's a directory
        BOOL isDirectory = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/filament/%@",cdir,file] isDirectory: &isDirectory];
        if (!isDirectory)
        {
            [slic3rFilamentList addObject:[file stringByDeletingPathExtension]];
        }
    }
    [slic3rFilamentSettings removeAllItems];
    [slic3rFilamentSettings addItemsWithTitles:slic3rFilamentList];
    // Print list
    enumerator = [[NSFileManager defaultManager] enumeratorAtPath:[NSString stringWithFormat:@"%@/print",cdir]];
    [slic3rPrintList removeAllObjects];
    while (file = [enumerator nextObject])
    {
        // check if it's a directory
        BOOL isDirectory = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/print/%@",cdir,file] isDirectory: &isDirectory];
        if (!isDirectory)
        {
            [slic3rPrintList addObject:[file stringByDeletingPathExtension]];
        }
    }
    [slic3rPrintSettings removeAllItems];
    [slic3rPrintSettings addItemsWithTitles:slic3rPrintList];
    // Printer list
    enumerator = [[NSFileManager defaultManager] enumeratorAtPath:[NSString stringWithFormat:@"%@/printer",cdir]];
    [slic3rPrinterList removeAllObjects];
    while (file = [enumerator nextObject])
    {
        // check if it's a directory
        BOOL isDirectory = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/printer/%@",cdir,file] isDirectory: &isDirectory];
        if (!isDirectory)
        {
            [slic3rPrinterList addObject:[file stringByDeletingPathExtension]];
        }
    }
    [slic3rPrinterSettings removeAllItems];
    [slic3rPrinterSettings addItemsWithTitles:slic3rPrinterList];

    // Skeinforge profiles list
    NSString *prof = [d stringForKey:@"skeinforgeProfiles"];
    enumerator = [[NSFileManager defaultManager] enumeratorAtPath:[NSString stringWithFormat:@"%@/extrusion",prof]];
    [skeinforgeProfileList removeAllObjects];
    while (file = [enumerator nextObject])
    {
        // check if it's a directory
        BOOL isDirectory = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/extrusion/%@",prof,file] isDirectory: &isDirectory];
        if (isDirectory)
        {
            [skeinforgeProfileList addObject:file];
        }
    }
    [skeinforgeProfile removeAllItems];
    [skeinforgeProfile addItemsWithTitles:skeinforgeProfileList];

    if(oldFilament==nil && slic3rFilamentList.count>0)
        oldFilament = [slic3rFilamentList objectAtIndex:0];
    if(oldFilament) {
        [d setObject:oldFilament forKey:@"slic3rFilament"];
        [slic3rFilamentSettings selectItemWithTitle:oldFilament];
    }
    if(oldPrint==nil && slic3rPrintList.count>0)
        oldPrint = [slic3rPrintList objectAtIndex:0];
    if(oldPrint) {
        [d setObject:oldPrint forKey:@"slic3rPrint"];
        [slic3rPrintSettings selectItemWithTitle:oldPrint];
    }
    if(oldPrinter==nil && slic3rPrinterList.count>0)
        oldPrinter = [slic3rPrinterList objectAtIndex:0];
    if(oldPrinter) {
        [d setObject:oldPrinter forKey:@"slic3rPrinter"];
        [slic3rPrinterSettings selectItemWithTitle:oldPrinter];
    }
    if(oldProfile==nil && skeinforgeProfileList.count>0)
        oldProfile = [skeinforgeProfileList objectAtIndex:0];
    if(oldProfile) {
        [d setObject:oldProfile forKey:@"skeinforgeSelectedProfile"];
        [skeinforgeProfile selectItemWithTitle:oldProfile];
    }
}

- (IBAction)sliceAction:(id)sender {
    [app->composer generateGCode:nil];
}
- (void)drawRect:(NSRect)dirtyRect
{
    // Drawing code here.
}

- (IBAction)configureSlic3rAction:(id)sender {
    [app->slicer configSlic3r:nil];
}

- (IBAction)configureSkeinforgeAction:(id)sender {
    [app->slicer runSkeinforge:nil];
}

- (IBAction)selectSlic3rAction:(id)sender {
    [app->slicer activateSlic3rInternal:nil];
}

- (IBAction)selectSkeinforgeAction:(id)sender {
    [app->slicer activateSkeinforge:nil];
}

- (IBAction)killAction:(id)sender {
    [app->slicer killSlicing];
}
+(NSString*)slic3rConfigDir {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *userpath = [paths objectAtIndex:0];
    userpath = [userpath stringByAppendingPathComponent:@"Slic3r"];
    return userpath;
}
@end
