#import "GLTextViewController.h"
#import "GLTheme.h"

@interface GLTextViewController ()
@property (nonatomic, copy) NSString *text;
@end

@implementation GLTextViewController

- (instancetype)initWithTitle:(NSString *)title text:(NSString *)text {
    if ((self = [super init])) {
        self.title = title;
        _text = [text copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UITextView *view = [[UITextView alloc] initWithFrame:self.view.bounds];
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    view.editable = NO;
    view.backgroundColor = GLBackgroundColor();
    view.textColor = GLTextColor();
    view.font = GLFont(12);
    view.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    view.text = self.text;
    [self.view addSubview:view];
}

@end
