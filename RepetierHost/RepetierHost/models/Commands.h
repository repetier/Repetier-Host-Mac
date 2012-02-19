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
#import "RHLinkedList.h"

@interface CommandParameter : NSObject {
@public
    BOOL optional;
    NSString *parameter;
    NSString *desc;
    
}
-(id)initWithNode:(NSXMLElement*)n;
-(NSString*)description;
@property (retain)NSString *parameter;
@property (retain)NSString *desc;
@end

@interface CommandDescription : NSObject {
@public
    NSString *command;
    NSString *title;
    RHLinkedList *parameter;
    NSString *desc; 
    NSAttributedString *attr;
}
-(id)initWithNode:(NSXMLElement*)n;
-(NSAttributedString*)attributedDescription;
@property (retain)NSString *desc;
@property (retain)NSString *command;
@property (retain)NSString *title;
@end

@interface Commands : NSObject {
@public
    NSMutableDictionary *commands;
}
-(void)readFirmware:(NSString*)firmware language:(NSString*) lang;
-(void)readFile:(NSString*)file;
@end

extern Commands *commands;