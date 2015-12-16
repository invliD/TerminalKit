#import "TKFontManager.h"

@implementation TKFontManager

+ (instancetype)managerWithFontName:(NSString*)fontName size:(CGFloat)fontSize {
	return [[self alloc] initWithFontName:fontName size:fontSize];
}

- (instancetype)initWithFontName:(NSString*)fontName size:(CGFloat)fontSize {
	NSFontManager *fontManager = [NSFontManager sharedFontManager];
	_regularFont = [fontManager fontWithFamily:fontName traits:0 weight:5 size:fontSize];
	_boldFont = [fontManager fontWithFamily:fontName traits:NSBoldFontMask weight:9 size:fontSize];
	return self;
}

@end
