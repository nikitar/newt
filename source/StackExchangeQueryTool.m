/*
 * Created by Nikita Rybak on Feb 3 2011.
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

#import "StackExchangeQueryTool.h"


@implementation StackExchangeQueryTool

- (id)init {
  URLConnectionErrorHandler error = ^(id error) {
    NSLog(@"ERROR - %@", error);
  };
  return [self initWithDefaultErrorHandler:error];
}


- (id)initWithDefaultErrorHandler:(URLConnectionErrorHandler) error {
  self = [super init];
  if (self != nil) {
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *path = [bundle pathForResource:@"StackExchangeAPI" ofType:@"plist"];
    NSDictionary *dic = [NSDictionary dictionaryWithContentsOfFile:path];
    apiVersion = [[dic objectForKey:@"Version"] retain];
    apiKey = [[dic objectForKey:@"Key"] retain];
    
    jsonParser = [[SBJsonParser alloc] init];
    defaultErrorHandler = [error retain];
    
    if (DEBUG) {
      callsRecent = 0;
      callsTotal = 0;
      NSLog(@"QueryTool: creating usage report timer");
      
      usageReporting = [[NSTimer scheduledTimerWithTimeInterval:60*60
                                                         target:self
                                                       selector:@selector(reportUsage)
                                                       userInfo:nil
                                                        repeats:YES] retain];
    }
  }
  return self;
}

- (void)dealloc {
  [jsonParser release];
  [apiVersion release];
  [apiKey release];
  [defaultErrorHandler release];
  
  [super dealloc];
}


- (void)execute:(NSString *)apiEndpoint
     withMethod:(NSString *)method
  andParameters:(NSDictionary *)parameters
      onSuccess:(QueryToolSuccessHandler)success {
  if (DEBUG) {
    callsRecent++;
  }
  
  // concatenate parameters
  NSMutableString* paramString = [NSMutableString stringWithCapacity:40];
  if (apiKey != nil) {
    parameters = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [parameters setObject:apiKey forKey:@"key"];
  }
  for (NSString *key in parameters) {
    NSString *value = [parameters objectForKey:key];
    if ([paramString length] > 0) {
      [paramString appendString:@"&"];
    } else {
      [paramString appendString:@"?"];
    }
    [paramString appendFormat:@"%@=%@", key, value];
  }
  
  NSString *url = [NSString stringWithFormat:@"%@/%@/%@%@", apiEndpoint, apiVersion, method, paramString];
//  NSLog(@"query: %@", url);
  
  NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString: url]];
  
  URLConnectionSuccessHandler connectionSuccess = ^(NSData *response) {
    NSString *responseString = [[[NSString alloc] initWithData:response
                                                      encoding:NSUTF8StringEncoding] autorelease];
    
    NSDictionary *dict = [jsonParser objectWithString:responseString error:nil];
    
    NSDictionary *error = [dict objectForKey:@"error"];
    if (error) {
      NSString *msg = [NSString stringWithFormat:@"API error! %@", [error objectForKey:@"message"]];
      defaultErrorHandler(msg);
      return;
    }
    
    success(dict);
  };
  
  URLConnectionDelegate *delegate = [[[URLConnectionDelegate alloc] initWithSuccessHandler:connectionSuccess
                                                                           andErrorHandler:defaultErrorHandler] autorelease];
 
  // will be released from delegate
  NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request
                                                                delegate:delegate];
  if (!connection) {
    // some day, we'll have error handler
    defaultErrorHandler([NSString stringWithFormat:@"Couldn't open connection for url %@", url]);
  }
}

- (void)reportUsage {
  callsTotal += callsRecent;
  NSLog(@"QueryTool: Calls over last interval %d", callsRecent);
  NSLog(@"QueryTool: Calls total %d", callsTotal);
  callsRecent = 0;
}

@end
