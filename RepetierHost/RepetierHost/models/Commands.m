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

#import "Commands.h"

Commands *commands=nil;

@implementation Commands
-(id)init {
    if((self=[super init])) {
        commands = [[NSMutableDictionary alloc] initWithCapacity:100];
    }
    return self;
}
-(void)dealloc {
    [commands release];
    [super dealloc];
}

-(void)readFirmware:(NSString*)firmware language:(NSString*) lang
{
    //RegistryKey repetierKey = Registry.CurrentUser.CreateSubKey("Software\\Repetier");
    
    //string basedir = (string)repetierKey.GetValue("installPath");
    NSString *defaultsyntax = [[NSBundle mainBundle] pathForResource:@"syntax" ofType:@"xml"];
    [self readFile:defaultsyntax];
/*    ReadFile(basedir + Path.DirectorySeparatorChar+"data"+Path.DirectorySeparatorChar+"default"+
             Path.DirectorySeparatorChar+"syntax_en.xml");
    if(lang.Equals("en")==false)
        ReadFile(basedir + Path.DirectorySeparatorChar+"data"+Path.DirectorySeparatorChar+"default"+
                 Path.DirectorySeparatorChar+"syntax_"+lang+".xml");
    if (firmware.Equals("default") == false)
    {
        ReadFile(basedir + Path.DirectorySeparatorChar+"data"+Path.DirectorySeparatorChar+firmware+
                 Path.DirectorySeparatorChar+"syntax_en.xml");
        if (lang.Equals("en") == false)
            ReadFile(basedir + Path.DirectorySeparatorChar+"data"+Path.DirectorySeparatorChar+firmware+
                     Path.DirectorySeparatorChar+"syntax_" + lang + ".xml");
    }*/
}
-(void)readFile:(NSString*) file
{
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL fileExists = [fm fileExistsAtPath:file] ;
    if (!fileExists) return;
    
    @try
    {
        NSXMLDocument *xmlDoc;
        NSError *err=nil;
        NSURL *furl = [NSURL fileURLWithPath:file];
        if (!furl) {
            NSLog(@"Can't create an URL from file %@.", file);
            return;
        }
        xmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL:furl
                                                      options:(NSXMLNodePreserveWhitespace|NSXMLNodePreserveCDATA)
                                                        error:&err];
        if (xmlDoc == nil) {
            xmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL:furl
                                                          options:NSXMLDocumentTidyXML
                                                            error:&err];
        }
        if (xmlDoc == nil)  {
            return;
        }
        NSArray *nodes = [xmlDoc nodesForXPath:@".//Command"
                                              error:&err];
        for (NSXMLElement * n in nodes) {
            CommandDescription *cd = [[CommandDescription alloc] initWithNode:n];
            [commands setValue:cd forKey:cd->command];
        }
    }
    @catch(NSException *e) { }
}

@end

@implementation CommandParameter
@synthesize parameter;
@synthesize desc;

-(id)initWithNode:(NSXMLElement*)n {
    if((self=[super init])) {
        optional = NO;
        [self setDesc:[n stringValue]];
        NSXMLNode *anode = [n attributeForName:@"name"];
        if(anode == nil)
            [self setParameter:@""];
        else
            [self setParameter:anode.stringValue];
        anode = [n attributeForName:@"optional"];
        if(anode!=nil)
            if ([anode.stringValue compare:@"1"]==NSOrderedSame) 
                optional = YES;
    }
    return self;
}
-(NSString*)description
{
   if (optional)
       return [[[[@"[" stringByAppendingString:parameter] stringByAppendingString:@"{<it>"] stringByAppendingString:desc] stringByAppendingString:@"</it>}] "];
    return [[[parameter stringByAppendingString:@"{<it>"] stringByAppendingString:desc] stringByAppendingString:@"</it>} "];
}
-(void)dealloc {
    [desc release];
    [parameter release];
    [super dealloc];
}
@end

@implementation CommandDescription

@synthesize desc;
@synthesize command;
@synthesize title;

-(id)initWithNode:(NSXMLElement*)n {
    if((self=[super init])) {
        parameter = [RHLinkedList new];
        [self setCommand:[n attributeForName:@"name"].stringValue];
        [self setTitle:[n attributeForName:@"title"].stringValue];
            for (NSXMLNode *pn in n.children)
            {
                if (pn.kind != NSXMLElementKind) continue;
                if ([pn.name compare:@"Param"]==NSOrderedSame) {
                    CommandParameter *lastparam = [[CommandParameter alloc] initWithNode:(NSXMLElement*)pn];
                    [parameter addLast:lastparam];
                    [lastparam release];
                }
                if ([pn.name compare:@"Description"]==NSOrderedSame)
                    [self setDesc:pn.stringValue];
            }
        attr = nil;
    }
    return self;
}
-(void)dealloc {
    [attr release];
    [command release];
    [desc release];
    [title release];
    [parameter release];
    [super dealloc];
}
-(NSAttributedString*)attributedDescription {
    if(attr!=nil) return attr;
    NSMutableString *s = [[NSMutableString alloc] init];
    [s appendString:@"<strong>"];
    [s appendString:command];
    [s appendString:@":"];
    [s appendString:title];
    [s appendString:@"</strong><br/>Syntax:"];
    [s appendString:command];
    [s appendString:@" "];
    for (CommandParameter *pa in parameter) {
      [s appendString:pa.description];
    }
    [s appendString:@"<br/>"];
    [s appendString:desc];
    NSData *fooData = [s dataUsingEncoding: NSUTF8StringEncoding];
    NSDictionary *at = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:NSUTF8StringEncoding],NSCharacterEncodingDocumentOption,nil];
    NSAttributedString *as = [[NSAttributedString alloc]
                              initWithHTML:fooData options:at documentAttributes:nil];
    attr = as; //[as retain];
    [s release];
    return attr;
}
@end    

