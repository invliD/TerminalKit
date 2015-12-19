#import "TKKeyMap.h"

@implementation TKKeyMap

+ (VTermModifier)convertModifierToVTerm:(NSEventModifierFlags)mod {
	VTermModifier vMod = VTERM_MOD_NONE;
	if (mod & NSShiftKeyMask)
		vMod |= VTERM_MOD_SHIFT;
	if (mod & NSControlKeyMask)
		vMod |= VTERM_MOD_CTRL;
	if (mod & NSAlternateKeyMask)
		vMod |= VTERM_MOD_ALT;
	return vMod;
}

+ (VTermKey)convertCharactersToVTerm:(NSString*)characters {
	if ([characters length] == 0)
		return VTERM_KEY_NONE;
	unichar code = [characters characterAtIndex:0];

	//NSLog(@"Keycode: %2x", code);

	if(code >= NSF1FunctionKey && code <= NSF35FunctionKey)
		return VTERM_KEY_FUNCTION(code - NSF1FunctionKey + 1);

	switch(code) {
		case NSTabCharacter: return VTERM_KEY_TAB;
		//case NSNewlineCharacter: return VTERM_KEY_ENTER;
		case NSCarriageReturnCharacter: return VTERM_KEY_ENTER;
		case NSBackspaceCharacter: return VTERM_KEY_BACKSPACE;
		case 0x1b: return VTERM_KEY_ESCAPE;
		case NSDeleteCharacter: return VTERM_KEY_BACKSPACE;

		case NSUpArrowFunctionKey: return VTERM_KEY_UP;
		case NSDownArrowFunctionKey: return VTERM_KEY_DOWN;
		case NSLeftArrowFunctionKey: return VTERM_KEY_LEFT;
		case NSRightArrowFunctionKey: return VTERM_KEY_RIGHT;

		case NSInsertFunctionKey: return VTERM_KEY_INS;
		case NSDeleteFunctionKey: return VTERM_KEY_DEL;
		case NSHomeFunctionKey: return VTERM_KEY_HOME;
		case NSEndFunctionKey: return VTERM_KEY_END;
		case NSPageUpFunctionKey: return VTERM_KEY_PAGEUP;
		case NSPageDownFunctionKey: return VTERM_KEY_PAGEDOWN;
		default: return VTERM_KEY_NONE;
	}
}

@end
