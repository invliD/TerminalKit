#import <Cocoa/Cocoa.h>

#import "vterm.h"

@interface TKKeyMap : NSObject

+ (VTermModifier)convertModifierToVTerm:(NSEventModifierFlags)mod;
+ (VTermKey)convertCharactersToVTerm:(NSString*)characters;

@end
