#import <Cocoa/Cocoa.h>

@interface TKTerminalView : NSView

@property (nonatomic) unsigned int currentWidth;
@property (nonatomic) unsigned int currentHeight;

- (void)setDefaultTextColor:(NSColor*)fgColor backgroundColor:(NSColor*)bgColor;
- (void)setPaletteColor:(NSColor*)color forIndex:(int)index;
- (void)setPaletteColors:(NSArray*)colors;

- (void)connectToFD:(int)fd;

@end
