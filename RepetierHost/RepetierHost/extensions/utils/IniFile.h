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

@interface IniSection : NSObject {
    NSString *name;
    NSMutableDictionary *entries;
}
@property (retain)NSString *name;
@property (retain)NSMutableDictionary *entries;

-(id)initWithName:(NSString*)_name;
@end

@interface IniFile : NSObject {
    NSString *path;
    NSMutableDictionary *sections;
}
@property (retain)NSString *path;
@property (retain)NSMutableDictionary *sections;

-(id)init;
-(void)read:(NSString*)_path;
-(void)add:(IniFile*)f;
-(void)flatten;
-(void)write:(NSString*)_path;

@end
