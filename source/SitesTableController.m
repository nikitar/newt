/*
 * Created by Nikita Rybak on Feb 4 2011.
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

#import "SitesTableController.h"
#import "PreferencePaneController.h"

@interface SitesTableController()
- (void)prepareData:(NSString *)filter;
@end


NSComparisonResult compareInt(int i1, int i2) {
  if (i1 < i2) {
    return NSOrderedAscending;
  } else if (i1 > i2) {
    return NSOrderedDescending;
  } else {
    return NSOrderedSame;
  }
}


// compare sites 1) by 'enabled' 2) by user reputation and 3) by creation date
NSInteger sortSites(NSString *key1, NSString *key2, void *context) {
  NSDictionary *sites = context;
  NSDictionary *site1 = [sites objectForKey:key1];
  NSDictionary *site2 = [sites objectForKey:key2];
  
  NSNumber *order1 = [site1 objectForKey:@"order"];
  NSNumber *order2 = [site2 objectForKey:@"order"];
  NSNumber *enabled1 = [site1 objectForKey:@"enabled"];
  NSNumber *enabled2 = [site2 objectForKey:@"enabled"];
  if (enabled1 == NULL) enabled1 = [NSNumber numberWithBool:FALSE];
  if (enabled2 == NULL) enabled2 = [NSNumber numberWithBool:FALSE];
  int rep1 = [[site1 objectForKey:@"user_reputation"] intValue];
  int rep2 = [[site2 objectForKey:@"user_reputation"] intValue];
  
  if ([enabled1 isEqual:enabled2]) {
    if (rep1 == rep2) {
      return compareInt([order1 intValue], [order2 intValue]);
    } else {
      return compareInt(rep2, rep1);
    }
  } else {
    return compareInt([enabled2 intValue], [enabled1 intValue]);
  }
}



@implementation SitesTableController

-(void)dealloc {
  if (toDisplay) {
    [toDisplay release];
  }
  
  [super dealloc];
}

- (void)initWithPersistence:(NewtPersistence *)persistence_ {
  persistence = persistence_;
  [self prepareData:@""];
}

- (void)applyFilter:(NSString *)filter {
  [self prepareData:filter];
  [table reloadData];
  
  // remove selection from table
  [table deselectAll:self];
  [preferencePane loadConfigurationForSite:NULL];
}

- (void)prepareData:(NSString *)filter {
  filter = [filter lowercaseString];
  
  if (toDisplay) {
    [toDisplay release];
  }
  
  NSDictionary *sites = [persistence sites];
  
  // I fucking hate objective c collections
  
  // filter sites by name
  NSMutableArray *buffer = [NSMutableArray arrayWithCapacity:[sites count]];
  for (NSString *siteUrl in sites) {
    NSDictionary *site = [sites objectForKey:siteUrl];
    NSString *siteName = [[site objectForKey:@"name"] lowercaseString];
    
    NSMutableArray *urls = [NSMutableArray arrayWithObject:siteUrl];
    NSArray *aliases = [site objectForKey:@"aliases"];
    if (aliases != nil) {
      [urls addObjectsFromArray:aliases];
    }
    
    // check site name
    if ([filter length] == 0 || [siteName rangeOfString:filter].location != NSNotFound) {
      [buffer addObject:siteUrl];
      continue;
    }
    
    // check site urls
    for (NSString *url in urls) {
      NSRange pos = [url rangeOfString:filter];
      if (pos.location != NSNotFound) {
        // check that start position is not inside '.stackexchange.com' suffix
        // including it in search is meaningless
        if ([url hasSuffix:@".stackexchange.com"] && pos.location >= ([url length] - [@".stackexchange.com" length])) {
          continue;
        }
        
        [buffer addObject:siteUrl];
        break;
      }
    }
  }
  
  toDisplay = [buffer sortedArrayUsingFunction:sortSites context:(void *)sites];
  [toDisplay retain];
}


- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
  return [toDisplay count];
}

- (id)tableView:(NSTableView *)tableView
    objectValueForTableColumn:(NSTableColumn *)tableColumn
                          row:(NSInteger)row {
  id columnType = [tableColumn identifier];
  NSString *siteKey = [toDisplay objectAtIndex:row];
  
  NSDictionary *site = [persistence siteForKey:siteKey];
  
  if ([columnType isEqual:@"site"]) {
    return site;
  } else if ([columnType isEqual:@"enabled"]) {
    return [site objectForKey:@"enabled"];
  } else {
    return NULL;
  }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
  int row = [table selectedRow];
  if (row < 0) {
    [preferencePane loadConfigurationForSite:NULL];
  } else {
    [preferencePane loadConfigurationForSite:[toDisplay objectAtIndex:row]];
  }
}

//- (BOOL)selectionShouldChangeInTableView:(NSTableView *)aTableView {
//  int row = [table selectedRow];
//  if (row >= 0) {
//    [preferencePane saveConfigurationForSite:[toDisplay objectAtIndex:row]];
//  }
//  return TRUE;
//}

- (void)tableView:(NSTableView *)tableView
   setObjectValue:(id)object 
   forTableColumn:(NSTableColumn *)tableColumn
              row:(NSInteger)rowIndex {
  NSString *siteKey = [toDisplay objectAtIndex:rowIndex];
    
  if ([[tableColumn identifier] isEqual:@"enabled"]) {
    [persistence setObject:object
                   forSite:siteKey
                    andKey:@"enabled"];
    [table reloadData];
  }
  
  [preferencePane loadConfigurationForSite:siteKey];
}

@end
