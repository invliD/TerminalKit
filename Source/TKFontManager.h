#import <Cocoa/Cocoa.h>

@interface TKFontManager : NSObject

@property (readonly,nonatomic,strong) NSFont *regularFont;
@property (readonly,nonatomic,strong) NSFont *boldFont;

+ (instancetype)managerWithFontName:(NSString*)fontName size:(CGFloat)fontSize;
- (instancetype)initWithFontName:(NSString*)fontName size:(CGFloat)fontSize;

@end
