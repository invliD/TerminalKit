#import "TKTerminalScreen.h"

@import AudioToolbox;

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

	NSMutableArray *mScrollbackBuffer;
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
	[mView setNeedsDisplayInRect:[mView rectFromVTRect:rect]];
	return 1;
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
	// TODO: Add to config.
	AudioServicesPlayAlertSound(kSystemSoundID_UserPreferredAlert);
	return 1;
}

- (int) pushScrollbackLine:(VTermScreenCell*)cells cols:(int)cols {
	// TODO: Add scrollback limit

	VTermScreenCell* cells_copy = malloc(sizeof(cells[0]) * cols);
	memcpy(cells_copy, cells, sizeof(cells[0]) * cols);
	[mScrollbackBuffer addObject:@[@(cols), [NSValue valueWithPointer:cells_copy]]];
	return 1;
}

- (int) popScrollbackLine:(VTermScreenCell*)cells cols:(int)cols {
	if ([mScrollbackBuffer count] == 0)
		return 0;

	NSArray *line = [mScrollbackBuffer lastObject];
	[mScrollbackBuffer removeLastObject];

	int cols_saved = [line[0] intValue];
	VTermScreenCell* cells_saved;
	[line[1] getValue:&cells_saved];

	memcpy(cells, cells_saved, cols < cols_saved ? cols : cols_saved);
	free(cells_saved);
	return 1;
}

@end
