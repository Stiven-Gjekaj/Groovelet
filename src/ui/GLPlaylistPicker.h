// Asks for the name of a playlist, and lets the owner pick a playlist of the
// app for "Add to Playlist".

#import <UIKit/UIKit.h>

@interface GLPlaylistPicker : NSObject

// Shows an alert with a text field. `completion` gets a name that is not
// empty. It does not run when the owner cancels.
+ (void)askForNameWithTitle:(NSString *)title name:(NSString *)name completion:(void (^)(NSString *name))completion;

// Shows the playlists of the app and "New Playlist", and adds the tracks to
// the one that the owner picks.
+ (void)addTracks:(NSArray *)tracks fromView:(UIView *)view;

@end
