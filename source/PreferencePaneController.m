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
- (void)updateUserInfoWithProfiles:(NSArray *)profiles
                   andGlobalUserId:(NSString *)globalUserId
                          andFlair:(NSData *)flairData;  
@end



NSInteger sortSitesByUsage(NSDictionary *site1, NSDictionary *site2, void *context) {
  int rep1 = [[site1 objectForKey:@"reputation"] intValue];
  int rep2 = [[site2 objectForKey:@"reputation"] intValue];
  if (rep1 > rep2) {
    return NSOrderedAscending;
  } else if (rep1 < rep2) {
    return NSOrderedDescending;
  } else {
    return NSOrderedSame;
  }
}




@implementation PreferencePaneController

- (id)initWithBundle:(NSBundle *)bundle {
  self = [super initWithBundle:bundle];
  if (self != nil) {
    queryTool = [[StackExchangeQueryTool alloc] init];
  }
  
  return self;
}

-(void)dealloc {
  [queryTool release];
  
  [super dealloc];
}

- (NSString *)mainNibName {
  return @"PrefPane";
}

- (void)mainViewDidLoad {
//  NSLog(@"mainViewDidLoad  %@", [profileURL delegate]);
}

- (void)setPersistence:(NewtPersistence *) persistence_ {
  persistence = persistence_;
}

- (void)willSelect {
//  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  
  [launchOnStartup setState:0];
  [launchOnStartup setTarget:self];
  [launchOnStartup setAction:@selector(updateStartupLaunchAction:)];
  
  NSString *appPath = [[NSBundle mainBundle] bundlePath];
  if ([self findStartupItem:appPath]) {
    [launchOnStartup setState:1];
  }

  
  NSData *flair = [persistence objectForKey:@"user_flair"];
  if (flair != nil) {
//    NSLog(@"global id %@", [persistence objectForKey:@"user_global_id"]);
    
    NSImage *image = [[NSImage alloc] initWithData:flair];
    NSSize newSize;
    newSize.height = 58;
    newSize.width = 208;
    [image setSize:newSize];
    [profileImage setImage:image];
    [image release];
  }
  
  [sitesTable initWithPersistence:persistence];
  
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
    [window setDelegate:self];
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
  
//  [persistence release];
  [profileInputWindow close];
  [profileInputWindow release];
  profileInputWindow = nil;
  
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
  NSDictionary *site = [persistence siteForKey:key];
  NSArray *tags = [site objectForKey:@"favourite_tags"];
  if (tags == NULL) {
    tags = [NSArray array];
  }
  [tagsField setObjectValue:tags];
  
  NSNumber *enable = [site objectForKey:@"enabled"];
  BOOL boolEnable = (enable != NULL) && [enable boolValue];
  [tagsField setEditable:boolEnable];
  [tagsField setEnabled:boolEnable];
}

- (void)saveConfigurationForCurrentSite {
  if (siteInEdit == NULL) {
    return;
  }
  
  NSArray *tags = [tagsField objectValue];
  [persistence setObject:tags forSite:siteInEdit andKey:@"favourite_tags"];
}

- (void)flushPreferences {
//  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//  [defaults setObject:preferences forKey:@"preferences"];
//  [defaults synchronize];
  [persistence synchronize];
}

- (void)windowDidResignKey:(NSNotification *)notification {
  if ([notification object] == window) {
    // will also be invoked when window is closed, so check first
    if (window != NULL) {
      [self flushPreferences];
    }
  }
}

- (void)windowWillClose:(NSNotification *)notification {
  if ([notification object] == window) {
    [self closePreferences];
  } else if ([notification object] == profileInputWindow) {
    [NSApp stopModal];
    [window makeKeyAndOrderFront:NSApp];
    [NSApp activateIgnoringOtherApps:YES];
  }
}

- (BOOL)windowShouldClose:(id)sender {
  if (sender == profileInputWindow) {
    return activity != FETCHING_USER_PROFILE;
  }
  return TRUE;
}


- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor {
  [self saveConfigurationForCurrentSite];
  return TRUE;
}

- (IBAction)selectUserButton:(id)sender {
  [profileInputWindow makeKeyAndOrderFront:NSApp];
  [profileInputWindow center];
//  [NSApp runModalForWindow:profileInputWindow];
}

- (IBAction)confirmUserSelection:(id)sender {
//  NSLog(@"updateProfileURL %@ !", [profileURL stringValue]);  
  
  activity = FETCHING_USER_PROFILE;
//  [profileProgressIndicator setUsesThreadedAnimation:TRUE];
  [profileProgressIndicator startAnimation:self];
  [searchUserButton setEnabled:FALSE];
  [profileURL setEditable:FALSE];

  [self updateProfileURL];
}

- (void)profileSearchError:(NSString *)text {
  activity = 0;
  [profileProgressIndicator stopAnimation:self];
  [searchUserButton setEnabled:TRUE];
  [profileURL setEditable:TRUE];
  
  NSRect frame = [profileInputWindow frame];
  frame.size.height = 97;
  [profileInputWindow setFrame:frame display:TRUE animate:TRUE];
  [profileSearchError setStringValue:text];
  [profileSearchError setHidden:FALSE];
  
  NSPoint errorPosition = [profileSearchError frame].origin; 
  errorPosition.y = 10;
  [profileSearchError setFrameOrigin:errorPosition];
}

- (IBAction)updateProfileURL {
  NSString *url = [profileURL stringValue];
  NSLog(@"updateProfileURL %@ ?", url);
//  [self profileSearchError:@"some text"];
  
  // no regular expressions in this fucking language...
  
  if (![url hasPrefix:@"http://"]) {
    url = [@"http://" stringByAppendingString:url];
  }
  
  NSDictionary *site = nil;
  for (NSString *key in [persistence sites]) {
    if ([url hasPrefix:key]) {
      site = [persistence siteForKey:key];
      break;
    }
  }
  if (site == nil) {
    [self profileSearchError:@"Profile URL is expected, e.g. stackoverflow.com/users/22656"];
    return;
  }
  
  // remove 'http://stackoverflow.com/users/' prefix
  NSString *suffix = [url substringFromIndex:[[site objectForKey:@"site_url"] length] + 7];
  NSLog(@"suffix %@", suffix);
  NSString *id = [[suffix componentsSeparatedByString:@"/"] objectAtIndex:0];
  NSLog(@"id %@", id);
  
  QueryToolSuccessHandler userDataHandler = ^(NSDictionary *result) {
    NSLog(@"userDataHandler");
    NSArray *users = [result objectForKey:@"users"];
    if ([users count] == 0) {
      // no such user
      [self profileSearchError:@"User with such id doesn't exist."];
    }
    
    // save association id
    NSDictionary *userData = [users objectAtIndex:0];
    NSString *associationId = [userData objectForKey:@"association_id"];
    
    
    // fetch information about user's profiles across Stack Exchange network
    QueryToolSuccessHandler globalUserDataHandler = ^(NSDictionary *result) {
      NSLog(@"globalUserDataHandler");
      NSArray *profiles = [result objectForKey:@"associated_users"];
      
      // retrieve flair image for the user
      NSString *flairURL = [NSString stringWithFormat:@"http://stackexchange.com/users/flair/%@.png", associationId];
      NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString: flairURL]];
      URLConnectionDelegate *flairHandler = [[[URLConnectionDelegate alloc] initWithSuccessHandler:^(NSData *flair) {
        
        [self updateUserInfoWithProfiles:profiles
                         andGlobalUserId:associationId
                                andFlair:flair];
        
      }] autorelease];
      
      // will be released from delegate
      NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request
                                                                    delegate:flairHandler];
      if (!connection) {
        NSLog(@"Couldn't open connection for url %@", flairURL);
      }
    };
    [queryTool execute:@"http://stackauth.com"
            withMethod:[NSString stringWithFormat:@"users/%@/associated", associationId]
         andParameters:[NSDictionary dictionary]
             onSuccess:globalUserDataHandler];
    
  };
  
  NSString *apiEndpoint = [site objectForKey:@"api_endpoint"];
  [queryTool execute:apiEndpoint
          withMethod:[@"users/" stringByAppendingString:id]
       andParameters:[NSDictionary dictionary]
           onSuccess:userDataHandler];
}

- (void)updateUserInfoWithProfiles:(NSArray *)profiles
                   andGlobalUserId:(NSString *)globalUserId
                          andFlair:(NSData *)flairData {
  NSLog(@"updateUserInfoWithProfiles");
  activity = 0;
  [profileProgressIndicator stopAnimation:self];
  [searchUserButton setEnabled:TRUE];
  [profileURL setEditable:TRUE];
  [profileInputWindow close];
  
  
  profiles = [profiles sortedArrayUsingFunction:sortSitesByUsage context:nil];
  
  NSMutableArray *sortedProfiles = [NSMutableArray arrayWithCapacity:[profiles count]];

  // clear any data from previous user account, assuming there was one
  for (NSString *siteKey in [persistence sites]) {
    NSMutableDictionary *site = [persistence siteForKey:siteKey];
    [site removeObjectForKey:@"user_reputation"];
    [site removeObjectForKey:@"user_email_hash"];
    [site removeObjectForKey:@"user_name"];
    [site removeObjectForKey:@"user_type"];
    [site removeObjectForKey:@"user_id"];
  }
  
  // persist profile data
  for (NSDictionary *profile in profiles) {
    NSString *siteKey = [[profile objectForKey:@"on_site"] objectForKey:@"site_url"];
    NSMutableDictionary *site = [persistence siteForKey:siteKey];
    
    NSString *userType = [profile objectForKey:@"user_type"];
    if ([userType isEqualToString:@"registered"] || [userType isEqualToString:@"moderator"]) {
      [site setObject:[profile objectForKey:@"user_id"] forKey:@"user_id"];
      [site setObject:userType forKey:@"user_type"];
      [site setObject:[profile objectForKey:@"display_name"] forKey:@"user_name"];
      [site setObject:[profile objectForKey:@"reputation"] forKey:@"user_reputation"];
      [site setObject:[profile objectForKey:@"email_hash"] forKey:@"user_email_hash"];
    }
    
    [sortedProfiles addObject:siteKey];
  }
  
  [persistence setObject:flairData forKey:@"user_flair"];
  [persistence setObject:globalUserId forKey:@"user_global_id"];
  [persistence setObject:sortedProfiles forKey:@"most_used_sites"];
  [persistence synchronize];
  
  // present flair image, so user knows it's _his_ account
  NSImage *image = [[NSImage alloc] initWithData:flairData];
  NSSize newSize;
  newSize.height = 58;
  newSize.width = 208;
  [image setSize:newSize];
  [profileImage setImage:image];
  [image release];
  
  // reorder table according to new user accouns data
  [self updateFilterAction:self];
}

@end
