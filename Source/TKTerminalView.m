#import "TKTerminalViewPrivate.h"
#import "TKTerminalScreen.h"

// TODO: Move to config (or calculate from font size)
#define CELL_WIDTH 8
#define CELL_HEIGHT 19

@implementation TKTerminalView {
	VTerm *mVTerm;
	VTermScreen *mVTermScreen;

	TKTerminalScreen *mTerminalScreen;
	NSFileHandle *mFileHandle;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	if (self == nil)
		return nil;

	[self initialize];
	return self;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
	self = [super initWithFrame:frameRect];
	if (self == nil)
		return nil;

	[self initialize];
	return self;
}

- (void)initialize {
	// Create vterm
	[self updateSize];
	mVTerm = vterm_new(_currentWidth, _currentHeight);
	vterm_set_utf8(mVTerm, 1);

	// Set up state
	VTermState *state = vterm_obtain_state(mVTerm);
	vterm_state_set_bold_highbright(state, 1);

	// Set up colors
	// TODO: Move to config.
	VTermColor default_fg = { 0, 0, 0 };
	VTermColor default_bg = { 200, 200, 200 };
	vterm_state_set_default_colors(state, &default_fg, &default_bg);
	// TODO: Set color palette.

	// Set up screen
	mVTermScreen = vterm_obtain_screen(mVTerm);
	vterm_screen_enable_altscreen(mVTermScreen, 1);
	vterm_screen_set_damage_merge(mVTermScreen, VTERM_DAMAGE_SCROLL);
	mTerminalScreen = [TKTerminalScreen screenWithTerminalView:self vTerm:mVTerm];
}

- (void)dealloc {
	vterm_free(mVTerm);
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	// TODO: Possibly disable mFileHandle's notifications?
}

- (void)updateSize {
	CGSize viewSize = self.bounds.size;
	_currentWidth = viewSize.width / CELL_WIDTH;
	_currentHeight = viewSize.height / CELL_HEIGHT;
}

- (void)connectToFD:(int)fd {
	mFileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd];
	[mFileHandle readInBackgroundAndNotify];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readFromPipe:) name:NSFileHandleReadCompletionNotification object:mFileHandle];

	vterm_screen_reset(mVTermScreen, 1);

	VTermState *state = vterm_obtain_state(mVTerm);
	vterm_state_set_termprop(state, VTERM_PROP_CURSORSHAPE, &(VTermValue){ .number = VTERM_PROP_CURSORSHAPE_BLOCK });
}

- (void)readFromPipe:(NSNotification*)notification {
	NSData *data = [notification userInfo][NSFileHandleNotificationDataItem];
	vterm_input_write(mVTerm, [data bytes], [data length]);

	vterm_screen_flush_damage(mVTermScreen);

	// Read again.
	[mFileHandle readInBackgroundAndNotify];
}

@end
