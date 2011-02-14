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

- (id) init {
  self = [super init];
  if (self != nil) {
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *path = [bundle pathForResource:@"StackExchangeAPI" ofType:@"plist"];
    NSDictionary *dic = [NSDictionary dictionaryWithContentsOfFile:path];
    apiVersion = [[dic objectForKey:@"Version"] retain];
    apiKey = [[dic objectForKey:@"Key"] retain];
    
    jsonParser = [[SBJsonParser alloc] init];
  }
  return self;
}

- (void) dealloc {
  [jsonParser release];
  [apiVersion release];
  [apiKey release];
  
  [super dealloc];
}


- (void)execute:(NSString *)apiEndpoint
     withMethod:(NSString *)method
  andParameters:(NSDictionary *)parameters
      onSuccess:(QueryToolSuccessHandler)success {
  
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
  
  URLConnectionDelegate *delegate = [[[URLConnectionDelegate alloc] initWithSuccessHandler:^(NSData *response) {
//    NSLog(@"StackExchangeQueryTool delegate");
    // convert NSData to dictionary 
    NSString *responseString = [[NSString alloc] initWithData:response
                                                     encoding:NSUTF8StringEncoding];
    
    success([jsonParser objectWithString:responseString error:nil]);
    [responseString release];
  }] autorelease];
 
  // will be released from delegate
  NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request
                                                                delegate:delegate];
  if (!connection) {
    // some day, we'll have error handler
    NSLog(@"Couldn't open connection for url %@", url);
  }
}


@end
