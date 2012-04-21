//
//  BookmarksManager.h
//  DocSets
//
//  Created by Ole Zorn on 19.04.12.
//  Copyright (c) 2012 omz:software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BookmarksDocument.h"

#define BookmarksDidUpdateNotification		@"BookmarksDidUpdateNotification"

@class BookmarksDocument, DocSet;

@interface BookmarksManager : NSObject <BookmarksDocumentDelegate> {
	
	BookmarksDocument *_document;
	NSMetadataQuery *_query;
	
	BOOL _bookmarksAvailable;
	BOOL _bookmarksEditable;
	
	BOOL isResolvingConflict;
}

@property (nonatomic, strong) BookmarksDocument *document;
@property (nonatomic, strong) NSMetadataQuery *query;

@property (nonatomic, assign) BOOL bookmarksAvailable;
@property (nonatomic, assign) BOOL bookmarksEditable;

+ (id)sharedBookmarksManager;

- (NSMutableArray *)bookmarksForDocSet:(DocSet *)docSet;
- (BOOL)addBookmarkWithURL:(NSString *)bookmarkURL title:(NSString *)bookmarkTitle subtitle:(NSString *)subtitle forDocSet:(DocSet *)docSet;
- (BOOL)deleteBookmarkAtIndex:(NSInteger)bookmarkIndex fromDocSet:(DocSet *)docSet;
- (BOOL)moveBookmarkAtIndex:(NSInteger)fromIndex inDocSet:(DocSet *)docSet toIndex:(NSInteger)toIndex;
- (NSURL *)URLForBookmark:(NSDictionary *)bookmark inDocSet:(DocSet *)docSet;
- (NSURL *)webURLForBookmark:(NSDictionary *)bookmark inDocSet:(DocSet *)docSet;

@end
