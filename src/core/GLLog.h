// A small log file for the diagnostics. It keeps the newest lines in
// Library/Caches/Groovelet/log.txt.

#import <Foundation/Foundation.h>

void GLLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);

// The text of the log.
NSString *GLLogText(void);
