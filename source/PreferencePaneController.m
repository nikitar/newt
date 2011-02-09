/*
 * Created by Nikita Rybak on Feb 2 2011.
 *
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge,
 * to any person obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to permit
 * persons to whom the Software is furnished to do so, subject to the following
 * conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import "PreferencePaneController.h"

@interface PreferencePaneController()
- (LSSharedFileListItemRef)findStartupItem:(NSString *)appPath;
@end



@implementation PreferencePaneController

- (id)initWithBundle:(NSBundle *)bundle {
  if ( ( self = [super initWithBundle:bundle] ) != nil ) {
  }
  
  return self;
}

- (NSString *)mainNibName {
  return @"PrefPane";
}

- (void)mainViewDidLoad {
}

- (void)willSelect {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  
  [launchOnStartup setState:0];
  [launchOnStartup setTarget:self];
  [launchOnStartup setAction:@selector(updateStartupLaunchAction:)];
  
  NSString *appPath = [[NSBundle mainBundle] bundlePath];
  if ([self findStartupItem:appPath]) {
    [launchOnStartup setState:1];
  }


  
  sites = [[defaults objectForKey:@"sites"] retain];
  preferences = [[[defaults objectForKey:@"preferences"] mutableCopy] retain];
  if (preferences == NULL) {
    preferences = [[NSMutableDictionary dictionary] retain];
  }
  [sitesTable setUpWithSites:sites
              andPreferences:preferences];
  
  siteInEdit = NULL;
  [tagsField setTokenizingCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@", "]];
  [self loadConfigurationForSite:NULL];
}

- (void)willUnselect {
  // save unsaved fields
  [self saveConfigurationForCurrentSite];
  
  // save all data to memory
  [self flushPreferences];
  
  if (siteInEdit) {
    [siteInEdit release];
  }
}



// loads preferences view from .xib file and puts it in a new window
-(void) displayPreferences {
  if (window != NULL) {
    [window orderFrontRegardless];
    [NSApp activateIgnoringOtherApps:YES];
    return;
  }
  
  NSView *prefView;
  if ([self loadMainView]) {
    [self willSelect];
    prefView = [self mainView];
    
    // create preferences window
    NSSize prefSize = [prefView frame].size;
    NSRect frame = NSMakeRect(200, 200, prefSize.width, prefSize.height);
    window  = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:NSTitledWindowMask | NSClosableWindowMask
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [window center];
    [window setContentView:prefView];
    [window setTitle:@"Newt Preferences"];
    [window setDelegate: self];
    [window makeKeyAndOrderFront:NSApp];
    [NSApp activateIgnoringOtherApps:YES];
    
    [self didSelect];
  } else {
    NSLog(@"load preferences error");
  }
}

-(void) closePreferences {
  [self willUnselect];
  
  // window will be closed automatically
  
  [sites release];
  [preferences release];
  
  // displayPreferences checks for NULL to see whether pref window is currently open
  window = NULL;
  
  [self didUnselect];
}

- (IBAction)updateFilterAction:(id)sender {
  NSString *search = [siteSearchField stringValue];
  [sitesTable applyFilter:search];
}

- (IBAction)updateStartupLaunchAction:(id)sender {
  NSString *appPath = [[NSBundle mainBundle] bundlePath];
	CFURLRef url = (CFURLRef)[NSURL fileURLWithPath:appPath]; 
  LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
  if (loginItems) {
    if ([launchOnStartup state]) {
      //Insert an item to the list.
      LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemLast, NULL, NULL, url, NULL, NULL);
      if (item) {
        CFRelease(item);
      }
    } else {
      LSSharedFileListItemRef itemRef = [self findStartupItem:appPath];
      if (itemRef) {
        LSSharedFileListItemRemove(loginItems, itemRef);
      }
    }
    
    CFRelease(loginItems);
  }
}

- (LSSharedFileListItemRef)findStartupItem:(NSString *)appPath {
  LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
  
  if (loginItems) {
		UInt32 seedValue;
		NSArray *loginItemsArray = (NSArray *)LSSharedFileListCopySnapshot(loginItems, &seedValue);
    CFRelease(loginItems);
    
		for (int i = 0; i < [loginItemsArray count]; ++i) {
			LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)[loginItemsArray objectAtIndex:i];
      
			//Resolve the item with URL
      CFURLRef url;
			if (LSSharedFileListItemResolve(itemRef, 0, (CFURLRef*) &url, NULL) == noErr) {
				NSString *urlPath = [(NSURL*)url path];
        CFRelease(url);
				if ([urlPath compare:appPath] == NSOrderedSame){
          CFRetain(itemRef);
          [loginItemsArray release];
          return itemRef;
				}
			}
		}
		[loginItemsArray release];
  }
  
  return nil;
}

- (void)loadConfigurationForSite:(NSString *)key {
  if (siteInEdit) {
    [siteInEdit release];
  }
  
  if (key == NULL) {
    siteInEdit = NULL;
    [tagsField setEditable:FALSE];
    [tagsField setEnabled:FALSE];
    [tagsField setObjectValue:@""];
    return;
  }

  siteInEdit = [[key copy] retain];

  // fetch user's favourite tags
  NSDictionary *sitePreferences = [preferences objectForKey:key];
  if (sitePreferences == NULL) {
    sitePreferences = [NSDictionary dictionary];
  }
  NSArray *tags = [sitePreferences objectForKey:@"tags"];
  if (tags == NULL) {
    tags = [NSArray array];
  }
  
  [tagsField setObjectValue:tags];
  
  NSNumber *enable = [sitePreferences objectForKey:@"enabled"];
  BOOL boolEnable = (enable != NULL) && [enable boolValue];
  [tagsField setEditable:boolEnable];
  [tagsField setEnabled:boolEnable];
}

- (void)saveConfigurationForCurrentSite {
  if (siteInEdit == NULL) {
    return;
  }
  
  NSDictionary *current = [preferences objectForKey:siteInEdit];
  NSMutableDictionary *next;
  if (current == NULL) {
    next = [NSMutableDictionary dictionary];
  } else {
    next = [NSMutableDictionary dictionaryWithDictionary:current];
  }
  
  NSArray *tags = [tagsField objectValue];
  [next setObject:tags forKey:@"tags"];
  [preferences setObject:next forKey:siteInEdit];
}

- (void)flushPreferences {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:preferences forKey:@"preferences"];
  [defaults synchronize];
}

- (void)windowDidResignKey:(NSNotification *)notification {
  // will also be invoked when window is closed, so check first
  if (window != NULL) {
    [self flushPreferences];
  }
}

- (void)windowWillClose:(NSNotification *)notification {
  [self closePreferences];
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor {
  [self saveConfigurationForCurrentSite];
  return TRUE;
}

@end
