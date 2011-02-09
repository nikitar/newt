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

#import "SiteTableCell.h"


@implementation SiteTableCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
  NSArray *object = [self objectValue];
	NSDictionary *info = [object objectAtIndex:0];
	NSDictionary *preferences = [object objectAtIndex:1];
  if (preferences == NULL) {
    preferences = [NSDictionary dictionary];
  }
  
  // draw site name
  NSString *siteName = [info objectForKey:@"name"];
	NSPoint textPoint;
	textPoint.x = cellFrame.origin.x + 50;
	textPoint.y = cellFrame.origin.y;
	NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys: 
                                  [NSColor blackColor], NSForegroundColorAttributeName, 
                                  [NSFont systemFontOfSize:15], NSFontAttributeName,
                                  nil];
	[siteName drawAtPoint:textPoint withAttributes:textAttributes];
  
  
  // draw site tags
  NSArray *tags = [preferences objectForKey:@"tags"];
  if (tags == NULL) {
    tags = [NSArray array];
  }
  NSString *tagsTitle = [tags componentsJoinedByString:@", "];
  if ([tagsTitle length] == 0) {
//    tagsTitle = @"";
  }

	textPoint.x = cellFrame.origin.x + 50;
	textPoint.y = cellFrame.origin.y + 20;
  NSColor *tagsColor = ([self isHighlighted]) ? [NSColor lightGrayColor] : [NSColor darkGrayColor];
	textAttributes = [NSDictionary dictionaryWithObjectsAndKeys: 
                                  tagsColor, NSForegroundColorAttributeName, 
                                  [NSFont systemFontOfSize:13], NSFontAttributeName,
                                  nil];
  [tagsTitle drawAtPoint:textPoint withAttributes:textAttributes];

  
  // draw site icon
  NSData *imageData = [info objectForKey:@"icon_data"];
  NSImage *image = [[NSImage alloc] initWithData:imageData];
  NSSize newSize;
  newSize.height = 40;
  newSize.width = 40;
  [image setSize:newSize];

  [image setFlipped:YES];
  
  [image drawAtPoint:cellFrame.origin
            fromRect:NSZeroRect
           operation:NSCompositeSourceOver
            fraction:1.0];
  [image release];
}

@end
