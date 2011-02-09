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


@implementation SitesTableController

-(void)dealloc {
  if (toDisplay) {
    [toDisplay release];
  }
  
  [super dealloc];
}

- (void)setUpWithSites:(NSDictionary *)sites_
        andPreferences:(NSMutableDictionary *)preferences_ {
  sites = sites_;
  preferences = preferences_;
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
  
  // I fucking hate objective c collections
  
  // filter sites by name
  NSMutableArray *buffer = [NSMutableArray arrayWithCapacity:[sites count]];
  for (NSString *siteUrl in sites) {
    NSDictionary *site = [sites objectForKey:siteUrl];
    NSString *siteName = [[site objectForKey:@"name"] lowercaseString];
    if ([filter length] == 0 || [siteName rangeOfString:filter].location != NSNotFound) {
      [buffer addObject:siteUrl];
    }
  }
  
  toDisplay = [buffer sortedArrayUsingComparator:^NSComparisonResult(id key1, id key2) {
    NSNumber *order1 = [[sites objectForKey:key1] objectForKey:@"order"];
    NSNumber *order2 = [[sites objectForKey:key2] objectForKey:@"order"];
    NSNumber *enabled1 = [[preferences objectForKey:key1] objectForKey:@"enabled"];
    NSNumber *enabled2 = [[preferences objectForKey:key2] objectForKey:@"enabled"];
    if (enabled1 == NULL) enabled1 = [NSNumber numberWithBool:FALSE];
    if (enabled2 == NULL) enabled2 = [NSNumber numberWithBool:FALSE];
    
    if ([enabled1 isEqual:enabled2]) {
      return ([order1 intValue] < [order2 intValue]) ? NSOrderedAscending : NSOrderedDescending;
    } else {
      return ([enabled1 intValue] > [enabled2 intValue]) ? NSOrderedAscending : NSOrderedDescending;
    }
  }];
  
  [toDisplay retain];
}


- (int)numberOfRowsInTableView:(NSTableView *)tableView {
  return [toDisplay count];
}

- (id)tableView:(NSTableView *)tableView
    objectValueForTableColumn:(NSTableColumn *)tableColumn
                          row:(int)row {
  id columnType = [tableColumn identifier];
  NSString *siteKey = [toDisplay objectAtIndex:row];
  
  NSDictionary *sitePreferences = [preferences objectForKey:siteKey];
  if (sitePreferences == NULL) {
    sitePreferences = [NSDictionary dictionary];
  }
  
  if ([columnType isEqual:@"site"]) {
    return [NSArray arrayWithObjects:
            [sites objectForKey:siteKey],
            sitePreferences,
            NULL];
  } else if ([columnType isEqual:@"enabled"]) {
    return [sitePreferences objectForKey:@"enabled"];
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
    NSDictionary *current = [preferences objectForKey:siteKey];
    NSMutableDictionary *next;
    if (current == NULL) {
      next = [NSMutableDictionary dictionary];
    } else {
      next = [NSMutableDictionary dictionaryWithDictionary:current];
    }
    [next setObject:object forKey:@"enabled"];
    [preferences setObject:next forKey:siteKey];
    
    [table reloadData];
  }
  
  [preferencePane loadConfigurationForSite:siteKey];
}

@end
