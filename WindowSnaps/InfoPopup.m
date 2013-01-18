//
//  InfoPopup.m
//  WindowSnaps
//
//  Created by Jeremy Bridon on 1/17/13.
//  Copyright (c) 2013 Jeremy Bridon. All rights reserved.
//

#import "InfoPopup.h"

@interface InfoPopup ()

@end

@implementation InfoPopup

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

-(IBAction)CoreS2Clicked:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.cores2.com/"]];
}

-(IBAction)GitHubClicked:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/nint22/WindowSnaps"]];
}

@end
