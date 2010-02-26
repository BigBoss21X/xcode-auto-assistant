//  Created by Ciarán Walsh on 02/04/2009.
//  Modified by Nick Farina on a sunny day

#import "AutoAssistant.h"
#import "JRSwizzle.h"

static AutoAssistant* SharedInstance;

@interface NSObject (DevToolsInterfaceAdditions)
// XCTextStorageAdditions
- (id)language;

// XCSourceCodeTextView
- (BOOL)isInlineCompleting;
- (id)codeAssistant;

// PBXCodeAssistant
- (void)liveInlineRemoveCompletion;
@end

static NSArray* SupportedLanguages;

NSWindow *FindAssistantWindow() {
	
	Class assistantClass = NSClassFromString(@"PBXCodeAssistantWindow");
	
	if (assistantClass)
		for (NSWindow *window in [[NSApplication sharedApplication] windows])
			if ([window isKindOfClass:assistantClass])
				return window;
	
	return nil;
}

@implementation NSTextView (AutoAssistant)
- (void)AutoAssistant_keyDown:(NSEvent*)event {
	
	BOOL didInsert = NO;
	if ([[event characters] isEqualToString:@";"])
	{
		NSString* language = [[self textStorage] language];
		if([SupportedLanguages containsObject:language])
			didInsert = [[AutoAssistant sharedInstance] insertSemicolonForTextView:self];
	}
	else if ([[event characters] isEqualToString:@"."]) {
		[self performSelector:@selector(pressEscSometimeLater) withObject:nil afterDelay:0];
	}
	else if ([[event characters] length] == 1 && 
			 ([[NSCharacterSet lowercaseLetterCharacterSet] characterIsMember:[[event characters] characterAtIndex:0]] ||
			  [[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:[[event characters] characterAtIndex:0]])) {
		
		NSWindow *assistant = FindAssistantWindow();
		if (assistant && ![assistant isVisible])
			[self performSelector:@selector(pressEscSometimeLater) withObject:nil afterDelay:0];
	}

	if(!didInsert)
		[self AutoAssistant_keyDown:event];
}
- (void)pressEscSometimeLater {
	CGEventRef keyPressEvent=CGEventCreateKeyboardEvent (NULL, (CGKeyCode)53, true);
	CGEventPost(kCGSessionEventTap, keyPressEvent);
	CFRelease(keyPressEvent);
}
@end

@implementation AutoAssistant

+ (void)load {
	if(![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.Xcode"])
		return;

	if([NSClassFromString(@"XCSourceCodeTextView") jr_swizzleMethod:@selector(keyDown:) withMethod:@selector(AutoAssistant_keyDown:) error:NULL])
		NSLog(@"AutoAssistant loaded");

	SupportedLanguages = [[NSArray alloc] initWithObjects:@"xcode.lang.objcpp", @"xcode.lang.objc", @"xcode.lang.objj", nil];
}

+ (AutoAssistant*)sharedInstance {
	return SharedInstance ?: [[self new] autorelease];
}

- (BOOL)insertSemicolonForTextView:(NSTextView*)textView
{
	static NSCharacterSet *controlSet = nil;
	
	if (!controlSet)
		controlSet = [[NSCharacterSet characterSetWithCharactersInString:@"'\""] retain];

	if(![[textView selectedRanges] count])
		return NO;
	
	// Get the position of the carat
	NSRange selectedRange = [[[textView selectedRanges] lastObject] rangeValue];
	if(selectedRange.length > 0)
		return NO;
	
	// Get the current line from the carat position
	NSRange lineRange = [textView.textStorage.string lineRangeForRange:selectedRange];
	lineRange.length -= 1;
	NSString* lineText = [textView.textStorage.string substringWithRange:lineRange];

	if (lineRange.location + lineRange.length == selectedRange.location)
		return NO; // we're already at the end of a line, let XCode do it
		
	// build up the result string
	NSMutableString *result = [NSMutableString string];

	// Poor man's trimEnd
	NSString *trimmed = [lineText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	
	NSScanner *scanner = [NSScanner scannerWithString:lineText];
	[scanner setCharactersToBeSkipped:nil];
	NSString *whitespaceBeginning = nil;
	[scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&whitespaceBeginning];

	if (whitespaceBeginning)
		[result appendString:whitespaceBeginning];
	
	[result appendString:trimmed];
	
	if ([result rangeOfString:@";"].location == [result length] - 1)
		return NO; // already a semicolon at the end
	
	[result appendString:@";"];

	[textView.undoManager beginUndoGrouping];
	[[textView.undoManager prepareWithInvocationTarget:textView] replaceCharactersInRange:NSMakeRange(lineRange.location, [result length]) withString:lineText];
	[textView.undoManager endUndoGrouping];
	
	[textView replaceCharactersInRange:lineRange withString:result];
	
	return YES;
}

@end
