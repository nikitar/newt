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


NSString *cutoffDate(double limit) {
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
  int cutoffDate = (int) (now - limit * 60);
  return [NSString stringWithFormat:@"%d", cutoffDate];
}



// some private methods
@interface NewtMenulet()
- (void)loadStackExchangeNetworkSites;

- (BOOL)isNewPost:(NSString *)postId
           ofType:(NSString *)type
          forSite:(NSString *)siteKey;
- (void)cleanUpViewedPosts;

- (void)processNewQuestions:(NSDictionary *)data forSite:(NSString *)siteKey;
- (void)processUserQuestions:(NSDictionary *)result forSite:(NSString *)siteKey;
- (void)processUserAnswers:(NSDictionary *)result forSite:(NSString *)siteKey;
- (void)processCommentsToUser:(NSDictionary *)result forSite:(NSString *)siteKey;
- (void)processAnswers:(NSDictionary *)result forSite:(NSString *)siteKey;


- (NSTimer *)startTimerWithMethod:(SEL)selector
                      andInterval:(double)interval;
//- (void)disposeTimer:(NSTimer *)timer;

- (NSArray *)interestingSites;
@end


@implementation NewtMenulet

- (void)dealloc {
  [statusItem release];
  [menuIconOn release];
  [menuIconOff release];
  [menuIconAlert release];
  
  [questionTimer release];
  [postsByUserTimer release];
  [commentsToUserTimer release];
  [answersOnPostsTimer release];
  
  [queryTool release];
  [prefPane release];
  [persistence release];
  [viewedPosts release];
  [watchedQuestions release];
  [watchedAnswers release];
  
  [super dealloc];
}

- (void)awakeFromNib {
  
  viewedPosts = [[NSMutableDictionary alloc] initWithCapacity:20];
  enabled = TRUE;
  watchedQuestions = [[NSMutableDictionary alloc] initWithCapacity:10];
  watchedAnswers = [[NSMutableDictionary alloc] initWithCapacity:10];
  persistence = [[NewtPersistence alloc] init];
  
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
  [prefPane setPersistence:persistence];
  
  [self loadStackExchangeNetworkSites];
  
  // initialise Growl
  [GrowlApplicationBridge setGrowlDelegate:self];

  // experimental
//  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self 
//                                                         selector: @selector(receiveSleepNote:) name: NSWorkspaceWillSleepNotification object: NULL];
//  [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self 
//                                                         selector: @selector(receiveWakeNote:) name: NSWorkspaceDidWakeNotification object: NULL];  
  
  questionTimer = [self startTimerWithMethod:@selector(retrieveQuestions:) andInterval:1];
  answersOnPostsTimer = [self startTimerWithMethod:@selector(retrieveAnswers:) andInterval:2];
  commentsOnPostsTimer = [self startTimerWithMethod:@selector(retrieveCommentsForPosts:) andInterval:1];
  postsByUserTimer = [self startTimerWithMethod:@selector(retrievePosts:) andInterval:5];
  commentsToUserTimer = [self startTimerWithMethod:@selector(retrieveCommentsToUser:) andInterval:2];
}

- (BOOL)isNewPost:(NSString *)postId
           ofType:(NSString *)type
          forSite:(NSString *)siteKey {
  NSString *compositeKey = [NSString stringWithFormat:@"%@-%@-%@", type, siteKey, postId];
  
  if ([viewedPosts objectForKey:compositeKey] == nil) {
    NSNumber *now = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSinceReferenceDate]];
    [viewedPosts setObject:now forKey:compositeKey];
    return TRUE;
  } else {
    return FALSE;
  }
}

- (void)cleanUpViewedPosts {
  NSTimeInterval now = [[NSDate date] timeIntervalSinceReferenceDate];
  for (NSString *key in [viewedPosts allKeys]) {
    NSTimeInterval created = [[viewedPosts objectForKey:key] doubleValue];
    if (created + 15*60 < now) {
      // question is more than 15 minutes old, delete
      [viewedPosts removeObjectForKey:key];
    }
  }
}

- (void)loadStackExchangeNetworkSites {
  [persistence updateSites:queryTool];
}


- (IBAction)retrieveQuestions:(id)sender {
  if (!enabled) {
    // temporary switched off
    return;
  }
  
  NSDictionary *sites = [persistence sites];
  [self cleanUpViewedPosts];
  
//  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
//  int cutoffDate = (int) now - 2 * 60;
  
  for (NSString *siteKey in [sites allKeys]) {
    NSDictionary *site = [persistence siteForKey:siteKey];
    
    NSNumber *siteEnabled = [site objectForKey:@"enabled"];
    if (siteEnabled == NULL || ![siteEnabled boolValue]) {
      continue;
    }
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:5];
    
    // do not use 'search' method, go for 'questions' and filter results later
    NSString *api = [site objectForKey:@"api_endpoint"];
    
    [parameters setObject:cutoffDate(2) forKey:@"fromdate"];

    [parameters setObject:@"creation" forKey:@"sort"];
    [parameters setObject:@"16" forKey:@"pagesize"];
    
    QueryToolSuccessHandler onSuccess = ^(NSDictionary *result) {
      [self processNewQuestions:result
                        forSite:siteKey];
    };
    
    [queryTool execute:api 
            withMethod:@"questions" 
         andParameters:parameters
             onSuccess:onSuccess];
  }
}

- (void)processNewQuestions:(NSDictionary *)data
                    forSite:(NSString *)siteKey {
  NSArray *questions = [data objectForKey:@"questions"];
//  NSLog(@"%d questions found for %@", questions.count, siteKey);
  
  NSDictionary *site = [persistence siteForKey:siteKey];
  
  NSArray *interestingTagsArray = [site objectForKey:@"favourite_tags"];
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
    if (![self isNewPost:questionId ofType:@"q" forSite:siteKey]) {
      continue;
    }

    NSString *url = [NSString stringWithFormat:@"%@/questions/%@", [site objectForKey:@"site_url"], questionId];
    NSString *title = [tags componentsJoinedByString:@", "];
    
    [GrowlApplicationBridge notifyWithTitle:title
                                description:[question objectForKey:@"title"]
                           notificationName:@"New Question"
                                   iconData:[site objectForKey:@"icon_data"]
                                   priority:0
                                   isSticky:FALSE
                               clickContext:url];
  }
}

- (IBAction)displayPreferences:(id)sender {
  [prefPane displayPreferences];
}

- (IBAction)openAboutPanel:(id)sender {
  [NSApp orderFrontStandardAboutPanel:self];
}

- (IBAction)quit:(id)sender {
  [NSApp terminate:self];
}

- (IBAction)toggleDisable:(id)sender {
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

- (void)growlNotificationWasClicked:(id)clickContext {
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:clickContext]];
}



- (NSTimer *)startTimerWithMethod:(SEL)selector
                      andInterval:(double)interval {
  NSTimer *timer = [[NSTimer scheduledTimerWithTimeInterval:interval*60 + 1
                                                    target:self
                                                  selector:selector
                                                  userInfo:nil
                                                   repeats:YES] retain];
  [timer fire];
  return timer;
}
//- (void)disposeTimer:(NSTimer *)timer {
//  if (timer == nil) {
//    [timer invalidate];
//    [timer release];
//  }
//}



- (void)retrievePosts:(id)sender {
  for (NSString *siteKey in [self interestingSites]) {
    NSDictionary *site = [persistence siteForKey:siteKey];
    NSString *user_id = [site objectForKey:@"user_id"];
    if (user_id == nil) {
      continue;
    }
    NSString *api = [site objectForKey:@"api_endpoint"];
    
    QueryToolSuccessHandler handler = ^(NSDictionary *result) {
      [self processUserQuestions:result forSite:siteKey];
    };
    
    [queryTool execute:api 
            withMethod:[NSString stringWithFormat:@"users/%@/questions", user_id]
         andParameters:[NSDictionary dictionaryWithObject:@"5" forKey:@"pagesize"]
             onSuccess:handler];
    
    handler = ^(NSDictionary *result) {
      [self processUserAnswers:result forSite:siteKey];
    };
    
    [queryTool execute:api 
            withMethod:[NSString stringWithFormat:@"users/%@/answers", user_id]
         andParameters:[NSDictionary dictionaryWithObject:@"5" forKey:@"pagesize"]
             onSuccess:handler];
  }
}

- (void)processUserQuestions:(NSDictionary *)result
                     forSite:(NSString *)siteKey {
  NSArray *posts = [result objectForKey:@"questions"];
  NSMutableArray *ids = [NSMutableArray arrayWithCapacity:[posts count]];
  for (NSDictionary *post in posts) {
    [ids addObject:[post objectForKey:@"question_id"]];
  }
  
  NSArray *old = [watchedQuestions objectForKey:siteKey];
  [watchedQuestions setObject:ids forKey:siteKey];
//  if (old == nil || ![ids isEqualToArray:old]) {
//    [answersOnPostsTimer fire];
//    [commentsOnPostsTimer fire];
//  }
}

- (void)processUserAnswers:(NSDictionary *)result
                   forSite:(NSString *)siteKey {
  NSArray *posts = [result objectForKey:@"answers"];
  NSMutableArray *ids = [NSMutableArray arrayWithCapacity:[posts count]];
  for (NSDictionary *post in posts) {
    [ids addObject:[post objectForKey:@"answer_id"]];
  }
  
  NSArray *old = [watchedAnswers objectForKey:siteKey];
  [watchedAnswers setObject:ids forKey:siteKey];
//  if (old == nil || ![ids isEqualToArray:old]) {
//    [commentsOnPostsTimer fire];
//  }
}

- (void)retrieveCommentsToUser:(id)sender {
  for (NSString *siteKey in [self interestingSites]) {
    NSDictionary *site = [persistence siteForKey:siteKey];
    NSString *user_id = [site objectForKey:@"user_id"];
    if (user_id == nil) {
      continue;
    }
    NSString *api = [site objectForKey:@"api_endpoint"];
    
    QueryToolSuccessHandler handler = ^(NSDictionary *result) {
      [self processCommentsToUser:result forSite:siteKey];
    };
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:3];
    [parameters setObject:@"10" forKey:@"pagesize"];
    [parameters setObject:cutoffDate(10) forKey:@"fromdate"];
    [queryTool execute:api 
            withMethod:[NSString stringWithFormat:@"users/%@/mentioned", user_id]
         andParameters:parameters
             onSuccess:handler];
  }
}

- (void)processCommentsToUser:(NSDictionary *)result
                      forSite:(NSString *)siteKey {
  NSArray *comments = [result objectForKey:@"comments"];
  NSDictionary *site = [persistence siteForKey:siteKey];
  
  for (NSDictionary *comment in comments) {
    NSString *commentId = [comment objectForKey:@"comment_id"];
    if (![self isNewPost:commentId ofType:@"c" forSite:siteKey]) {
      continue;
    }
    
    NSString *from = [[comment objectForKey:@"owner"] objectForKey:@"display_name"];
    NSString *text = [comment objectForKey:@"body"];
      
    // the system works funny here
    // you can go to the url /questions/{answer_id} and you'll be redirected to the correct question
    NSString *url = [NSString stringWithFormat:@"%@/questions/%@", [site objectForKey:@"site_url"], [comment objectForKey:@"post_id"]];
  
    [GrowlApplicationBridge notifyWithTitle:[NSString stringWithFormat:@"Comment from %@", from]
                                description:text
                           notificationName:@"New Comment"
                                   iconData:[site objectForKey:@"icon_data"]
                                   priority:0
                                   isSticky:FALSE
                               clickContext:url];
  }
}


- (void)retrieveAnswers:(id)sender {
  for (NSString *siteKey in watchedQuestions) {
    NSDictionary *site = [persistence siteForKey:siteKey];
    NSArray *ids = [watchedQuestions objectForKey:siteKey];
    if ([ids count] == 0) {
      continue;
    }
    
    NSString *api = [site objectForKey:@"api_endpoint"];
    
    QueryToolSuccessHandler handler = ^(NSDictionary *result) {
      [self processAnswers:result forSite:siteKey];
    };
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:3];
    [parameters setObject:@"10" forKey:@"pagesize"];
    [parameters setObject:cutoffDate(10) forKey:@"fromdate"];
    [parameters setObject:@"creation" forKey:@"sort"];
    NSString *idsJoined = [ids componentsJoinedByString:@";"];
    
    [queryTool execute:api 
            withMethod:[NSString stringWithFormat:@"questions/%@/answers", idsJoined]
         andParameters:parameters
             onSuccess:handler];
  }
}

- (void)processAnswers:(NSDictionary *)result
               forSite:(NSString *)siteKey {
  NSArray *answers = [result objectForKey:@"answers"];
  NSDictionary *site = [persistence siteForKey:siteKey];
  
  for (NSDictionary *answer in answers) {
    NSString *answerId = [answer objectForKey:@"answer_id"];
    if (![self isNewPost:answerId ofType:@"a" forSite:siteKey]) {
      continue;
    }
    
    NSString *from = [[answer objectForKey:@"owner"] objectForKey:@"display_name"];
    
    // the system works funny here
    // you can go to the url /questions/{answer_id} and you'll be redirected to the correct question
    NSString *url = [NSString stringWithFormat:@"%@/questions/%@", [site objectForKey:@"site_url"], answerId];
    
    [GrowlApplicationBridge notifyWithTitle:[NSString stringWithFormat:@"A new answer by %@", from]
                                description:@""
                           notificationName:@"New Answer"
                                   iconData:[site objectForKey:@"icon_data"]
                                   priority:0
                                   isSticky:TRUE
                               clickContext:url];
  }  
}


- (void)retrieveCommentsForPosts:(id)sender {
  for (NSString *siteKey in watchedQuestions) {
    NSDictionary *site = [persistence siteForKey:siteKey];
    NSArray *ids = [watchedQuestions objectForKey:siteKey];
    ids = [ids arrayByAddingObjectsFromArray:[watchedAnswers objectForKey:siteKey]];
    if ([ids count] == 0) {
      continue;
    }
    
    NSString *api = [site objectForKey:@"api_endpoint"];
    
    QueryToolSuccessHandler handler = ^(NSDictionary *result) {
      [self processCommentsToUser:result forSite:siteKey];
    };
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:3];
    [parameters setObject:@"10" forKey:@"pagesize"];
    [parameters setObject:cutoffDate(10) forKey:@"fromdate"];
    [parameters setObject:@"creation" forKey:@"sort"];
    NSString *idsJoined = [ids componentsJoinedByString:@";"];
    
    [queryTool execute:api 
            withMethod:[NSString stringWithFormat:@"posts/%@/comments", idsJoined]
         andParameters:parameters
             onSuccess:handler];
  }
}




- (NSArray *)interestingSites {
  NSArray *sites = [persistence objectForKey:@"most_used_sites"];
  if (sites == nil) {
    return [NSArray array];
  }
  
  if ([sites count] > 5) {
    NSRange range;
    range.location = 0;
    range.length = 5;
    return [sites subarrayWithRange:range];
  } else {
    return sites;
  }
}

// experimental

//- (void) receiveSleepNote: (NSNotification*) note {
//  NSLog(@"NewtMenulet#receiveSleepNote: %@", [note name]);
//}
//
//- (void) receiveWakeNote: (NSNotification*) note {
//  NSLog(@"NewtMenulet#receiveSleepNote: %@", [note name]);
//  [NSString stringWithFormat:@""];
//}


@end
