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

@interface BookmarksManager2 : NSObject {

	BOOL _movingToUbiquityContainer;
}

@property (nonatomic, strong) NSMetadataQuery *query;
@property (nonatomic, strong) NSMutableDictionary *bookmarks;
@property (nonatomic, strong) NSDate *bookmarksModificationDate;

+ (id)sharedBookmarksManager;
- (void)postChangeNotification;
- (void)resolveConflictAtURL:(NSURL *)fileURL;

- (NSMutableArray *)bookmarksForDocSet:(DocSet *)docSet;
- (BOOL)addBookmarkWithURL:(NSString *)bookmarkURL title:(NSString *)bookmarkTitle subtitle:(NSString *)subtitle forDocSet:(DocSet *)docSet;
- (NSString *)relativeBookmarkPathWithBookmarkURL:(NSString *)bookmarkURL inDocSetWithPath:(NSString *)docSetPath;
- (NSURL *)URLForBookmark:(NSDictionary *)bookmark inDocSet:(DocSet *)docSet;
- (NSURL *)webURLForBookmark:(NSDictionary *)bookmark inDocSet:(DocSet *)docSet;
- (BOOL)deleteBookmarkAtIndex:(NSInteger)bookmarkIndex fromDocSet:(DocSet *)docSet;
- (BOOL)moveBookmarkAtIndex:(NSInteger)fromIndex inDocSet:(DocSet *)docSet toIndex:(NSInteger)toIndex;

@end
