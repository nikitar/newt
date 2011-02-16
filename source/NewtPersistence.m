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


#import "NewtPersistence.h"


@implementation NewtPersistence

- (id)init {
  self = [super init];
  if (self != nil) {
    persistence = [[NSUserDefaults standardUserDefaults] retain];
    
    NSDictionary *sites_ = [persistence objectForKey:@"sites"];
    if (sites_ == nil) {
      // running for the first time?
      sites = [[NSMutableDictionary dictionary] retain];
    } else {
      sites = [[NSMutableDictionary dictionaryWithCapacity:[sites_ count]] retain];
      for (NSString *siteKey in sites_) {
        NSDictionary *site_ = [sites_ objectForKey:siteKey];
        [sites setObject:[NSMutableDictionary dictionaryWithDictionary:site_] forKey:siteKey];
      }
    }

  }
  return self;
}

- (void)dealloc {
  [persistence release];
  [sites release];
  
  [super dealloc];
}

- (void)synchronize {
  [persistence setObject:sites forKey:@"sites"];
  [persistence synchronize];
}


- (NSDictionary *)sites {
  return sites;
}

- (NSMutableDictionary *)siteForKey:(NSString *)key {
  return [[self sites] objectForKey:key];
}
- (void)setObject:(id)value
         forSite:(NSString *)siteKey
          andKey:(NSString *)propertyKey {
  
  NSMutableDictionary* site = [self siteForKey:siteKey];
  if (site == nil) {
    site = [NSMutableDictionary dictionaryWithObject:value forKey:propertyKey];
    [sites setObject:site forKey:siteKey];
  } else {
    [site setObject:value forKey:propertyKey];
  }
}


- (id)objectForKey:(NSString *)key {
  return [persistence objectForKey:key];
}
- (void)setObject:(id)object
           forKey:(NSString *)key {
  [persistence setObject:object forKey:key];
}

//- (NSString *)globalUserId {
//  return [persistence objectForKey:@"user_global_id"];
//}
//- (void)setGlobalUserId:(NSString *)globalUserId {
//  [persistence setObject:globalUserId forKey:@"user_global_id"];
//}


- (void)updateSites:(StackExchangeQueryTool *)queryTool {
  
  // uncomment to update sites information unconditionally
//  [persistence setObject:NULL forKey:@"sites_updated"];
//  [persistence setObject:NULL forKey:@"sites"];
//  [persistence synchronize];
  
  
  
  NSDate *lastUpdate = [persistence objectForKey:@"sites_updated"];
  if (lastUpdate == NULL ||
      ([lastUpdate timeIntervalSinceReferenceDate] + 5*24*60*60 < [[NSDate date] timeIntervalSinceReferenceDate])) {
    NSLog(@"Refreshing SE sites information...");
    
    QueryToolSuccessHandler handleSites = ^(NSDictionary *result) {
      NSArray *sites_ = [result objectForKey:@"api_sites"];
      
      // fucking final requirement
      NSMutableArray *processed = [NSMutableArray arrayWithObject:[NSNumber numberWithInt:0]];
      
      int sites_total = [sites_ count];
      for (int i = 0; i < sites_total; ++i) {
        NSDictionary *site = [sites_ objectAtIndex:i];
        NSString *siteKey = [site objectForKey:@"site_url"];
        
        for (NSString *key in site) {
          [self setObject:[site objectForKey:key]
                  forSite:siteKey
                   andKey:key];
        }
        [self setObject:[NSNumber numberWithInt:i]
                forSite:siteKey
                 andKey:@"order"];
        
        NSString *iconUrl = [site objectForKey:@"icon_url"];
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString: iconUrl]];
                
        // we'll fetch site icons asynchronously, so application won't freeze
        // it also turns out to be much faster
        URLConnectionDelegate *delegate = [[[URLConnectionDelegate alloc] initWithSuccessHandler:^(NSData *response) {
          [self setObject:response
                  forSite:siteKey
                   andKey:@"icon_data"];
          
          // this is how '++processed' looks in fucking objective c
          int count = [[processed objectAtIndex:0] intValue] + 1;
          [processed replaceObjectAtIndex:0 withObject:[NSNumber numberWithInt:count]];
          
          if (count == sites_total) {
            NSLog(@"processing's done, %i sites found", sites_total);
            [persistence setObject:[NSDate date] forKey:@"sites_updated"];
            [self synchronize];
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



@end
