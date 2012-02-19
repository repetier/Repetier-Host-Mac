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

#import "SDCardManager.h"
#import "PrinterConnection.h"
#import "StringUtil.h"
#import "RHAppDelegate.h"
#import "GCodeEditorController.h"
#import "GCodeView.h"

@implementation SDCardFile

-(id)initFile:(NSString*)fname size:(int)sz {
    if((self=[super init])) {
        filename = [fname retain];
        filesize = sz;
    }
    return self;
}
-(void)dealloc {
    [filename release];
    [super dealloc];
}
@end
@implementation SDCardManager

- (id) init {
    if(self = [super initWithWindowNibName:@"SDCard" owner:self]) {
        //  NSLog(@"Window is %l",self.window);
        //[self.window setReleasedWhenClosed:NO];
    }
    return self;
}

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        files = [RHLinkedList new];
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    mainWindow = self.window;
    files = [RHLinkedList new];
    mounted = YES;
    printing = NO;
    printPaused = NO;
    uploading = NO;
    readFilenames = NO;
    updateFilenames = NO;
    startPrint = NO;
    printWait = 0;
    waitDelete = 0;
    timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self
                                           selector:@selector(timerTick:) userInfo:self repeats:YES];
    openPanel = [[NSOpenPanel openPanel] retain];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setAllowsMultipleSelection:NO];
    [self refreshFilenames];
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newParam:) name:@"RHEepromAdded" object:nil];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}
-(void)dealloc {
    [timer invalidate];
    [files release];
    [super dealloc];
}
- (BOOL)windowShouldClose:(id)sender {
    [mainWindow orderOut:self];
    return NO;
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    return files->count;
}
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)col row:(NSInteger)rowIndex {
    if(col==filenameColumn)
        return ((SDCardFile*)[files objectAtIndex:(int)rowIndex])->filename;
    return [NSString stringWithFormat:@"%d",((SDCardFile*)[files objectAtIndex:(int)rowIndex])->filesize];
}
- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode
        contextInfo:(void *)contextInfo {
    
}
-(void)showInfo:(NSString*)warn headline:(NSString*)head {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:head];
    [alert setInformativeText:warn];
    [alert setAlertStyle:NSInformationalAlertStyle];
    [alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}
-(void)showError:(NSString*)warn headline:(NSString*)head {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:head];
    [alert setInformativeText:warn];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}
-(void)showErrorUpload:(NSString*)warn headline:(NSString*)head {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:head];
    [alert setInformativeText:warn];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert beginSheetModalForWindow:uploadPanel modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

-(void)updateButtons
{
    if (!connection->connected)
    {
        [uploadButton setTag:NO];
        [removeButton setTag:NO];
        [unmountButton setTag:NO];
        [mountButton setTag:NO];
        [startPrintButton setTag:NO];
        [stopPrintButton setTag:NO];
        return;
    }
    if (uploading || printing || [connection->job hasData])
    {
        [uploadButton setTag:NO];
        [removeButton setTag:NO];
        [unmountButton setTag:NO];
        [mountButton setTag:NO];
        [startPrintButton setTag:NO];
        [stopPrintButton setTag:mounted];
    }
    else
    {
        BOOL fc = [table selectedRow]!=NSNotFound;
        [uploadButton setTag:mounted];
        [removeButton setTag:fc && mounted];
        [unmountButton setTag:YES];
        [mountButton setTag:YES];
        [startPrintButton setTag:(fc || printPaused) && mounted];
        [stopPrintButton setTag:printPaused && mounted];
    }
    
}
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    [self updateButtons];
}
-(NSString*)reduceSpace:(NSString*)a
{
    NSMutableString *b = [NSMutableString stringWithCapacity:a.length];
    char lastc = 'X';
    for (int i=0;i<a.length;i++)
    {
        char c = [a characterAtIndex:i];
        if (c != lastc || c != ' ')
            [b appendString:[a substringWithRange:NSMakeRange(i,1)]];
        lastc = c;
    }
    return b;
}
-(void)analyze:(NSString*)res
{
    if (readFilenames)
    {
        if([res rangeOfString:@"End file list"].location==0) {
            readFilenames = NO;
            return;
        }
        NSString *s = [res stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        s = [[self reduceSpace:s] lowercaseString];
        NSArray *parts = [StringUtil explode:s sep:@" "];
        int len = 0;
        if(parts.count>1) len = [[parts objectAtIndex:1] intValue];
        SDCardFile *sdf = [[SDCardFile alloc] initFile:[parts objectAtIndex:0] size:len];
        [files addLast:sdf];
        [sdf release];
        [table reloadData];
        return;
    }
    if([res rangeOfString:@"Begin file list"].location==0) {
        readFilenames = YES;
        [files clear];
        return;
    }
    // Printing done?
    if ([res rangeOfString:@"Not SD printing"].location != NSNotFound || [res rangeOfString:@"Done printing file"].location!=NSNotFound)
    {
        printing = NO;
        [printStatus setStringValue:@"Print finished"];
        [progressBar setDoubleValue:100];
    }
    else if ([res rangeOfString:@"SD printing byte "].location != NSNotFound) // Print status update
    {
        NSRange p = [res rangeOfString:@"SD printing byte "];
        NSString *s = [res substringFromIndex:p.location+17];
        NSArray *s2 = [StringUtil explode:s sep:@"/"];
        if (s2.count == 2)
        {
            double a, b;
            a = [[s2 objectAtIndex:0] doubleValue];
            b = [[s2 objectAtIndex:1] doubleValue];
            [progressBar setDoubleValue:(100 * a / b)];
        }
    }
    else if ([res rangeOfString:@"SD init fail"].location != NSNotFound || [res rangeOfString:@"volume.init failed"].location != NSNotFound ||
             [res rangeOfString:@"openRoot failed"].location!=NSNotFound) // mount failed
    {
        mounted = NO;
    }
    else if ([res rangeOfString:@"error writing to file"].location != NSNotFound) // write error
    {
        [connection->job killJob];
    }
    else if ([res rangeOfString:@"Done saving file"].location != NSNotFound) // save finished
    {
        uploading = NO;
        [progressBar setDoubleValue:100];
        [printStatus setStringValue:@"Upload finished."];
        updateFilenames = YES;
    }
    else if ([res rangeOfString:@"File selected"].location != NSNotFound)
    {
        [printStatus setStringValue:@"SD printing ..."];
        [progressBar setDoubleValue:0];
        printing = YES;
        printPaused = NO;
        startPrint = YES;
    }
    else if (uploading && [res rangeOfString:@"open failed, File"].location!=NSNotFound)
    {
        [connection->job killJob];
        connection->analyzer->uploading = NO;
        [printStatus setStringValue:@"Upload failed."];
    }
    else if ([res rangeOfString:@"File deleted"].location!=NSNotFound)
    {
        waitDelete = 0;
        [printStatus setStringValue:@"File deleted"];
        updateFilenames = YES;
    }
    else if ([res rangeOfString:@"Deletion failed"].location!=NSNotFound)
    {
        waitDelete = 0;
        [printStatus setStringValue:@"Delete failed"];
    }
}
-(void)timerTick:(NSTimer*)timer
{
    if (printing && printWait == 0)
    {
        printWait = 2;
        if(![connection hasInjectedMCommand:27])
            [connection injectManualCommand:@"M27"];
    }
    if (printWait <= 0) printWait = 2;
    if (uploading)
    {
        [progressBar setDoubleValue:connection->job.percentDone];
    }
    printWait--;
    if (updateFilenames) [self refreshFilenames];
    if (startPrint)
    {
        startPrint = false;
        [connection injectManualCommand:@"M24"];
    }
    if (waitDelete > 0)
    {
        if (--waitDelete == 0)
        {
            [self showInfo:@"Your firmware doesn't implement file delete or has an unknown implementation." headline:@"Error"];
        }
    }
    [self updateButtons];
}
-(void)refreshFilenames {
    updateFilenames = false;
    [connection injectManualCommand:@"M20"];
    
}
- (void)sdAddDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode
        contextInfo:(void *)contextInfo {
    
}
- (IBAction)uploadAction:(id)sender {
    if ([connection->job hasData])
    {
        [self updateButtons];
        return;
    }
    [NSApp beginSheet: uploadPanel
       modalForWindow: mainWindow
        modalDelegate: self
       didEndSelector: @selector(sdAddDidEnd:returnCode:contextInfo:)
          contextInfo: nil];
}
- (void)removeDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode
        contextInfo:(void *)contextInfo {
    if(returnCode==NSAlertFirstButtonReturn) {
        NSString *fname = ((SDCardFile*)[files objectAtIndex:(int)table.selectedRow])->filename;
        waitDelete = 6;
        [connection injectManualCommand:[NSString stringWithFormat:@"M30 %@",fname]];
    }
}
- (IBAction)removeAction:(id)sender {
    if (table.selectedRow<0) return;
    NSString *fname = ((SDCardFile*)[files objectAtIndex:(int)table.selectedRow])->filename;
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"Yes"];
    [alert addButtonWithTitle:@"No"];
    [alert setMessageText:[NSString stringWithFormat:@"Really delete %@",fname]];
    [alert setInformativeText:@"Security question"];
    [alert setAlertStyle:NSInformationalAlertStyle];
    [alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(removeDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)startPrintAction:(id)sender {
    if (printPaused)
    {
        [printStatus setStringValue:@"SD printing ..."];
        printing = YES;
        printPaused = NO;
        [connection injectManualCommand:@"M24"];
        return;
    }
    int idx = (int)table.selectedRow;
    if(idx<0 || idx>=files->count) return;
    SDCardFile *v = [files objectAtIndex:idx];
    [connection injectManualCommand:[NSString stringWithFormat:@"M23 %@",v->filename]];
 }

- (IBAction)stopPrintAction:(id)sender {
    if (printPaused)
    {
        printPaused = NO;
        [printStatus setStringValue:@"Print aborted"];
        return;
    }
    [connection injectManualCommand:@"M25"];
    printPaused = YES;
    printing = NO;
    [printStatus setStringValue:@"Print paused"];
}

- (IBAction)mountAction:(id)sender {
    [connection injectManualCommand:@"M21"];
    mounted = YES;
    [self refreshFilenames];
}

- (IBAction)unmountAction:(id)sender {
    [connection injectManualCommand:@"M22"];
    mounted = NO;
    [self showInfo:@"You can remove the sd card." headline:@"Information"];
}
-(BOOL)validFilename:(NSString*)t
{
    BOOL ok = YES;
    //box.Text = box.Text.ToLower();
    if (t.length > 12 || t.length == 0) ok = NO;
    NSRange p = [t rangeOfString:@"."];
    if (p.location!=NSNotFound && p.location>8) ok = NO;
        
    int i;
    for (i = 0; i < t.length; i++)
    {
        if (i == p.location) continue;
        char c = [t characterAtIndex:i];
        BOOL cok = NO;
        if (c >= '0' && c <= '9') cok = YES;
        else if (c >= 'a' && c <= 'z') cok = YES;
        else if (c == '_') cok = YES;
        if (!cok)
        {
            ok = NO;
            break;
        }
    }
    if(!ok)
        [self showErrorUpload:@"Target name is not a valid 8.3 filename. Only 0-9, a-z and _ are allowed." headline:@"Wrong target filename"];
    return ok;
}
- (IBAction)uplBrowseExternalFile:(id)sender {
    [openPanel setMessage:@"Select gcode file for upload"];
    [openPanel beginSheetModalForWindow:uploadPanel completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSArray* urls = [openPanel URLs];
            if(urls.count>0) {
                NSURL *url = [urls objectAtIndex:0];
                [uplExternalFilenameText setStringValue:url.path];
            }
        }        
    }];
}
-(BOOL)upload:(int)source {
    if(![self validFilename:uplFilenameText.stringValue]) return NO;
    RHPrintjob *job = connection->job;
    [printStatus setStringValue:@"Uploading file ..."];
    [progressBar setIndeterminate:NO];
    [progressBar setDoubleValue:0];
    [job beginJob];
    job->exclusive = YES;
    [job pushData:[@"M28 " stringByAppendingString:[uplFilenameText stringValue]]];
    if([uplIncludeStartEndCheckbox state])
        [job pushData:[app->gcodeView getContent:1]];
    if (source==0)
    {
        [job pushData:[app->gcodeView getContent:0]];
    }
    else
    {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *path = uplExternalFilenameText.stringValue;
        BOOL fileExists = [fm fileExistsAtPath:path] ;
        if (!fileExists) {
            job->exclusive = NO;
            [job beginJob];
            [job endJob ];
            [self showErrorUpload:@"File not found." headline:@"Error"];
            return NO;
        }
        NSError *err = nil;
        [job pushData:[NSString stringWithContentsOfFile:path encoding:NSISOLatin1StringEncoding error:&err]];
        if(err && err.code) {
            job->exclusive = NO;
            [job beginJob];
            [job endJob ];
            [self showErrorUpload:@"Error loading file." headline:@"Error"];
            return NO;
        }
    }
    if ([uplIncludeStartEndCheckbox state])
        [job pushData:[app->gcodeView getContent:2]];
    if ([uplIncludeJobEndCheckbox state])
    {
        if (currentPrinterConfiguration->afterJobDisableExtruder)
        {
            [job pushData:@"M104 S0"];
        }
        if (currentPrinterConfiguration->afterJobDisableHeatedBed)
             [job pushData:@"M140 S0"];
        if (currentPrinterConfiguration->afterJobGoDispose)
        {
            [job pushData:@"G90"];
            [job pushData:[NSString stringWithFormat:@"G1 X%.2f Y%.2f F%.2F",currentPrinterConfiguration->disposeX,currentPrinterConfiguration->disposeY,currentPrinterConfiguration->travelFeedrate]];
        }
    }
    [job pushData:@"M29"];
    [job endJob];
    uploading = YES;
    return YES;
}
- (IBAction)uplUploadGCodeAction:(id)sender {
    if(![self upload:0]) return;
    [NSApp endSheet:uploadPanel];
    [uploadPanel orderOut:self];
}

- (IBAction)uplUploadExternalFileAction:(id)sender {
    if(![self upload:1]) return;
    [NSApp endSheet:uploadPanel];
    [uploadPanel orderOut:self];
}

- (IBAction)uplCancelAction:(id)sender {
    [NSApp endSheet:uploadPanel];
    [uploadPanel orderOut:self];
}
@end
