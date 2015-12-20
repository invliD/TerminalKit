#import <Foundation/Foundation.h>
#import "vterm.h"

#import "TKTerminalViewPrivate.h"

@class TKTerminalView;

@interface TKTerminalScreen : NSObject

@property (nonatomic) VTermPos cursorPosition;

+ (instancetype)screenWithTerminalView:(TKTerminalView*)view vTerm:(VTerm*)vterm;
- (instancetype)initWithTerminalView:(TKTerminalView*)view vTerm:(VTerm*)vterm;

- (int)damageInRect:(VTermRect)rect;
- (int)moveRectFrom:(VTermRect)src to:(VTermRect)dest;
- (int)moveCursorFrom:(VTermPos)oldpos to:(VTermPos)pos visible:(int)visible;
- (int)setTermValue:(VTermValue*)val forProp:(VTermProp)prop;
- (int)triggerBell;
- (int)pushScrollbackLine:(VTermScreenCell*)cells cols:(int)cols;
- (int)popScrollbackLine:(VTermScreenCell*)cells cols:(int)cols;

@end
