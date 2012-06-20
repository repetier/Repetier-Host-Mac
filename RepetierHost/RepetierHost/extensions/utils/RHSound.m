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

#import "RHSound.h"

@implementation RHSound

@synthesize soundFinished;
@synthesize soundPaused;
@synthesize soundError;
@synthesize soundCommand = soundCommand;

+(void)createSounds {
    sound = [RHSound new];
}
-(id)init {
    self = [super init];
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d addObserver:self forKeyPath:@"soundPrintjobFinished" options:NSKeyValueObservingOptionNew context:NULL];
    [d addObserver:self forKeyPath:@"soundPrintjobPaused" options:NSKeyValueObservingOptionNew context:NULL];
    [d addObserver:self forKeyPath:@"soundError" options:NSKeyValueObservingOptionNew context:NULL];
    [d addObserver:self forKeyPath:@"soundCommand" options:NSKeyValueObservingOptionNew context:NULL];
    NSFileManager *m = [NSFileManager defaultManager];
    NSString *path = [d objectForKey:@"soundPrintjobFinished"];
    if([m fileExistsAtPath:path]) {
        self.soundFinished = [[[NSSound alloc] initWithContentsOfFile:path byReference:YES] autorelease];
    }
    path = [d objectForKey:@"soundPrintjobPaused"];
    if([m fileExistsAtPath:path]) {
        self.soundPaused = [[[NSSound alloc] initWithContentsOfFile:path byReference:YES] autorelease];
    }
    path = [d objectForKey:@"soundError"];
    if([m fileExistsAtPath:path]) {
        self.soundError = [[[NSSound alloc] initWithContentsOfFile:path byReference:YES] autorelease];
    }
    path = [d objectForKey:@"soundCommand"];
    if([m fileExistsAtPath:path]) {
        self.soundCommand = [[[NSSound alloc] initWithContentsOfFile:path byReference:YES] autorelease];
    }
    
    return self;
}
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    //NSLog(@"Key changed:%@",keyPath);
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSFileManager *m = [NSFileManager defaultManager];
    NSSound *nextSound = nil;
    NSString *path = [d objectForKey:keyPath];
    if([m fileExistsAtPath:path]) {
        nextSound = [[[NSSound alloc] initWithContentsOfFile:path byReference:YES] autorelease];
    }
    if ([keyPath isEqual:@"soundPrintjobFinished"]) {
        self.soundFinished = nextSound;
    }
    if ([keyPath isEqual:@"soundPrintjobPaused"]) {
        self.soundPaused = nextSound;
    }
    if ([keyPath isEqual:@"soundError"]) {
        self.soundError = nextSound;
    }
    if ([keyPath isEqual:@"soundCommand"]) {
        self.soundCommand = nextSound;
    }
}
-(void)playPrintjobFinished:(BOOL)force {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    BOOL play = [d boolForKey:@"soundPrintjobFinishedEnabled"];
    if(soundFinished!=nil && (play || force) && !soundFinished.isPlaying) {
        [soundFinished play];
    }
}
-(void)playPrintjobPaused:(BOOL)force {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    BOOL play = [d boolForKey:@"soundPrintjobPausedEnabled"];
    if(soundPaused!=nil && (play || force) && !soundPaused.isPlaying) {
        [soundPaused play];
    }
}
-(void)playError:(BOOL)force {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    BOOL play = [d boolForKey:@"soundErrorEnabled"];
    if(soundError!=nil && (play || force) && !soundError.isPlaying) {
        [soundError play];
    }
}
-(void)playCommand:(BOOL)force {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    BOOL play = [d boolForKey:@"soundCommandEnabled"];
    if(soundCommand!=nil && (play || force) && !soundCommand.isPlaying) {
        [soundCommand play];
    }    
}

@end
RHSound *sound;
