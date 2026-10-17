// The colors and the font of the app: a near-black background, off-white
// text, and the coral of the logo as the accent. The bars stay the stock
// iOS 6 bars with a dark tint. See docs/decisions.md.

#import <UIKit/UIKit.h>

UIColor *GLBackgroundColor(void);     // #111111, behind the content
UIColor *GLSurfaceColor(void);        // A dark grey, for headers and cards
UIColor *GLSeparatorColor(void);
UIColor *GLTextColor(void);           // Off-white
UIColor *GLSecondaryTextColor(void);
UIColor *GLAccentColor(void);         // Coral #FF6B4A

// Inter, bundled with the app. The system font when Inter is missing.
UIFont *GLFont(CGFloat size);
UIFont *GLBoldFont(CGFloat size);

// Sets the tint of the bars of the app. Call it before the first window shows.
void GLApplyTheme(void);

// Makes a table dark, with the separators and the index of the theme.
void GLStyleTable(UITableView *table);
