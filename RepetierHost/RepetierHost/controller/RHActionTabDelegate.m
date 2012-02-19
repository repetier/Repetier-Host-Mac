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

#import "RHActionTabDelegate.h"
#import "RHAppDelegate.h"
#import "ThreeDView.h"

@implementation RHActionTabDelegate

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem {
    if(tabViewItem==app->composerTab)
        view->act = app->stlView;
    else if(tabViewItem==app->printTab)
        view->act = app->printPreview;
    else if(tabViewItem==app->gcodeTab)
        view->act = app->codePreview;
    [app->openGLView redraw];
    [app->openGLView updateButtons];
}

@end
