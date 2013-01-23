//
//  ClickableTextField.m
//  RepetierHost
//
//  Created by Roland Littwin on 23.01.13.
//  Copyright (c) 2013 Repetier. All rights reserved.
//

#import "ClickableTextField.h"

@implementation ClickableTextField

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}
- (void)mouseDown:(NSEvent *)theEvent
{
    [self sendAction:[self action] to:[self target]];
}

@end
