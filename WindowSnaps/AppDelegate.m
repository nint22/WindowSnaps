//
//  AppDelegate.m
//  WindowSnaps
//
//  Created by Jeremy Bridon on 1/15/13.
//  Copyright (c) 2013 Jeremy Bridon. All rights reserved.
//

#import "AppDelegate.h"
#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import <QuartzCore/QuartzCore.h>
#import <Carbon/Carbon.h>
#import "InfoPopup.h"

// Static callback for when a window is moved around
// When this was moved (i.e. the user releases the mouse) we need to check for input and change window size if necesary
void MyAXObserverCallback(AXObserverRef observer, AXUIElementRef element, CFStringRef notificationName, void* contextData)
{
    // Get global mouse position
    NSPoint MousePos = [NSEvent mouseLocation];
    
    // True if we should snap, and with what origin & size
    bool WillSnap = false;
    NSRect SnapRect = NSMakeRect(0, 0, 0, 0);
    
    // Get screen sizes
    // From: http://stackoverflow.com/questions/4982656/programmatically-get-screen-size-in-mac-os-x
    NSArray* ScreenArray = [NSScreen screens];
    
    // For each screen
    for(NSScreen* Screen in ScreenArray)
    {
        // What is the screen's rect?
        NSRect ScreenRect = [Screen visibleFrame];
        
        // Did the user attempt to snap-left?
        int LeftDx = ScreenRect.origin.x - MousePos.x;
        if(LeftDx >= 0 && LeftDx < 5) // 5 pixel buffer
        {
            // Window snapping to left!
            WillSnap = true;
            SnapRect = NSMakeRect(0, 0, ScreenRect.size.width / 2, ScreenRect.size.height);
            break;
        }
        
        // Did the user attempt to snap-right?
        int RightDx = (ScreenRect.origin.x + ScreenRect.size.width) - MousePos.x;
        if(RightDx <= 0 && RightDx > -5) // 5 pixel buffer
        {
            // Window snapping to right!
            WillSnap = true;
            SnapRect = NSMakeRect(ScreenRect.size.width / 2, 0, ScreenRect.size.width / 2, ScreenRect.size.height);
            break;
        }
        
        // Did the user attempt to snap to the top? (cursor moved up and the x is in the top 
        int TopDy = (ScreenRect.origin.y + ScreenRect.size.height) - MousePos.y;
        if(TopDy < 30) // 5 pixel buffer
        {
            // Window snapping to right!
            WillSnap = true;
            SnapRect = NSMakeRect(0, 0, ScreenRect.size.width, ScreenRect.size.height);
            break;
        }
    }
    
    // Snap if needed
    if(WillSnap)
    {
        AXValueRef NewOrigin = AXValueCreate(kAXValueCGPointType, &(SnapRect.origin));
        AXUIElementSetAttributeValue(element, kAXPositionAttribute, NewOrigin);
        
        AXValueRef NewSize = AXValueCreate(kAXValueCGSizeType, &(SnapRect.size));
        AXUIElementSetAttributeValue(element, kAXSizeAttribute, NewSize);
    }
}

@implementation AppDelegate

/*** Standard Delegate Functions ***/

- (void)dealloc
{
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
}


-(void)awakeFromNib
{
    [self Initialize];
}

-(void)InfoPressed
{
    // Instance our info window
    InfoPopup* Popup = [[InfoPopup alloc] initWithWindowNibName:@"InfoPopup"];
    [NSApp runModalForWindow: [Popup window]];
}

-(void)QuitPressed
{
    // Simple force-quit; nothing to clean-up as the OS takes care of our handles
    exit(0);
}

/*** Custom Code ***/

-(void)Initialize
{
    /*** Initialize GUI ***/
    
    // Initialize UI properties..
    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
    [statusItem setMenu:statusMenu];
    [statusItem setImage:[NSImage imageNamed:@"MainIcon.png"]];
    [statusItem setHighlightMode:YES];
    
    // Attach the info and exit event
    [statusMenu setAutoenablesItems:false];
    
    NSMenuItem* InfoItem = [statusMenu itemAtIndex:0];
    [InfoItem setAction:@selector(InfoPressed)];
    
    NSMenuItem* QuitItem = [statusMenu itemAtIndex:1];
    [QuitItem setAction:@selector(QuitPressed)];
    
    /*** Initialize Snapping ***/
    
    // Check first if we are authorized to use Assistance API
    bool IsAuthorized = [self IsAuthorized];
    
    // Give a pop-up if not authorized
    if(!IsAuthorized)
    {
        // Present and wait
        NSAlert* Popup = [NSAlert alertWithMessageText:@"Error: Accessibility not enabled" defaultButton:@"Quit Application" alternateButton:nil otherButton:nil informativeTextWithFormat:@"This application requires system-accessibility authorization. To do this, go to System Preferences, Universal Access, and make sure that \"Enable access for assistive devices\" is enabled."];
        [Popup runModal];
        
        // Simply force-quit!
        exit(0);
    }
    
    // Single-step update for the sake of testing
    // TODO: Instead of a constant query, let's ask the OS to get informed on every new app launch
    // By doing this, we can then use the current code to explicitly ask for any new window launches
    [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(CheckSnaps) userInfo:nil repeats:true];
}

- (void)CheckSnaps
{
    // Get all windows listed
    // Returns an array of CGWindowID types
    CFArrayRef WindowList = CGWindowListCreate(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    
    // Get description information for each window we found above
    // Returns an array of (possibly matchin) window description stuff...
    CFArrayRef DescriptionList = CGWindowListCreateDescriptionFromArray(WindowList);
    
    // For each graphical app (has a root window and more windows...)
    for(int i = 0; i < CFArrayGetCount(DescriptionList); i++)
    {
        // Pull out window description
        CFDictionaryRef WindowDict = CFArrayGetValueAtIndex(DescriptionList, i);
        CFNumberRef AppPID = CFDictionaryGetValue(WindowDict, kCGWindowOwnerPID);
        
        // Get the PID from the number
        int64_t PIDBuffer;
        CFNumberGetValue(AppPID, kCFNumberSInt64Type, &PIDBuffer);
        
        // Convert from 64 bit to actual PID type
        pid_t PID = (pid_t)PIDBuffer; // Isn't PID a hidden type / structure? i.e. it is unsafe to do this...
        
        // Get the app's base window controller
        AXUIElementRef ApplicationHandle = AXUIElementCreateApplication(PID);
        
        // Get active windows of this app
        CFArrayRef ApplicationWindowsList = NULL;
        AXUIElementCopyAttributeValue(ApplicationHandle, kAXWindowsAttribute, (CFTypeRef*)&ApplicationWindowsList);
        
        // If there are any windows...
        if(ApplicationWindowsList != NULL && CFArrayGetCount(ApplicationWindowsList) > 0)
        {
            // For each window..
            for(int j = 0; j < CFArrayGetCount(ApplicationWindowsList); j++)
            {
                // Get the window handle...
                __strong AXUIElementRef WindowHandle = CFArrayGetValueAtIndex(ApplicationWindowsList, j);
                
                // Documentation: http://stackoverflow.com/questions/853833/how-can-my-app-detect-a-change-to-another-apps-window
                
                // Create observer
                AXObserverRef ObserverHandle = NULL;
                AXObserverCreate(PID, MyAXObserverCallback, &ObserverHandle);
                
                // Attach observer to window in question (remove any we currently have)
                if(AXObserverAddNotification(ObserverHandle, WindowHandle, kAXWindowMovedNotification, (void*)self) == kAXErrorSuccess)
                {
                    // Now make async to not freeze up any other mechanisms
                    CFRunLoopAddSource([[NSRunLoop currentRunLoop] getCFRunLoop], AXObserverGetRunLoopSource(ObserverHandle), kCFRunLoopDefaultMode);
                }
            }
        }
    }
    
    // Done installing all handles
}

// Authorization check of Accessibility API
// From http://stackoverflow.com/questions/614185/window-move-and-resize-apis-in-os-x
-(bool)IsAuthorized
{
    // General system-level check
    if(AXAPIEnabled())
        return true;
    
    // Check if we are authorized
    if(AXIsProcessTrusted())
        return true;
    
    // Not authorized, move along...
    return false;
}

@end
