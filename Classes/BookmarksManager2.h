//
//  BookmarksManager2.h
//  DocSets
//
//  Created by Ole Zorn on 22.05.12.
//  Copyright (c) 2012 omz:software. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum BookmarksState {
	BookmarksStateUnknown,
	
	BookmarksStateInitializing,
	
	BookmarksStateLoading,
	BookmarksStateLoaded,
	
	BookmarksStateSaving,
	
	BookmarksStateError
} BookmarksState;

@interface BookmarksManager2 : NSObject

@property (nonatomic, assign) BookmarksState state;
@property (nonatomic, strong) NSMetadataQuery *query;
@property (nonatomic, strong) NSMutableDictionary *bookmarks;
@property (nonatomic, strong) NSDate *bookmarksModificationDate;

+ (id)sharedBookmarksManager;

- (void)resolveConflictAtURL:(NSURL *)fileURL;

@end
