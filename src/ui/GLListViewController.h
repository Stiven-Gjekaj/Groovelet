// The base of the lists of the library: a dark table with a search box at
// the top and an index of the letters at the right. A subclass gives the
// items and says how each item shows.
//
// The items load away from the main thread. The list loads them again when
// the library changes.

#import <UIKit/UIKit.h>
#import "GLTrackCell.h"

@interface GLListViewController : UITableViewController <UISearchBarDelegate>

// The items that show now, after the search.
@property (nonatomic, readonly) NSArray *visibleItems;

// Loads the items again.
- (void)reload;

#pragma mark For a subclass

// Called away from the main thread. Returns all items, sorted.
- (NSArray *)loadItems;
// The sort key of an item, for the index. nil makes a list with no index.
- (NSString *)sortKeyForItem:(id)item;
// The text that the search looks in.
- (NSString *)searchTextForItem:(id)item;
- (void)configureCell:(GLTrackCell *)cell forItem:(id)item;
- (void)didSelectItem:(id)item;
// The text when the list is empty.
- (NSString *)emptyText;
// YES for a list that loads again when the track that plays changes.
- (BOOL)showsCurrentTrack;

@end
