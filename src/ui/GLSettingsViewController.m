#import "GLSettingsViewController.h"
#import "GLArtCache.h"
#import "GLFormat.h"
#import "GLImageLoader.h"
#import "GLLibrary.h"
#import "GLLibraryUpdater.h"
#import "GLSettings.h"
#import "GLTextViewController.h"
#import "GLTheme.h"

typedef NS_ENUM(NSInteger, GLSettingsSection) {
    GLSectionLibrary,
    GLSectionAbout,
    GLSectionCount,
};

@implementation GLSettingsViewController

- (instancetype)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) self.title = @"Settings";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    GLStyleTable(self.tableView);
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self.tableView selector:@selector(reloadData) name:GLScanDidStartNotification object:nil];
    [center addObserver:self.tableView selector:@selector(reloadData) name:GLScanDidEndNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.tableView];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return GLSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == GLSectionLibrary ? 3 : 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == GLSectionLibrary ? @"Library" : @"About";
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 36)];
    label.backgroundColor = [UIColor clearColor];
    label.textColor = GLSecondaryTextColor();
    label.font = GLBoldFont(13);
    label.text = [@"     " stringByAppendingString:[self tableView:tableView titleForHeaderInSection:section].uppercaseString];
    return label;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 40;
}

- (UITableViewCell *)cellWithTitle:(NSString *)title detail:(NSString *)detail {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.backgroundColor = GLSurfaceColor();
    cell.textLabel.text = title;
    cell.textLabel.font = GLFont(16);
    cell.textLabel.textColor = GLTextColor();
    cell.textLabel.backgroundColor = [UIColor clearColor];
    cell.detailTextLabel.text = detail;
    cell.detailTextLabel.font = GLFont(14);
    cell.detailTextLabel.textColor = GLSecondaryTextColor();
    cell.detailTextLabel.backgroundColor = [UIColor clearColor];
    return cell;
}

- (UITableViewCell *)switchCellWithTitle:(NSString *)title on:(BOOL)on action:(SEL)action {
    UITableViewCell *cell = [self cellWithTitle:title detail:nil];
    UISwitch *control = [UISwitch new];
    control.on = on;
    [control addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = control;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    GLSettings *settings = [GLSettings shared];
    if (indexPath.section == GLSectionLibrary) {
        switch (indexPath.row) {
            case 0:
                return [self switchCellWithTitle:@"Sort \"The\" by the next word" on:settings.ignoreArticles
                                          action:@selector(toggleArticles:)];
            case 1:
                return [self switchCellWithTitle:@"Show Folders in More" on:settings.showFolders
                                          action:@selector(toggleFolders:)];
            default: {
                GLLibraryUpdater *updater = [GLLibraryUpdater shared];
                NSString *detail = updater.scanning ? @"Scanning..." : GLCountText((NSInteger)[[GLLibrary shared] trackCount],
                                                                                    @"song");
                UITableViewCell *cell = [self cellWithTitle:@"Scan the library again" detail:detail];
                cell.textLabel.textColor = GLAccentColor();
                return cell;
            }
        }
    }
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    switch (indexPath.row) {
        case 0: {
            UITableViewCell *cell = [self cellWithTitle:@"Version" detail:version];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            return cell;
        }
        case 1: {
            UITableViewCell *cell = [self cellWithTitle:@"Licences" detail:nil];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            return cell;
        }
        default:
            return [self cellWithTitle:@"Groovelet on GitHub" detail:nil];
    }
}

- (void)toggleArticles:(UISwitch *)control {
    [GLSettings shared].ignoreArticles = control.on;
}

- (void)toggleFolders:(UISwitch *)control {
    [GLSettings shared].showFolders = control.on;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == GLSectionLibrary && indexPath.row == 2) {
        // A rescan also makes the art again, for art that changed.
        [[GLArtCache shared] clear];
        [[GLImageLoader shared] clear];
        [[GLLibraryUpdater shared] scan];
    } else if (indexPath.section == GLSectionAbout && indexPath.row == 1) {
        [self.navigationController pushViewController:[[GLTextViewController alloc] initWithTitle:@"Licences"
                                                                                             text:[self licences]]
                                             animated:YES];
    } else if (indexPath.section == GLSectionAbout && indexPath.row == 2) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/Stiven-Gjekaj/Groovelet"]];
    }
}

- (NSString *)licences {
    NSMutableString *text = [NSMutableString string];
    [text appendString:@"Groovelet is free software under the MIT licence.\n\n"
                       @"It uses FFmpeg 7.1.1 under the LGPL 2.1. The app loads FFmpeg as the library "
                       @"libglffmpeg.dylib, which you can replace. The source of FFmpeg is at ffmpeg.org, and "
                       @"scripts/ffmpeg.sh in the repository of Groovelet builds it.\n\n"
                       @"It uses the Inter font under the SIL Open Font License 1.1.\n\n"];
    for (NSString *name in @[ @"Inter-OFL.txt", @"FFmpeg-LGPL-2.1.txt" ]) {
        NSString *path = [[NSBundle mainBundle] pathForResource:name.stringByDeletingPathExtension ofType:@"txt"];
        NSString *body = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
        if (body) [text appendFormat:@"=== %@ ===\n\n%@\n\n", name.stringByDeletingPathExtension, body];
    }
    return text;
}

@end
