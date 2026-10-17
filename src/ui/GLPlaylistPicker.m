#import "GLPlaylistPicker.h"
#import "GLLibrary.h"

// The delegate keeps itself until the alert or the sheet closes.
@interface GLPickerDelegate : NSObject <UIAlertViewDelegate, UIActionSheetDelegate>
@property (nonatomic, copy) void (^onName)(NSString *name);
@property (nonatomic, copy) void (^onIndex)(NSInteger index);
@property (nonatomic, strong) GLPickerDelegate *keep;
@end

@implementation GLPickerDelegate

- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)index {
    NSString *name = [[alert textFieldAtIndex:0].text
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (index != alert.cancelButtonIndex && name.length && self.onName) self.onName(name);
    self.keep = nil;
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    if (index != sheet.cancelButtonIndex && index >= 0 && self.onIndex) self.onIndex(index);
    self.keep = nil;
}

@end

@implementation GLPlaylistPicker

+ (void)askForNameWithTitle:(NSString *)title name:(NSString *)name completion:(void (^)(NSString *name))completion {
    GLPickerDelegate *delegate = [GLPickerDelegate new];
    delegate.keep = delegate;
    delegate.onName = completion;
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:nil delegate:delegate cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"Save", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    UITextField *field = [alert textFieldAtIndex:0];
    field.placeholder = @"Name";
    field.text = name;
    field.autocapitalizationType = UITextAutocapitalizationTypeWords;
    [alert show];
}

+ (void)addTracks:(NSArray *)tracks fromView:(UIView *)view {
    NSArray *playlists = [[[GLLibrary shared] playlists]
        filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"kind == %d", GLPlaylistUser]];
    GLPickerDelegate *delegate = [GLPickerDelegate new];
    delegate.keep = delegate;
    delegate.onIndex = ^(NSInteger index) {
        if (index == 0) {
            [self askForNameWithTitle:@"New Playlist" name:nil completion:^(NSString *name) {
                GLPlaylist *playlist = [[GLLibrary shared] createPlaylistNamed:name];
                [[GLLibrary shared] addTracks:tracks toPlaylist:playlist];
            }];
        } else if ((NSUInteger)index - 1 < playlists.count) {
            [[GLLibrary shared] addTracks:tracks toPlaylist:playlists[index - 1]];
        }
    };
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Add to Playlist" delegate:delegate cancelButtonTitle:nil
                                         destructiveButtonTitle:nil otherButtonTitles:@"New Playlist", nil];
    for (GLPlaylist *playlist in playlists) [sheet addButtonWithTitle:playlist.name];
    sheet.cancelButtonIndex = [sheet addButtonWithTitle:@"Cancel"];
    [sheet showInView:view];
}

@end
