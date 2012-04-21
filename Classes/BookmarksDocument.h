//
//  BookmarksDocument.h
//  DocSets
//
//  Created by Ole Zorn on 18.04.12.
//  Copyright (c) 2012 omz:software. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BookmarksDocument;
@protocol BookmarksDocumentDelegate <NSObject>
@optional
- (void)bookmarksDocumentDidLoad:(BookmarksDocument *)document;

@end

@interface BookmarksDocument : UIDocument {

	__weak id<BookmarksDocumentDelegate> _delegate;
	NSMutableDictionary *_bookmarks;
}

@property (nonatomic, weak) id<BookmarksDocumentDelegate> delegate;
@property (nonatomic, strong) NSMutableDictionary *bookmarks;

+ (NSData *)dataFromBookmarks:(NSMutableDictionary *)bookmarksDict error:(NSError *__autoreleasing *)outError;
+ (NSMutableDictionary *)mergedBookmarksFromVersions:(NSArray *)bookmarksVersions;

@end
