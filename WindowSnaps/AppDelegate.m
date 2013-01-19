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

// The top and side buffer size (based in pixels)
static const int SideBufferWidth = 5;
static const int TopBufferHeight = 10;

// The latest element that has been moved by the user; this is what we will use when we see a left-click release
static __strong AXUIElementRef LatestElement = NULL;

// The press down and move 

// Static callback for when a user releases the mouse button
CGEventRef MyCGEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon)
{
    // Get global mouse position
    CGPoint MousePos = CGEventGetLocation(event);
    
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
        if(LeftDx >= 0 && LeftDx < SideBufferWidth)
        {
            // Window snapping to left!
            WillSnap = true;
            SnapRect = NSMakeRect(0, 0, ScreenRect.size.width / 2, ScreenRect.size.height);
            break;
        }
        
        // Did the user attempt to snap-right?
        int RightDx = ScreenRect.size.width - MousePos.x;
        if(RightDx >= 0 && RightDx < SideBufferWidth)
        {
            // Window snapping to right!
            WillSnap = true;
            SnapRect = NSMakeRect(ScreenRect.size.width / 2, 0, ScreenRect.size.width / 2, ScreenRect.size.height);
            break;
        }
        
        // Did the user attempt to snap to the top? (cursor moved up and the x is in the top
        int TopDy = MousePos.y;
        if(TopDy < (TopBufferHeight + [[[NSApplication sharedApplication] mainMenu] menuBarHeight]))
        {
            // Window snapping to right!
            WillSnap = true;
            SnapRect = NSMakeRect(0, 0, ScreenRect.size.width, ScreenRect.size.height);
            break;
        }
    }
    
    // Snap if needed
    if(WillSnap && LatestElement != NULL)
    {
        AXValueRef NewOrigin = AXValueCreate(kAXValueCGPointType, &(SnapRect.origin));
        AXUIElementSetAttributeValue(LatestElement, kAXPositionAttribute, NewOrigin);
        
        AXValueRef NewSize = AXValueCreate(kAXValueCGSizeType, &(SnapRect.size));
        AXUIElementSetAttributeValue(LatestElement, kAXSizeAttribute, NewSize);
    }
    
    // Always release the latest element
    LatestElement = NULL;
    
    // Nothing else to do - return raw data (not that it matters; we tell the system we're just reading data)
    return event;
}

// Static callback for when a window is moved around
// When this was moved (i.e. the user releases the mouse) we need to check for input and change window size if necesary
void AXMCallback(AXObserverRef observer, AXUIElementRef element, CFStringRef notificationName, void* contextData)
{
    // Element was created
	if(CFStringCompare(notificationName, kAXWindowCreatedNotification, 0) == 0)
	{
        // Nothing to do here; registration is done through the update loop
	}
    
    // Element was moved
	else if(CFStringCompare(notificationName, kAXWindowMovedNotification, 0) == 0)
	{
        // Retain the element manipulated in question. Technical issue, resolved through:
        // http://stackoverflow.com/questions/853833/how-can-my-app-detect-a-change-to-another-apps-window
        LatestElement = (AXUIElementRef)CFMakeCollectable(CFRetain(element));
	}
}

@implementation AppDelegate

/*** Standard Delegate Functions ***/

- (void)dealloc
{
    [statusItem release];
    [TrackedProcesses release];
    
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
    InfoPopup* Popup = [[[InfoPopup alloc] initWithWindowNibName:@"InfoPopup"] autorelease];
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
        NSAlert* PopupAlert = [NSAlert alertWithMessageText:@"Error: Accessibility not enabled" defaultButton:@"Quit Application" alternateButton:nil otherButton:nil informativeTextWithFormat:@"This application requires system-accessibility authorization. To do this, go to System Preferences, Universal Access, and make sure that \"Enable access for assistive devices\" is enabled."];
        [PopupAlert runModal];
        
        // Simply force-quit!
        exit(0);
    }
    
    // Install the mouse release event
    CFMachPortRef MouseUpEventHandle = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionListenOnly, 1 << kCGEventLeftMouseUp, MyCGEventCallback, @"");
    CFRunLoopSourceRef RunSourceLoop = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, MouseUpEventHandle, 0);
    
    // Attatch to run-time detection
    CFRunLoopAddSource(CFRunLoopGetCurrent(), RunSourceLoop, kCFRunLoopCommonModes);
    CGEventTapEnable(MouseUpEventHandle, true);
    
    // Initialize an empty window registration array
    TrackedProcesses = [[NSMutableSet alloc] init];
    
    // Launch the window registration code, etc.
    // By doing this, we can then use the current code to explicitly ask for any new window launches
    [NSTimer scheduledTimerWithTimeInterval:2.0f target:self selector:@selector(UpdateAppHandles) userInfo:nil repeats:true];
}

- (void)UpdateAppHandles
{
    // Get all windows listed
    // Returns an array of CGWindowID types
    CFArrayRef WindowList = CGWindowListCreate(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    
    // New process list
    NSMutableSet* NewProcessIDs = [[NSMutableSet alloc] init];
    
    // Get description information for each window we found above
    // Returns an array of (possibly matchin) window description stuff...
    CFArrayRef DescriptionList = CGWindowListCreateDescriptionFromArray(WindowList);
    for(int i = 0; i < CFArrayGetCount(DescriptionList); i++)
    {
        // Pull out window description
        CFDictionaryRef WindowDict = CFArrayGetValueAtIndex(DescriptionList, i);
        CFNumberRef AppPID = CFDictionaryGetValue(WindowDict, kCGWindowOwnerPID);
        
        // Get the PID from the number
        int64_t PIDBuffer;
        CFNumberGetValue(AppPID, kCFNumberSInt64Type, &PIDBuffer);
        
        // Add to new process list
        [NewProcessIDs addObject:[NSNumber numberWithLongLong:PIDBuffer]];
    }
    CFRelease(DescriptionList);
    
    // Remove processes that have already been used
    NSMutableSet* ActiveSet = [NewProcessIDs copy];
    [NewProcessIDs minusSet:TrackedProcesses];
    
    // We essentially just want to retain the new process list (if a process is unlisted, that's new to us!)
    TrackedProcesses = ActiveSet;
    
    // For each graphical app (has a root window and more windows...)
    for(NSNumber* PIDNumber in NewProcessIDs)
    {
        // Get the PID value out
        pid_t PID = (pid_t)[PIDNumber longLongValue];
        
        // Get the app's base window controller
        AXUIElementRef WindowHandle = AXUIElementCreateApplication(PID);
        
        // Create window events observer
        __strong AXObserverRef ObserverHandle = NULL;
        AXObserverCreate(PID, AXMCallback, &ObserverHandle);
        
        // Create new window movement handle..
        if(AXObserverAddNotification(ObserverHandle, WindowHandle, kAXWindowCreatedNotification, (void*)self) == kAXErrorSuccess &&
           AXObserverAddNotification(ObserverHandle, WindowHandle, kAXWindowMovedNotification, (void*)self) == kAXErrorSuccess)
            CFRunLoopAddSource([[NSRunLoop currentRunLoop] getCFRunLoop], AXObserverGetRunLoopSource(ObserverHandle), kCFRunLoopDefaultMode);
    }
    
    // Done installing all handles
    CFRelease(WindowList);
    CFRelease(NewProcessIDs);
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
