// The keys that sort the names of the library.

#import <Foundation/Foundation.h>

// A key for `text` that compares with a plain compare. It is lowercase and
// has no accents. With `ignoreArticles`, a leading "The " or "A " goes away,
// so that "The Beatles" sorts as "beatles".
NSString *GLSortKey(NSString *text, BOOL ignoreArticles);

// The letter of the index of the list for a key: A to Z, or "#".
NSString *GLIndexLetter(NSString *sortKey);
