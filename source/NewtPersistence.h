/*
 * Created by Nikita Rybak on Feb 10 2011.
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
#import "StackExchangeQueryTool.h"


/**
 All application data are stored in user preferences (NSUserPreferences).

 Possible keys:
  - sites - NSDictionary with entry for each SE site
  - user_global_id - association_id value from /users/{user_id} request
  - user_flair - user flair data, image from stackexchange.com/users/flair/{user_global_id}.png
 
 Possible keys for site object:
  - every key from stackauth.com/{v}/sites
  - enabled - whether new questions will be polled from the site
  - favourite_tags - list of tags for this site user entered in preferences pane
  - user_id, user_type, user_name, user_reputation and user_email_hash  -  from stackauth.com/{v}/users/{user_id}/associated
  - icon_data - NSData object with site icon.
 */
@interface NewtPersistence : NSObject {
  
 @private
  NSUserDefaults *persistence;
  
  // sites data are cached
  NSMutableDictionary *sites;
}

- (id)init;
- (void)synchronize;

- (NSDictionary *)sites;
- (NSMutableDictionary *)siteForKey:(NSString *)key;
- (void)setObject:(id)value
          forSite:(NSString *)siteKey
           andKey:(NSString *)propertyKey;

- (id)objectForKey:(NSString *)key;
- (void)setObject:(id)object
           forKey:(NSString *)key;

- (void)updateSites:(StackExchangeQueryTool *)queryTool;

@end
