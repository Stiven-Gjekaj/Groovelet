#import "GLMoreViewController.h"
#import "GLFoldersViewController.h"
#import "GLSettings.h"
#import "GLSettingsViewController.h"
#import "GLTheme.h"

@interface GLMoreViewController ()
@property (nonatomic, strong) NSArray *rows;
@end

@implementation GLMoreViewController

- (instancetype)init {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        self.title = @"More";
        self.tabBarItem.image = [UIImage imageNamed:@"Tab-more.png"];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    GLStyleTable(self.tableView);
    self.tableView.rowHeight = 52;
    self.tableView.tableFooterView = [UIView new];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload)
                                                 name:GLSettingsDidChangeNotification object:nil];
    [self reload];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)reload {
    NSMutableArray *rows = [NSMutableArray array];
    if ([GLSettings shared].showFolders) [rows addObject:@"folders"];
    [rows addObject:@"settings"];
    self.rows = rows;
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"row"];
        cell.backgroundColor = GLBackgroundColor();
        cell.textLabel.font = GLFont(17);
        cell.textLabel.textColor = GLTextColor();
        cell.textLabel.backgroundColor = [UIColor clearColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    NSDictionary *titles = @{ @"folders": @"Folders", @"settings": @"Settings" };
    cell.textLabel.text = titles[self.rows[indexPath.row]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self openScreen:self.rows[indexPath.row]];
}

- (void)openScreen:(NSString *)name {
    UIViewController *screen = nil;
    if ([name isEqualToString:@"folders"]) screen = [[GLFoldersViewController alloc] initWithFolder:@""];
    if ([name isEqualToString:@"settings"]) screen = [GLSettingsViewController new];
    if (screen) [self.navigationController pushViewController:screen animated:YES];
}

@end
