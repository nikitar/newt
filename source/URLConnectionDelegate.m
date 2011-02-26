/*
 * Created by Nikita Rybak on Feb 5 2011.
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

#import "URLConnectionDelegate.h"

@implementation URLConnectionDelegate

- (id) initWithSuccessHandler:(URLConnectionSuccessHandler) success {
  return [self initWithSuccessHandler:success
                      andErrorHandler:nil];
}

- (id)initWithSuccessHandler:(URLConnectionSuccessHandler) success
             andErrorHandler:(URLConnectionErrorHandler) error {
  self = [super init];
  if (self != nil) {
    receivedData = [[NSMutableData data] retain];
//    successHandler = Block_copy(success);
    successHandler = [success copy];
    if (error) {
      errorHandler = [error copy];
    } else {
      errorHandler = nil;
    }
  }
  
  return self;
}


-(void)dealloc {
  [super dealloc];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
  [receivedData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
  if (errorHandler) {
    errorHandler([error localizedDescription]);
  } else {
    NSLog(@"Connection failed! Error - %@", [error localizedDescription]);
  }
  
  [receivedData release];
  [successHandler release];
  if (errorHandler) {
    [errorHandler release];
  }
  [connection release];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
  successHandler(receivedData);
  
  [receivedData release];
//  Block_release(successHandler);
  [successHandler release];
//  NSLog(@"connectionDidFinishLoading %d", errorHandler);
  if (errorHandler) {
    [errorHandler release];
  }
  
  [connection release];
}
@end
