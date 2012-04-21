//
//  BookmarksDocument.m
//  DocSets
//
//  Created by Ole Zorn on 18.04.12.
//  Copyright (c) 2012 omz:software. All rights reserved.
//

#import "BookmarksDocument.h"

@implementation BookmarksDocument

@synthesize bookmarks=_bookmarks, delegate=_delegate;

- (id)contentsForType:(NSString *)typeName error:(NSError *__autoreleasing *)outError
{
	if (self.bookmarks) {
		return [[self class] dataFromBookmarks:self.bookmarks error:outError]; 
	} else {
		return [NSData data];
	}
}

- (BOOL)loadFromContents:(id)contents ofType:(NSString *)typeName error:(NSError **)outError
{
	NSData *data = (NSData *)contents;
	self.bookmarks = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListMutableContainers format:NULL error:outError];
	if ([self.delegate respondsToSelector:@selector(bookmarksDocumentDidLoad:)]) {
		[self.delegate bookmarksDocumentDidLoad:self];
	}
	return (self.bookmarks != nil);
}

+ (NSData *)dataFromBookmarks:(NSMutableDictionary *)bookmarksDict error:(NSError *__autoreleasing *)outError
{
	return [NSPropertyListSerialization dataWithPropertyList:bookmarksDict format:NSPropertyListBinaryFormat_v1_0 options:0 error:outError];
}

+ (NSMutableDictionary *)mergedBookmarksFromVersions:(NSArray *)bookmarksVersions
{
	//Merge multiple versions of the bookmarks by forming a union of all bookmarks in all versions.
	//NOTE: This will cause bookmarks that were deleted in just one version to re-appear, 
	//      but this is better than having added bookmarks disappear.
	
	NSMutableDictionary *mergedBookmarks = [NSMutableDictionary dictionary];
	
	NSMutableSet *allDocSetBundleIDs = [NSMutableSet set];
	for (NSMutableDictionary *bookmarksVersion in bookmarksVersions) {
		[allDocSetBundleIDs addObjectsFromArray:[bookmarksVersion allKeys]];
	}
	for (NSString *bundleID in allDocSetBundleIDs) {
		NSMutableSet *allBookmarkPaths = [NSMutableSet set];
		NSMutableArray *mergedBookmarksForBundleID = [NSMutableArray array];
		for (NSMutableDictionary *bookmarksVersion in bookmarksVersions) {
			NSMutableArray *bookmarksForBundleID = [bookmarksVersion objectForKey:bundleID];
			for (NSDictionary *bookmark in [bookmarksForBundleID reverseObjectEnumerator]) {
				NSString *bookmarkPath = [bookmark objectForKey:@"path"];
				if (![allBookmarkPaths containsObject:bookmarkPath]) {
					[allBookmarkPaths addObject:bookmarkPath];
					[mergedBookmarksForBundleID insertObject:bookmark atIndex:0];
				}
			}
		}
		[mergedBookmarks setObject:mergedBookmarksForBundleID forKey:bundleID];
	}
	return mergedBookmarks;
}


@end
