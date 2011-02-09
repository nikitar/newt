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

#import "NewtApplication.h"


@implementation NewtApplication

- (void) sendEvent:(NSEvent *)event {
  if ([event type] == NSKeyDown) {
    if (([event modifierFlags] & NSDeviceIndependentModifierFlagsMask) == NSCommandKeyMask) {
      if ([[event charactersIgnoringModifiers] isEqualToString:@"x"]) {
        if ([self sendAction:@selector(cut:) to:nil from:self])
          return;
      }
      else if ([[event charactersIgnoringModifiers] isEqualToString:@"c"]) {
        if ([self sendAction:@selector(copy:) to:nil from:self])
          return;
      }
      else if ([[event charactersIgnoringModifiers] isEqualToString:@"v"]) {
        if ([self sendAction:@selector(paste:) to:nil from:self])
          return;
      }
      else if ([[event charactersIgnoringModifiers] isEqualToString:@"z"]) {
        if ([self sendAction:@selector(undo:) to:nil from:self])
          return;
      }
      else if ([[event charactersIgnoringModifiers] isEqualToString:@"a"]) {
        if ([self sendAction:@selector(selectAll:) to:nil from:self])
          return;
      }
    }
  }
  [super sendEvent:event];
}


- (void) receiveSleepNote: (NSNotification*) note
{
  NSLog(@"NewtApplication#receiveSleepNote: %@", [note name]);
}

- (void) receiveWakeNote: (NSNotification*) note
{
  NSLog(@"NewtApplication#receiveSleepNote: %@", [note name]);
}

@end
