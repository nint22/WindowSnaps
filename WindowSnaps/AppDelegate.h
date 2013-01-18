//
//  AppDelegate.h
//  WindowSnaps
//
//  Created by Jeremy Bridon on 1/15/13.
//  Copyright (c) 2013 Jeremy Bridon. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    // Menu interface
    // Based on http://cocoatutorial.grapewave.com/2010/01/creating-a-status-bar-application/
    IBOutlet NSMenu* statusMenu;
    NSStatusItem* statusItem;
}

@end
