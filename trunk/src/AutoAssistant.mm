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

- (void)showAssistantWindow;
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

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(showAssistantWindow) object:nil];

	BOOL didInsert = NO, showAssistant = NO;
	NSTimeInterval delay = 0;
	
	if ([[event characters] isEqualToString:@";"])
	{
		NSString* language = [[self textStorage] language];
		if([SupportedLanguages containsObject:language])
			didInsert = [[AutoAssistant sharedInstance] insertSemicolonForTextView:self];
	}
	else if ([[event characters] isEqualToString:@"."]) {

		if ([[AutoAssistant sharedInstance] shouldShowCompletionListForTextView:self withDelay:&delay]) {
			showAssistant = (delay != 0.4);
			delay = 0;
		}
	}
	else if ([[event characters] length] == 1 &&
			 ([[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:[[event characters] characterAtIndex:0]] ||
			  [[NSCharacterSet lowercaseLetterCharacterSet] characterIsMember:[[event characters] characterAtIndex:0]])) {

		NSWindow *assistant = FindAssistantWindow();
	
		if (assistant && ![assistant isVisible] && [[AutoAssistant sharedInstance] shouldShowCompletionListForTextView:self withDelay:&delay])
			showAssistant = YES;
	}

	if(!didInsert)
		[self AutoAssistant_keyDown:event];
	
	if (showAssistant) {
		if (delay == 0)
			[self showAssistantWindow];
		else
			[self performSelector:@selector(showAssistantWindow) withObject:nil afterDelay:delay];
	}
}
- (void)showAssistantWindow {
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

- (BOOL) shouldShowCompletionListForTextView:(NSTextView *)textView withDelay:(NSTimeInterval *)delay {
	
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
	
	NSString *prefix = [lineText substringToIndex:selectedRange.location - lineRange.location];
	
	if ([prefix rangeOfString:@"//"].location != NSNotFound ||
		([prefix rangeOfString:@"/*"].location != NSNotFound && [prefix rangeOfString:@"*/"].location == NSNotFound))
		return NO; // you're writing a comment! maybe. this isn't a lexer.

	prefix = [prefix stringByReplacingOccurrencesOfString:@"\\\"" withString:@""];
	int numberOfQuotes = [[prefix componentsSeparatedByString:@"\""] count];
	if (numberOfQuotes % 2 == 0)
		return NO; // you're writing a string! maybe. see above.

	NSUInteger wordLength = 1; // include the character you're typing
	
	for (int i=[prefix length]-1; i>=0; i--) {
		unichar c = [prefix characterAtIndex:i];
		if ([[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:c] ||
			[[NSCharacterSet lowercaseLetterCharacterSet] characterIsMember:c])
			wordLength++;
		else break;
	}

	if (wordLength == 1)
		(*delay) = 0.4;
	else if (wordLength == 2)
		(*delay) = 0.2;
	else if (wordLength == 3)
		(*delay) = 0.1;
	else
		(*delay) = 0;
	
	return YES;
}

@end
