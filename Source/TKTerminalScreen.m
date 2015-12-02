#import "TKTerminalScreen.h"

static inline TKTerminalScreen *obj(void *user_data) {
	return (__bridge TKTerminalScreen*)user_data;
}

static int term_damage(VTermRect rect, void *user_data) {
	return [obj(user_data) damageInRect: rect];
}

static int term_moverect(VTermRect dest, VTermRect src, void *user_data) {
	return [obj(user_data) moveRectFrom:src to:dest];
}

static int term_movecursor(VTermPos pos, VTermPos oldpos, int visible, void *user_data) {
	return [obj(user_data) moveCursorFrom:oldpos to:pos visible:visible];
}

static int term_settermprop(VTermProp prop, VTermValue *val, void *user_data) {
	return [obj(user_data) setTermValue:val forProp:prop];
}

static int term_bell(void *user_data) {
	return [obj(user_data) triggerBell];
}

static int term_sb_pushline(int cols, const VTermScreenCell *cells, void *user_data) {
	return [obj(user_data) pushScrollbackLine:(VTermScreenCell*)cells cols:cols];
}

static int term_sb_popline(int cols, VTermScreenCell *cells, void *user_data) {
	return [obj(user_data) popScrollbackLine:(VTermScreenCell*)cells cols:cols];
}

static VTermScreenCallbacks screen_callbacks = {
	.damage      = term_damage,
	.moverect    = term_moverect,
	.movecursor  = term_movecursor,
	.settermprop = term_settermprop,
	.bell        = term_bell,
	.sb_pushline = term_sb_pushline,
	.sb_popline  = term_sb_popline,
};

@implementation TKTerminalScreen {
	TKTerminalView *mView;
	VTerm* mVTerm;
	VTermScreen* mVTermScreen;
}

+ (instancetype)screenWithTerminalView:(TKTerminalView*)view vTerm:(VTerm*)vterm {
    return [[self alloc] initWithTerminalView:view vTerm:vterm];
}

- (instancetype)initWithTerminalView:(TKTerminalView*)view vTerm:(VTerm*)vterm {
    mView = view;
    mVTerm = vterm;
    mVTermScreen = vterm_obtain_screen(mVTerm);
    vterm_screen_set_callbacks(mVTermScreen, &screen_callbacks, (__bridge void *)(self));
    return self;
}

- (int) damageInRect:(VTermRect)rect {
	return 0;
}

- (int) moveRectFrom:(VTermRect)src to:(VTermRect)dest {
    return 0;
}

- (int) moveCursorFrom:(VTermPos)oldpos to:(VTermPos)pos visible:(int)visible {
    return 0;
}

- (int) setTermValue:(VTermValue*)val forProp:(VTermProp)prop {
    return 0;
}

- (int) triggerBell {
    return 0;
}

- (int) pushScrollbackLine:(VTermScreenCell*)cells cols:(int)cols {
    return 0;
}

- (int) popScrollbackLine:(VTermScreenCell*)cells cols:(int)cols {
    return 0;
}

@end
