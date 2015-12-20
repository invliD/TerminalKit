#import "TKTerminalViewPrivate.h"
#import "TKTerminalScreen.h"
#import "TKKeyMap.h"
#import "TKFontManager.h"

// TODO: Move to config (or calculate from font size)
#define CELL_WIDTH 8
#define CELL_HEIGHT 19

@implementation TKTerminalView {
	TKFontManager *mFontManager;

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
	// TODO: Move font and font size to config.
	mFontManager = [TKFontManager managerWithFontName:@"Menlo" size:14];

	// Create vterm
	[self updateSize];
	mVTerm = vterm_new(_currentWidth, _currentHeight);
	vterm_set_utf8(mVTerm, 1);

	// Set up state
	VTermState *state = vterm_obtain_state(mVTerm);
	vterm_state_set_bold_highbright(state, 1);

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

- (void)setDefaultTextColor:(NSColor*)fgColor backgroundColor:(NSColor*)bgColor {
	VTermState *state = vterm_obtain_state(mVTerm);
	VTermColor vtFGColor = [self vtColorFromColor:fgColor];
	VTermColor vtBGColor = [self vtColorFromColor:bgColor];
	vterm_state_set_default_colors(state, &vtFGColor, &vtBGColor);
}

- (void)setPaletteColor:(NSColor*)color forIndex:(int)index {
	VTermState *state = vterm_obtain_state(mVTerm);
	VTermColor vtColor = [self vtColorFromColor:color];
	vterm_state_set_palette_color(state, index, &vtColor);
}

- (void)setPaletteColors:(NSArray*)colors {
	if ([colors count] != 16) {
		[NSException raise:NSInvalidArgumentException format:@"Palette size must be 16."];
	}

	VTermState *state = vterm_obtain_state(mVTerm);
	for (int i = 0; i < 16; i++) {
		VTermColor vtColor = [self vtColorFromColor:colors[i]];
		vterm_state_set_palette_color(state, i, &vtColor);
	}
}

- (void)updateSize {
	CGSize viewSize = self.bounds.size;
	_currentWidth = viewSize.width / CELL_WIDTH;
	_currentHeight = viewSize.height / CELL_HEIGHT;
}

- (void)setFrameSize:(NSSize)newSize {
	[super setFrameSize:newSize];
	if (![self inLiveResize]) {
		[self resizeTerminal];
	}
}

- (void)viewDidEndLiveResize {
	[super viewDidEndLiveResize];
	[self resizeTerminal];
}

- (void)resizeTerminal {
	[self updateSize];
	vterm_set_size(mVTerm, _currentHeight, _currentWidth);
	vterm_screen_flush_damage(mVTermScreen);
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

- (BOOL)acceptsFirstResponder {
	return true;
}

- (void)keyDown:(NSEvent *)event {
	// Don't send cmd keystrokes.
	if ([event modifierFlags] & NSCommandKeyMask) {
		[super keyDown:event];
		return;
	}

	VTermModifier mod = [TKKeyMap convertModifierToVTerm:[event modifierFlags]];
	VTermKey key = [TKKeyMap convertCharactersToVTerm:[event characters]];

	if (key != VTERM_KEY_NONE) {
		vterm_keyboard_key(mVTerm, key, mod);
		[self flushBuffer];
		return;
	}
	NSString *toSend;
	if (mod & VTERM_MOD_CTRL)
		toSend = [event charactersIgnoringModifiers];
	else {
		toSend = [event characters];
		mod = VTERM_MOD_NONE;
	}

	[self sendString:toSend modifier:mod];
}

- (void)paste:(id)sender {
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	NSString *paste = [pb stringForType:NSPasteboardTypeString];
	[self sendString:paste modifier:VTERM_MOD_NONE];
}

- (void)sendString:(NSString*)str modifier:(VTermModifier)mod {
	for (int i = 0; i < [str length]; i++) {
		if (vterm_output_get_buffer_remaining(mVTerm) < 6)
			[self flushBuffer];
		vterm_keyboard_unichar(mVTerm, [str characterAtIndex:i], mod);
	}
	[self flushBuffer];
}

- (void)flushBuffer {
	size_t bufflen = vterm_output_get_buffer_current(mVTerm);
	if (bufflen > 0) {
		char buffer[bufflen];
		bufflen = vterm_output_read(mVTerm, buffer, bufflen);
		size_t written = 0;
		while (written < bufflen) {
			written += write([mFileHandle fileDescriptor], buffer + written, bufflen - written);
		}
	}
}

- (void)drawRect:(NSRect)dirtyRect {
	// TODO: Revisit this.
	[[NSColor grayColor] set];
	NSRectFill(dirtyRect);

	VTermRect vtRect = [self vtRectFromRect:dirtyRect];
	for (unsigned int j = vtRect.start_row; j <= vtRect.end_row; j++) {
		for (unsigned int i = vtRect.start_col; i <= vtRect.end_col; i++) {
			VTermPos pos = {j, i};
			VTermScreenCell cell;
			vterm_screen_get_cell(mVTermScreen, pos, &cell);
			NSUInteger width = [self drawCell:&cell atPosition:pos];
			i += width - 1;
		}
	}
}

- (NSUInteger)drawCell:(VTermScreenCell*)cell atPosition:(VTermPos)pos {
	CGRect cellPosition = [self rectFromPosition:pos width:cell->width];
	
	bool invert = cell->attrs.reverse;

	NSColor *fgColor = [self colorFromVTColor:cell->fg];
	NSColor *bgColor = [self colorFromVTColor:cell->bg];
	if (invert) {
		NSColor *tmp = fgColor;
		fgColor = bgColor;
		bgColor = tmp;
	}
	[bgColor set];
	NSRectFill(cellPosition);

	// Find NULL-termination.
	NSUInteger length;
	for (length = 0; cell->chars[length]; length++);
	if (length) {
		NSData *data = [NSData dataWithBytes:cell->chars length:length * sizeof(cell->chars[0])];
		NSString *character = [[NSString alloc] initWithData:data encoding:NSUTF32LittleEndianStringEncoding];

		NSFont *font;
		if (cell->attrs.bold)
			font = [mFontManager boldFont];
		else
			font = [mFontManager regularFont];

		NSDictionary *attributes = @{
			NSFontAttributeName: font,
			NSForegroundColorAttributeName: fgColor,
		};
		NSAttributedString *formattedChar = [[NSAttributedString alloc] initWithString:character attributes:attributes];

		[formattedChar drawAtPoint:cellPosition.origin];
	}
	return cell->width;
}

- (CGRect)rectFromPosition:(VTermPos)pos width:(NSUInteger)width {
	CGRect rect;
	rect.origin.x = [self bounds].origin.x + (pos.col * CELL_WIDTH);
	rect.origin.y = [self bounds].origin.y + [self bounds].size.height - ((pos.row + 1) * CELL_HEIGHT);
	rect.size.width = width * CELL_WIDTH;
	rect.size.height = CELL_HEIGHT;
	return rect;
}

- (CGRect)rectFromVTRect:(VTermRect)vtRect {
	CGRect cgRect;
	cgRect.origin.x = [self bounds].origin.x + (vtRect.start_col * CELL_WIDTH);
	cgRect.origin.y = [self bounds].origin.y + [self bounds].size.height - ((vtRect.end_row + 1) * CELL_HEIGHT);
	cgRect.size.width = (vtRect.end_col - vtRect.start_col + 1) * CELL_WIDTH;
	cgRect.size.height = (vtRect.end_row - vtRect.start_row + 1) * CELL_HEIGHT;
	return cgRect;
}

- (VTermRect)vtRectFromRect:(CGRect)rect {
	VTermRect vtRect;
	vtRect.start_col = (rect.origin.x - [self bounds].origin.x) / CELL_WIDTH;
	vtRect.end_col = (rect.size.width / CELL_WIDTH) + vtRect.start_col - 1;
	vtRect.end_row = ([self bounds].origin.y + [self bounds].size.height - rect.origin.y) / CELL_HEIGHT - 1;
	vtRect.start_row = (vtRect.end_row + 1) - (rect.size.height / CELL_HEIGHT);
	return vtRect;
}

- (NSColor*)colorFromVTColor:(VTermColor)vtColor {
	CGFloat red = vtColor.red;
	CGFloat green = vtColor.green;
	CGFloat blue = vtColor.blue;
	return [NSColor colorWithRed:(red / 255) green:(green / 255) blue:(blue / 255) alpha:1];
}

- (VTermColor)vtColorFromColor:(NSColor*)color {
	VTermColor vtColor;
	vtColor.red = [color redComponent] * 255;
	vtColor.green = [color greenComponent] * 255;
	vtColor.blue = [color blueComponent] * 255;
	return vtColor;
}

@end
