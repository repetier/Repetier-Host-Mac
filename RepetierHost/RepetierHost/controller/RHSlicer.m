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
#import "../models/PrinterConnection.h"
#import "../extensions/utils/IniFile.h"
#import "../extensions/utils/SkeinConfig.h"
#import "../extensions/utils/StringUtil.h"
#import "GCodeEditorController.h"

@implementation RHSlicer
@synthesize killButton;
@synthesize slic3rFilamentSettings3;
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
            [self slicerConfigToVariables];
        }
    }
    
    return self;
}
-(void)slicerConfigToVariables {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [connection.variables removeAllObjects];
    if([d integerForKey:@"activeSlicer"]==3) { // Skeinforge
        NSString *sdir = [d stringForKey:@"skeinforgeProfiles"];
        NSString *prof = [d stringForKey:@"skeinforgeSelectedProfile"];
        NSString *configDir = [NSString stringWithFormat:@"%@/extrusion/%@",sdir,prof];
        NSArray* enumerator = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:configDir error:nil];
        for (NSString *file in enumerator)
        {
            // check if it's a directory
            BOOL isDirectory = NO;
            [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@",configDir,file] isDirectory: &isDirectory];
            if (!isDirectory && [file.pathExtension compare:@"csv"]==NSOrderedSame)
            {
                SkeinConfig *sk = [[SkeinConfig alloc] initWithPath:[NSString stringWithFormat:@"%@/%@",configDir,file]];
                for(NSString *line in sk.orig) {
                    NSRange tab = [line rangeOfString:@"\t"];
                    if(tab.location==NSNotFound) continue;
                    NSString *var = [connection repairKey:[StringUtil trim:[line substringToIndex:tab.location]]];
                    NSString *val = [StringUtil trim:[line substringFromIndex:tab.location+1]];
                    [connection.variables setObject:val forKey:var];
                }
                [sk release];
            }
        }

    } else { // Slic3r
        NSString *sFilament = [d objectForKey:@"slic3rFilament"];
        NSString *sPrint = [d objectForKey:@"slic3rPrint"];
        NSString *sPrinter = [d objectForKey:@"slic3rPrinter"];
        NSString *cdir = [RHSlicer slic3rConfigDir];
        NSString *fPrinter = [NSString stringWithFormat:@"%@/print/%@.ini",cdir,sPrint];
        IniFile *ini = [[[IniFile alloc] init] autorelease];
        [ini read:fPrinter];
        IniFile *ini2 = [[[IniFile alloc] init] autorelease];
        [ini2 read:[NSString stringWithFormat:@"%@/printer/%@.ini",cdir,sPrinter]];
        IniFile *ini3 = [[[IniFile alloc] init] autorelease];
        [ini3 read:[NSString stringWithFormat:@"%@/filament/%@.ini",cdir,sFilament]];
        [ini flatten];
        [ini2 flatten];
        [ini3 flatten];
        [connection importVariablesFormDictionary:[[ini.sections objectForKey:@""] entries]];
        [connection importVariablesFormDictionary:[[ini2.sections objectForKey:@""] entries]];
        [connection importVariablesFormDictionary:[[ini3.sections objectForKey:@""] entries]];
    }
    if(app && app->gcodeView)
        [app->gcodeView->variablesTable.tableView reloadData];
}
-(void)updateSelections {
    NSString *cdir = [RHSlicer slic3rConfigDir];
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSString *oldFilament = [d objectForKey:@"slic3rFilament"];
    NSString *oldFilament2 = [d objectForKey:@"slic3rFilament2"];
    NSString *oldFilament3 = [d objectForKey:@"slic3rFilament3"];
    NSString *oldPrint = [d objectForKey:@"slic3rPrint"];
    NSString *oldPrinter = [d objectForKey:@"slic3rPrinter"];
    NSString *oldProfile = [d objectForKey:@"skeinforgeSelectedProfile"];
    // Filament list
    NSArray* enumerator = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/filament",cdir] error:nil];
    [slic3rFilamentList removeAllObjects];
    for (NSString *file in enumerator)
    {
        // check if it's a directory
        BOOL isDirectory = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/filament/%@",cdir,file] isDirectory: &isDirectory];
        if (!isDirectory && [file.pathExtension compare:@"ini"]==NSOrderedSame)
        {
            [slic3rFilamentList addObject:[file stringByDeletingPathExtension]];
        }
    }
    [slic3rFilamentSettings removeAllItems];
    [slic3rFilamentSettings addItemsWithTitles:slic3rFilamentList];
    [slic3rFilamentSettings2 removeAllItems];
    [slic3rFilamentSettings2 addItemsWithTitles:slic3rFilamentList];
    [slic3rFilamentSettings3 removeAllItems];
    [slic3rFilamentSettings3 addItemsWithTitles:slic3rFilamentList];
    // Print list
    enumerator = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/print",cdir] error:nil];
    [slic3rPrintList removeAllObjects];
    for (NSString *file in enumerator)
    {
        // check if it's a directory
        BOOL isDirectory = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/print/%@",cdir,file] isDirectory: &isDirectory];
        if (!isDirectory && [file.pathExtension compare:@"ini"]==NSOrderedSame)
        {
            [slic3rPrintList addObject:[file stringByDeletingPathExtension]];
        }
    }
    [slic3rPrintSettings removeAllItems];
    [slic3rPrintSettings addItemsWithTitles:slic3rPrintList];
    // Printer list
    enumerator = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/printer",cdir] error:nil];    [slic3rPrinterList removeAllObjects];
    for (NSString *file in enumerator)
    {
        // check if it's a directory
        BOOL isDirectory = NO;
        [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/printer/%@",cdir,file] isDirectory: &isDirectory];
        if (!isDirectory && [file.pathExtension compare:@"ini"]==NSOrderedSame)
        {
            [slic3rPrinterList addObject:[file stringByDeletingPathExtension]];
        }
    }
    [slic3rPrinterSettings removeAllItems];
    [slic3rPrinterSettings addItemsWithTitles:slic3rPrinterList];

    // Skeinforge profiles list
    NSString *prof = [d stringForKey:@"skeinforgeProfiles"];
    enumerator = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/extrusion",prof] error:nil];    [skeinforgeProfileList removeAllObjects];
    for (NSString *file in enumerator)
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
    if(oldFilament2==nil && slic3rFilamentList.count>0)
        oldFilament2 = [slic3rFilamentList objectAtIndex:0];
    if(oldFilament2) {
        [d setObject:oldFilament2 forKey:@"slic3rFilament2"];
        [slic3rFilamentSettings2 selectItemWithTitle:oldFilament2];
    }
    if(oldFilament3==nil && slic3rFilamentList.count>0)
        oldFilament3 = [slic3rFilamentList objectAtIndex:0];
    if(oldFilament3) {
        [d setObject:oldFilament3 forKey:@"slic3rFilament3"];
        [slic3rFilamentSettings3 selectItemWithTitle:oldFilament3];
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
    [self slicerConfigToVariables];
}

- (IBAction)selectSkeinforgeAction:(id)sender {
    [app->slicer activateSkeinforge:nil];
    [self slicerConfigToVariables];
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
