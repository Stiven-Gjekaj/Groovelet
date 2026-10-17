#import "GLTheme.h"

static UIColor *GLColor(unsigned rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 0xff) / 255.0 green:((rgb >> 8) & 0xff) / 255.0
                            blue:(rgb & 0xff) / 255.0 alpha:1];
}

UIColor *GLBackgroundColor(void) {
    return GLColor(0x111111);
}

UIColor *GLSurfaceColor(void) {
    return GLColor(0x1c1c1c);
}

UIColor *GLSeparatorColor(void) {
    return GLColor(0x262626);
}

UIColor *GLTextColor(void) {
    return GLColor(0xf5f1ec);
}

UIColor *GLSecondaryTextColor(void) {
    return GLColor(0x8e8a86);
}

UIColor *GLAccentColor(void) {
    return GLColor(0xff6b4a);
}

UIFont *GLFont(CGFloat size) {
    return [UIFont fontWithName:@"Inter-Regular" size:size] ?: [UIFont systemFontOfSize:size];
}

UIFont *GLBoldFont(CGFloat size) {
    return [UIFont fontWithName:@"Inter-SemiBold" size:size] ?: [UIFont boldSystemFontOfSize:size];
}

void GLApplyTheme(void) {
    UIColor *bar = GLColor(0x161616);
    [[UINavigationBar appearance] setTintColor:bar];
    [[UINavigationBar appearance] setTitleTextAttributes:@{
        UITextAttributeFont: GLBoldFont(18), UITextAttributeTextColor: GLTextColor(),
        UITextAttributeTextShadowColor: [UIColor clearColor],
    }];
    [[UIBarButtonItem appearance] setTitleTextAttributes:@{ UITextAttributeFont: GLBoldFont(12) }
                                                forState:UIControlStateNormal];
    [[UISearchBar appearance] setTintColor:bar];
    [[UIToolbar appearance] setTintColor:bar];
    [[UITabBar appearance] setTintColor:bar];
    [[UITabBar appearance] setSelectedImageTintColor:GLAccentColor()];
    [[UITabBarItem appearance] setTitleTextAttributes:@{ UITextAttributeFont: GLFont(10) }
                                             forState:UIControlStateNormal];
    [[UISegmentedControl appearance] setTintColor:GLColor(0x333333)];
    [[UISwitch appearance] setOnTintColor:GLAccentColor()];
    [[UISlider appearance] setMinimumTrackTintColor:GLAccentColor()];
    [[UIRefreshControl appearance] setTintColor:GLTextColor()];
}

void GLStyleTable(UITableView *table) {
    table.backgroundColor = GLBackgroundColor();
    table.backgroundView = nil;
    table.separatorColor = GLSeparatorColor();
    table.sectionIndexColor = GLSecondaryTextColor();
    table.sectionIndexTrackingBackgroundColor = [UIColor colorWithWhite:1 alpha:0.06];
    table.indicatorStyle = UIScrollViewIndicatorStyleWhite;
}
