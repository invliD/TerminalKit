#import "TKTerminalView.h"

#import "vterm.h"

@interface TKTerminalView ()

- (CGRect)rectFromPosition:(VTermPos)pos width:(NSUInteger)width;
- (CGRect)rectFromVTRect:(VTermRect)vtRect;

@end
