#import "TKTerminalViewPrivate.h"
#import "TKTerminalScreen.h"
#import "TKKeyMap.h"

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
	NSRectFill([self bounds]);

	for (unsigned int j = 0; j < _currentHeight; j++) {
		for (unsigned int i = 0; i < _currentWidth; i++) {
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

	NSColor *fgColor = [self colorFromVTColor:cell->fg];
	NSColor *bgColor = [self colorFromVTColor:cell->bg];
	[bgColor set];
	NSRectFill(cellPosition);

	// Find NULL-termination.
	NSUInteger length;
	for (length = 0; cell->chars[length]; length++);
	if (length) {
		NSData *data = [NSData dataWithBytes:cell->chars length:length * sizeof(cell->chars[0])];
		NSString *character = [[NSString alloc] initWithData:data encoding:NSUTF32LittleEndianStringEncoding];

		// TODO: Move font and font size to config.
		CGFloat fontSize = 14;
		NSString *fontName;
		if (cell->attrs.bold)
			fontName = @"Menlo-Bold";
		else
			fontName = @"Menlo";
		NSFont *font = [NSFont fontWithName:fontName size:fontSize];

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

- (NSColor*)colorFromVTColor:(VTermColor)vtColor {
	CGFloat red = vtColor.red;
	CGFloat green = vtColor.green;
	CGFloat blue = vtColor.blue;
	return [NSColor colorWithRed:(red / 255) green:(green / 255) blue:(blue / 255) alpha:1];
}

@end
