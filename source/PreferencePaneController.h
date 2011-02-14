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

#import <Cocoa/Cocoa.h>
#import <PreferencePanes/PreferencePanes.h>
#import <CoreFoundation/CoreFoundation.h>
#import "SiteTableCell.h"
#import "SitesTableController.h"
#import "StackExchangeQueryTool.h"
#import "NewtPersistence.h"


#define FETCHING_USER_PROFILE  201

// NSWindowDelegate protocol doesn't exist in OS X 10.5, so can't implement it. Ignore warning.
@interface PreferencePaneController : NSPreferencePane {
  IBOutlet SitesTableController *sitesTable;

  IBOutlet NSSearchField *siteSearchField;
  IBOutlet NSTokenField *tagsField;
  IBOutlet NSButton *launchOnStartup;
  
  IBOutlet NSTextField *profileURL;
  IBOutlet NSImageView *profileImage;
  IBOutlet NSWindow *profileInputWindow;
  IBOutlet NSProgressIndicator *profileProgressIndicator;
  IBOutlet NSButton *searchUserButton;
  IBOutlet NSTextField *profileSearchError;
  
  int activity;
  
 @private
  // currently edited site
  NSString *siteInEdit;
  
  StackExchangeQueryTool *queryTool;
  NewtPersistence *persistence;

  NSWindow *window;
}

- (IBAction)updateFilterAction:(id)sender;
- (IBAction)updateStartupLaunchAction:(id)sender;
- (IBAction)selectUserButton:(id)sender;
- (IBAction)confirmUserSelection:(id)sender;

- (void)displayPreferences;
- (void)closePreferences;
- (void)loadConfigurationForSite:(NSString *)key;
- (void)saveConfigurationForCurrentSite;
- (void)flushPreferences;
- (IBAction)updateProfileURL;

- (void)setPersistence:(NewtPersistence *) persistence_;

//- (void)textDidBeginEditing:(NSNotification *)notification;
//- (void)textDidEndEditing:(NSNotification *)aNotification;

@end
