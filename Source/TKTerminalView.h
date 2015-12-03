#import <Cocoa/Cocoa.h>

@interface TKTerminalView : NSView

@property (nonatomic) unsigned int currentWidth;
@property (nonatomic) unsigned int currentHeight;

- (void)connectToFD:(int)fd;

@end
