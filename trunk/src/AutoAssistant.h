//  Created by Ciarán Walsh on 02/04/2009.
//  Modified by Nick Farina on a sunny day

#import <Cocoa/Cocoa.h>

@interface AutoAssistant : NSObject
{

}
+ (AutoAssistant*)sharedInstance;
- (BOOL)insertSemicolonForTextView:(NSTextView*)textView;
- (BOOL)shouldShowCompletionListForTextView:(NSTextView*)textView;
@end
