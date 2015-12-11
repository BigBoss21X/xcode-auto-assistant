This is an xcode plug-in which makes writing code easier.

![http://ctu.appspot.com/gdxI1/o27/screenshot.png](http://ctu.appspot.com/gdxI1/o27/screenshot.png)

[Read the related blog post](http://nfarina.com/post/428544140/there-i-fixed-xcode-youre-welcome)

When editing an Objective-C file, the completion popup list will be triggered automatically as you type alphanumeric characters.

The list appears with a delay that is proportional to the number of characters in the word typed thus far. For instance, if you type only one letter, the delay is substantial (because we expect the completion list will be quite long), but by the time you type the 4th character, it appears instantly and predictably.

As an added feature, you can type a `;` to add a semicolon to the current line. The plug-in will automatically look forwards to insert the semicolon at the appropriate location.

This code was forked from the **excellent** xcode-bracket-matcher (http://github.com/ciaran/xcode-bracket-matcher) by ciaran, without which I could not have done this.