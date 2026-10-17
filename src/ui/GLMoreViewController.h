// The More tab: Folders, Upload, and Settings.

#import <UIKit/UIKit.h>

@interface GLMoreViewController : UITableViewController
// Opens the screen with this name: "folders", "upload", or "settings".
- (void)openScreen:(NSString *)name;
@end
