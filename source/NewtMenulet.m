/*
 * Created by Nikita Rybak on Feb 1 2011.
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


#import "NewtMenulet.h"


@interface NewtMenulet()
-(void) processNewQuestions:(NSDictionary*)data
                    forSite:(NSString *)siteKey;
-(void) loadStackExchangeNetworkSites;

-(void) savePreferenceValue:(id)value
                     forKey:(NSString *)key
                    andSite:(NSString *)siteKey;
-(id) preferenceValueForKey:(NSString *)key
                    andSite:(NSString *)siteKey;
//-(void) installGrowlPlugin;
-(BOOL) isNewQuestion:(NSString *) questionId;
-(void) cleanUpLatestQuestions;
@end


@implementation NewtMenulet

-(void)dealloc {
  [statusItem release];
  [menuIconOn release];
  [menuIconOff release];
  [menuIconAlert release];
  [updateTimer release];
  [queryTool release];
  [prefPane release];
  [defaults release];
  [latestQuestions release];
  
  [super dealloc];
}

- (void)awakeFromNib {
  
  latestQuestions = [[NSMutableDictionary alloc] initWithCapacity:20];
  enabled = TRUE;
  defaults = [[NSUserDefaults standardUserDefaults] retain];
  
  NSBundle *bundle = [NSBundle mainBundle];
  NSString *path = [bundle pathForResource:@"newtStatusBarIconDark" ofType:@"png"];
  menuIconOn = [[NSImage alloc] initWithContentsOfFile:path];
  path = [bundle pathForResource:@"newtStatusBarIconLight" ofType:@"png"];
  menuIconOff = [[NSImage alloc] initWithContentsOfFile:path];
  path = [bundle pathForResource:@"newtStatusBarIconYellow" ofType:@"png"];
  menuIconAlert = [[NSImage alloc] initWithContentsOfFile:path];
  
  queryTool = [[StackExchangeQueryTool alloc] init];
  
  statusItem = [[[NSStatusBar systemStatusBar] 
                 statusItemWithLength:NSVariableStatusItemLength]
                retain];
  [statusItem setHighlightMode:YES];
  [statusItem setImage:menuIconOn];
  [statusItem setEnabled:YES];
  [statusItem setToolTip:@"Newt - New questions from Stack Exchange sites."];
  [statusItem setMenu:theMenu];
  
  // initialize preference pane for later use
  prefPane = [[PreferencePaneController alloc] initWithBundle:bundle];
  
  [self loadStackExchangeNetworkSites];
  
  // initialise Growl
  [GrowlApplicationBridge setGrowlDelegate:self];
  
  //These notifications are filed on NSWorkspace's notification center, not the default notification center. 
  //  You will not receive sleep/wake notifications if you file with the default notification center.
  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self 
                                                         selector: @selector(receiveSleepNote:) name: NSWorkspaceWillSleepNotification object: NULL];
  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self 
                                                         selector: @selector(receiveWakeNote:) name: NSWorkspaceDidWakeNotification object: NULL];  
  
  updateTimer = [[NSTimer 
                  scheduledTimerWithTimeInterval:(61.0)
                  target:self
                  selector:@selector(retrieveQuestions:)
                  userInfo:nil
                  repeats:YES] retain];
  [updateTimer fire];
}

-(void) installGrowlPlugin {
}

-(BOOL) isNewQuestion:(NSString *) questionId {
  if ([latestQuestions objectForKey:questionId] == nil) {
    NSNumber *now = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSinceReferenceDate]];
    [latestQuestions setObject:now forKey:questionId];
    return TRUE;
  } else {
    return FALSE;
  }
}

-(void) cleanUpLatestQuestions {
  NSTimeInterval now = [[NSDate date] timeIntervalSinceReferenceDate];
  for (NSString *key in [latestQuestions allKeys]) {
    NSTimeInterval created = [[latestQuestions objectForKey:key] doubleValue];
    if (created + 15*60 < now) {
      // question is more than 15 minutes old, delete
      [latestQuestions removeObjectForKey:key];
    }
  }
}

-(void) loadStackExchangeNetworkSites {
  
  // uncomment to update sites information unconditionally
//  [defaults setObject:NULL forKey:@"sites_updated"];
//  [defaults setObject:NULL forKey:@"sites"];
//  [defaults synchronize];
  
  NSDate *lastUpdate = [defaults objectForKey:@"sites_updated"];
  if (lastUpdate == NULL || 
      ([lastUpdate timeIntervalSinceReferenceDate] + 5*24*60*60 < [[NSDate date] timeIntervalSinceReferenceDate])) {
    NSLog(@"Refreshing SE sites information...");
    
    QueryToolSuccessHandler handleSites = ^(NSDictionary *result) {
      NSArray *sites = [result objectForKey:@"api_sites"];
      
      NSMutableDictionary *sitesMap = [NSMutableDictionary dictionaryWithCapacity:[sites count]];
      int sites_total = [sites count];
      for (int i = 0; i < sites_total; ++i) {
        NSMutableDictionary *site = [NSMutableDictionary dictionaryWithDictionary:[sites objectAtIndex:i]];
        [site setObject:[NSNumber numberWithInt:i] forKey:@"order"];
        
        NSString *iconUrl = [site objectForKey:@"icon_url"];
        iconUrl = [NSString stringWithFormat:@"%@?test=1", iconUrl];
        
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString: iconUrl]];

        // we'll fetch site icons asynchronously, so application won't freeze
        // it also turns out to be much faster
        URLConnectionDelegate *delegate = [[[URLConnectionDelegate alloc] initWithSuccessHandler:^(NSData *response) {
//          NSLog(@"icon data received  %i  -  total %i", i, [sitesMap count]);
          
          [site setObject:response forKey:@"icon_data"];

          NSString *siteKey = [site objectForKey:@"site_url"];
          [sitesMap setObject:site forKey:siteKey];
          if ([sitesMap count] == sites_total) {
            NSLog(@"processing's done, %i sites found", sites_total);
            [defaults setObject:sitesMap forKey:@"sites"];
            [defaults setObject:[NSDate date] forKey:@"sites_updated"];
            [defaults synchronize];
          }
        }] autorelease];
        
        // will be released from delegate
        NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request
                                                                      delegate:delegate];
        if (!connection) {
          NSLog(@"Couldn't open connection for url %@", iconUrl);
        }
      }
    };
    
    
    [queryTool execute:@"http://stackauth.com"
            withMethod:@"sites"
         andParameters:[NSDictionary dictionary]
             onSuccess:handleSites];
  }
}

-(IBAction) retrieveQuestions:(id)sender {
  
  NSMutableDictionary *preferences = [NSMutableDictionary dictionaryWithDictionary:[defaults objectForKey:@"preferences"]];
  if (preferences == NULL) {
    return;
  }
  NSDictionary *sites = [defaults objectForKey:@"sites"];
  if (sites == NULL) {
    // didn't download data yet?
    return;
  }
  
  if (!enabled) {
    // temporary switched off
    return;
  }
  
  [self cleanUpLatestQuestions];
  
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
  int cutoffDate = (int) now - 2 * 60;
  
  for (NSString *siteKey in [preferences allKeys]) {
    NSMutableDictionary *sitePrefs = [NSMutableDictionary dictionaryWithDictionary:[preferences objectForKey:siteKey]];
    NSDictionary *siteInfo = [sites objectForKey:siteKey];
    if (siteInfo == NULL) {
      // key disappeared after site data update (e.g., site moved to the new domain)
      // remove pref record, for now
      [preferences setObject:NULL forKey:siteKey];
      continue;
    }
    
    NSNumber *siteEnabled = [sitePrefs objectForKey:@"enabled"];
    if (siteEnabled == NULL || ![siteEnabled boolValue]) {
      continue;
    }
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:5];
    
    
    // do not use 'search' method, go for 'questions' and filter results later
//    NSArray *tags = [sitePrefs objectForKey:@"tags"];
//    NSString *tagsString = [tags componentsJoinedByString:@";"];
//    [parameters setObject:tagsString forKey:@"tagged"];
    
    NSString *method;
    NSString *searchDateKey;
//    if ([tags count] == 0) {
      method = @"questions";
      searchDateKey = @"fromdate";
//    } else {
//      method = @"search";
//      searchDateKey = @"min";
//    }
    NSString *api = [siteInfo objectForKey:@"api_endpoint"];
    
    [parameters setObject:[NSString stringWithFormat:@"%d", cutoffDate] forKey:searchDateKey];

    [parameters setObject:@"creation" forKey:@"sort"];
    [parameters setObject:@"16" forKey:@"pagesize"];
    
    QueryToolSuccessHandler onSuccess = ^(NSDictionary *result) {
      [self processNewQuestions:result
                        forSite:siteKey];
    };
    
    [queryTool execute:api 
            withMethod:method 
         andParameters:parameters
             onSuccess:onSuccess];
  }
}

-(void) processNewQuestions:(NSDictionary *)data
                    forSite:(NSString *)siteKey {
  NSArray *questions = [data objectForKey:@"questions"];
//  NSLog(@"%d questions found for %@", questions.count, siteKey);
  
  NSDictionary *sites = [defaults objectForKey:@"sites"];
  NSDictionary *siteInfo = [sites objectForKey:siteKey];
  
  NSArray *interestingTagsArray = [self preferenceValueForKey:@"tags" andSite:siteKey];
  NSSet *interestingTags = nil;
  if (interestingTagsArray != nil && [interestingTagsArray count] > 0) {
    interestingTags = [NSSet setWithArray:interestingTagsArray];
  }
  
  for (NSDictionary *question in questions) {
    NSArray *tags = [question objectForKey:@"tags"];
    NSString *questionId = [question objectForKey:@"question_id"];
    
    // filter questions by interesting tags
    if (interestingTags != nil && ![interestingTags intersectsSet:[NSSet setWithArray:tags]]) {
      continue;
    }
    
    // check whether the question was seen before
    if (![self isNewQuestion:questionId]) {
      continue;
    }

    NSString *url = [NSString stringWithFormat:@"%@/questions/%@", [siteInfo objectForKey:@"site_url"], questionId];
    NSString *title = [tags componentsJoinedByString:@", "];
    
    [GrowlApplicationBridge notifyWithTitle:title
                                description:[question objectForKey:@"title"]
                           notificationName:@"New Question"
                                   iconData:[siteInfo objectForKey:@"icon_data"]
                                   priority:0
                                   isSticky:FALSE
                               clickContext:url];
  }
}

-(IBAction) displayPreferences:(id)sender {
  [prefPane displayPreferences];
}

- (IBAction)openAboutPanel:(id)sender {
  [NSApp orderFrontStandardAboutPanel:self];
}

-(IBAction) quit:(id)sender {
  [NSApp terminate:self];
}

-(IBAction) toggleDisable:(id)sender {
  if (enabled) {
    [disableButton setTitle:@"Wake"];
    [statusItem setImage:menuIconOff];
    enabled = FALSE;
  } else {
    [disableButton setTitle:@"Sleep"];
    [statusItem setImage:menuIconOn];
    enabled = TRUE;
  }
}

-(void) growlNotificationWasClicked:(id)clickContext {
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:clickContext]];
}

// since changing user defaults is so fucking tricky, there's a method for that
-(void) savePreferenceValue:(id)value
                     forKey:(NSString *)key
                    andSite:(NSString *)siteKey {
  NSLog(@"savePreferenceValue");
  NSMutableDictionary *preferences = [NSMutableDictionary dictionaryWithDictionary:[defaults objectForKey:@"preferences"]];
  NSMutableDictionary *sitePreferences = [NSMutableDictionary dictionaryWithDictionary:[preferences objectForKey:siteKey]];
  
  [sitePreferences setObject:value forKey:key];
  
  [preferences setObject:sitePreferences forKey:siteKey];
  [defaults setObject:preferences forKey:@"preferences"];
}

-(id) preferenceValueForKey:(NSString *)key
                    andSite:(NSString *)siteKey {
  NSDictionary *preferences = [defaults objectForKey:@"preferences"];
  NSDictionary *sitePreferences = [preferences objectForKey:siteKey];
  return [sitePreferences objectForKey:key];
}


- (void) receiveSleepNote: (NSNotification*) note {
  NSLog(@"NewtMenulet#receiveSleepNote: %@", [note name]);
}

- (void) receiveWakeNote: (NSNotification*) note {
  NSLog(@"NewtMenulet#receiveSleepNote: %@", [note name]);
  [NSString stringWithFormat:@""];
}


@end
