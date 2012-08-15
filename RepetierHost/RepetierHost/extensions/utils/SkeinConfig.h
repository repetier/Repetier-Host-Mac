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


#import <Foundation/Foundation.h>

@interface SkeinConfig : NSObject {
    NSMutableArray *lines;
    NSMutableArray *orig;
    NSString *path;
    BOOL exists;
}
@property (retain)NSMutableArray *lines;
@property (retain)NSMutableArray *orig;
@property (retain)NSString *path;

-(id)initWithPath:(NSString*) _path;
-(void)writeModified;
-(void)writeOriginal;
-(int)lineForKey:(NSString*)key;
-(NSString*)getValue:(NSString*)key;
-(void)setValue:(NSString*)val key:(NSString*)key;

@end
