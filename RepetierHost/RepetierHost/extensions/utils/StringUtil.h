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

@interface StringUtil : NSObject
+(NSMutableArray*)explode:(NSString*)text sep:(NSString*)c;
+(NSString*)implode:(NSArray*)list sep:(NSString*)c;
+(BOOL)string:(NSString*)text startsWith:(NSString*)comp;
+(NSString*)normalizeLineends:(NSString*)line;
+(NSString*)replaceIn:(NSString*)orig all:(NSString*)all with:(NSString*)with;
@end
