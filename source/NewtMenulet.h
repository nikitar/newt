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

#import <Cocoa/Cocoa.h>
#import <Growl/Growl.h>
#import "JSON.h"
#import "PreferencePaneController.h"
#import "StackExchangeQueryTool.h"
#import "NewtPersistence.h"



// Performs polling of SE API
//@protocol StackExchangeInterviewer
//- (id)initWithApp:(id *)mainObject;
//@end

@interface NewtMenulet : NSObject <GrowlApplicationBridgeDelegate> {
  IBOutlet NSMenu *theMenu;
  IBOutlet NSMenuItem *disableButton;
  IBOutlet NSMenuItem *silentButton;
  
  NewtPersistence *persistence;
  
 @private
  NSMutableDictionary *viewedPosts;
  BOOL enabled;
  BOOL silent;
  
  // this posts are watched for comments (and questions - also for answers)
  // grouped by site
  NSMutableDictionary *watchedQuestions;
  NSMutableDictionary *watchedAnswers;
  
  NSImage *menuIconOn;
  NSImage *menuIconOff;
  NSImage *menuIconAlert;
  
  NSTimer *questionTimer;
  NSTimer *postsByUserTimer;
  NSTimer *commentsToUserTimer;
  NSTimer *commentsOnPostsTimer;
  NSTimer *answersOnPostsTimer;
  NSTimer *userInfoTimer;

  NSTimer *sitesDataTimer;

  NSStatusItem *statusItem;
  PreferencePaneController *prefPane;
  StackExchangeQueryTool *queryTool;
  
  URLConnectionErrorHandler defaultErrorHandler;
}

- (IBAction)retrieveQuestions:(id)sender;
- (IBAction)displayPreferences:(id)sender;
- (IBAction)toggleDisable:(id)sender;
- (IBAction)toggleSilent:(id)sender;
- (IBAction)openAboutPanel:(id)sender;
- (IBAction)quit:(id)sender;
- (void)growlNotificationWasClicked:(id)clickContext;

@end
