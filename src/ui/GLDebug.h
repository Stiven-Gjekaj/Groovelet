// Links for the checks on the phone. They exist only in a build with
// GL_DEBUG (scripts/install.sh --debug), because a link from another app
// must never delete music.
//   groovelet://debug?action=delete&path=PATH       deletes a track as the menu does
//   groovelet://debug?action=deletefolder&path=DIR  deletes a folder as the menu does
//   groovelet://debug?action=playlist&name=NAME&path=PATH  adds a track to a new playlist
//   groovelet://debug?action=scroll&t=SECONDS       scrolls the visible list and logs the frames
//   groovelet://debug?action=scanall                reads each file of the library again

#import <UIKit/UIKit.h>

// Returns YES when the link was a debug link.
BOOL GLHandleDebugLink(NSURL *url, UIViewController *root);
