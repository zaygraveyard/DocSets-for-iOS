//
//  BookmarksManager2.h
//  DocSets
//
//  Created by Ole Zorn on 22.05.12.
//  Copyright (c) 2012 omz:software. All rights reserved.
//

#import <UIKit/UIKit.h>

#define BookmarksManagerDidLoadBookmarksNotification	@"BookmarksManagerDidLoadBookmarksNotification"

@class DocSet;

@interface BookmarksManager : NSObject

@property (strong) NSMutableDictionary *bookmarks;

+ (id)sharedBookmarksManager;

- (NSMutableArray *)bookmarksForDocSet:(DocSet *)docSet;
- (NSURL *)URLForBookmark:(NSDictionary *)bookmark inDocSet:(DocSet *)docSet;
- (NSURL *)webURLForBookmark:(NSDictionary *)bookmark inDocSet:(DocSet *)docSet;
- (BOOL)addBookmarkWithURL:(NSString *)bookmarkURL title:(NSString *)bookmarkTitle subtitle:(NSString *)subtitle forDocSet:(DocSet *)docSet;
- (BOOL)deleteBookmarkAtIndex:(NSInteger)bookmarkIndex fromDocSet:(DocSet *)docSet;
- (BOOL)moveBookmarkAtIndex:(NSInteger)fromIndex inDocSet:(DocSet *)docSet toIndex:(NSInteger)toIndex;

@end
