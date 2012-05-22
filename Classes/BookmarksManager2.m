//
//  BookmarksManager2.m
//  DocSets
//
//  Created by Ole Zorn on 22.05.12.
//  Copyright (c) 2012 omz:software. All rights reserved.
//

#import "BookmarksManager2.h"
#import "DocSet.h"
#import "NSString+RelativePath.h"
#import "BookmarksDocument.h"

//TODO: Save bookmarks locally when iCloud is not available
//TODO: Import legacy bookmarks

@implementation BookmarksManager2

@synthesize query=_query, bookmarks=_bookmarks, bookmarksModificationDate=_bookmarksModificationDate;

- (id)init
{
	self = [super init];
	if (self) {
		
		_query = [[NSMetadataQuery alloc] init];
		[_query setSearchScopes:[NSArray arrayWithObjects:NSMetadataQueryUbiquitousDataScope, nil]];
		[_query setPredicate:[NSPredicate predicateWithFormat:@"%K == 'Bookmarks.plist'", NSMetadataItemFSNameKey]];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(iCloudFileListReceived:) name:NSMetadataQueryDidFinishGatheringNotification object:_query];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(iCloudFileListReceived:) name:NSMetadataQueryDidUpdateNotification object:_query];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
		
		NSURL *ubiquityContainerURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
		NSLog(@"2: Container URL: %@", ubiquityContainerURL);
		
		[_query startQuery];
	}
	return self;
}

- (void)iCloudFileListReceived:(NSNotification *)notification
{
	[self.query disableUpdates];
	
	NSLog(@"2: ...");
	NSArray *queryResults = [self.query results];
	if (queryResults.count == 0) {
		if (!_movingToUbiquityContainer) {
			_movingToUbiquityContainer = YES;
			
			NSLog(@"2: Bookmarks file doesn't exist yet, saving...");
			NSFileManager *fm = [[NSFileManager alloc] init];
			//TODO: Merge in legacy bookmarks...
			
			//Discard any bookmarks that are loaded, the user may have deleted the data consciously from iCloud
			//and it shouldn't make a difference if the app is currently running while the data is deleted.
			self.bookmarks = [NSMutableDictionary dictionary];
			
			NSData *bookmarksData = [BookmarksDocument dataFromBookmarks:self.bookmarks error:NULL];
			
			NSURL *localDocumentsURL = [[fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] objectAtIndex:0];
			NSURL *tempBookmarksURL = [localDocumentsURL URLByAppendingPathComponent:@"TempBookmarks.plist"];
			[bookmarksData writeToURL:tempBookmarksURL atomically:YES];
			
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				NSLog(@"2: Moving new bookmarks file to iCloud container");
				NSURL *ubiquityContainerURL = [fm URLForUbiquityContainerIdentifier:nil];
				NSError *setUbiquitousError = nil;
				NSURL *destinationURL = [ubiquityContainerURL URLByAppendingPathComponent:@"Bookmarks.plist"];
				BOOL madeUbiquitous = [fm setUbiquitous:YES itemAtURL:tempBookmarksURL destinationURL:destinationURL error:&setUbiquitousError];
				
				if (madeUbiquitous) {
					NSLog(@"2: Bookmarks loaded");
				} else {
					NSLog(@"2: Error while moving to iCloud container: %@", setUbiquitousError);
					//TODO: Check for "file exists" error and try to open in that case...
					//TODO: Remove local temp file
				}
				_movingToUbiquityContainer = NO;
			});
		}
	} else {
		NSMetadataItem *metadataItem = [queryResults objectAtIndex:0];
		NSDate *modificationDate = [metadataItem valueForAttribute:NSMetadataItemFSContentChangeDateKey];
		NSURL *fileURL = [metadataItem valueForAttribute:NSMetadataItemURLKey];
		
		NSArray *conflictVersions = [NSFileVersion otherVersionsOfItemAtURL:fileURL];
		if (conflictVersions.count > 0) {
			NSFileVersion *currentVersion = [NSFileVersion currentVersionOfItemAtURL:fileURL];
			NSLog(@"2: >> Current version: %@ (%@)", [currentVersion localizedName], [currentVersion localizedNameOfSavingComputer]);
			for (NSFileVersion *version in conflictVersions) {
				NSLog(@"2: -- Conflict version: %@ (%@)", [version localizedName], [version localizedNameOfSavingComputer]);
			}
			[self resolveConflictAtURL:fileURL];
			
		} else {
			if (![modificationDate isEqual:self.bookmarksModificationDate]) {
				self.bookmarksModificationDate = modificationDate;
				
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
					
					NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
					NSError *coordinatorError = nil;
					[coordinator coordinateReadingItemAtURL:fileURL options:0 error:&coordinatorError byAccessor:^(NSURL *newURL) {
						NSData *bookmarksData = [NSData dataWithContentsOfURL:newURL];
						if (bookmarksData) {
							NSMutableDictionary *loadedBookmarks = [NSPropertyListSerialization propertyListWithData:bookmarksData options:NSPropertyListMutableContainers format:NULL error:NULL];
							if (loadedBookmarks) {
								self.bookmarks = loadedBookmarks;
								[self postChangeNotification];
							}
							NSLog(@"2: Bookmarks loaded: %@", loadedBookmarks);
						} else {
							NSLog(@"2: Could not load bookmarks!");
						}
					}];
					NSLog(@"2: Done loading");
					if (coordinatorError) {
						NSLog(@"    2: %@", coordinatorError);
						self.bookmarksModificationDate = nil;
					} else {
						NSLog(@"    2: (no error)");
					}
					
				});
			} else {
				NSLog(@"  2: Modification date of bookmark file not changed, ignoring...");
			}
		}
	}
	
	[self.query enableUpdates];
}

- (void)resolveConflictAtURL:(NSURL *)fileURL
{
	NSLog(@"2: Resolving conflict...");
	NSArray *conflictVersions = [NSFileVersion otherVersionsOfItemAtURL:fileURL];
	NSMutableArray *allVersions = [NSMutableArray arrayWithArray:conflictVersions];
	NSFileVersion *currentVersion = [NSFileVersion currentVersionOfItemAtURL:fileURL];
	if (currentVersion) {
		[allVersions insertObject:currentVersion atIndex:0];
	}
	
	//Read the bookmarks dictionary from all versions:
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSMutableArray *bookmarksVersions = [NSMutableArray array];
		for (NSFileVersion *conflictVersion in allVersions) {
			NSURL *versionURL = conflictVersion.URL;
			if (versionURL) {
				NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
				[coordinator coordinateReadingItemAtURL:versionURL options:0 error:NULL byAccessor:^(NSURL *newURL) {
					NSData *data = [NSData dataWithContentsOfURL:versionURL];
					if (data) {
						NSMutableDictionary *bookmarks = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListMutableContainers format:NULL error:NULL];
						if (bookmarks) {
							[bookmarksVersions addObject:bookmarks];
						}
					}
				}];
			}
		}
		
		//Merge all the versions into one dictionary:
		NSMutableDictionary *mergedBookmarks = [BookmarksDocument mergedBookmarksFromVersions:bookmarksVersions];
		
		//Write the dictionary to the document's file URL:
		NSFileCoordinator *writeCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
		[writeCoordinator coordinateWritingItemAtURL:fileURL options:NSFileCoordinatorWritingForReplacing error:NULL byAccessor:^(NSURL *newURL) {
			NSData *mergedBookmarksData = [BookmarksDocument dataFromBookmarks:mergedBookmarks error:NULL];
			if (mergedBookmarksData) {
				[mergedBookmarksData writeToURL:newURL atomically:YES];
			}
		}];
		
		//Remove the conflict versions and mark all conflicts as resolved:
		[NSFileVersion removeOtherVersionsOfItemAtURL:fileURL error:NULL];
		NSArray *remainingConflictVersions = [NSFileVersion unresolvedConflictVersionsOfItemAtURL:fileURL];
		for (NSFileVersion* fileVersion in remainingConflictVersions) {
			fileVersion.resolved = YES;
		}
		//Finished resolving conflict.
		
		self.bookmarks = mergedBookmarks;
		[self postChangeNotification];
		
		NSLog(@"2: Conflict resolved.");
		
	});
}

- (void)saveBookmarks
{
	NSFileManager *fm = [[NSFileManager alloc] init];
	NSData *bookmarksData = [BookmarksDocument dataFromBookmarks:self.bookmarks error:NULL];
	NSURL *ubiquityContainerURL = [fm URLForUbiquityContainerIdentifier:nil];
	NSURL *destinationURL = [ubiquityContainerURL URLByAppendingPathComponent:@"Bookmarks.plist"];
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSLog(@"2: Writing bookmarks...");
		NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
		[coordinator coordinateWritingItemAtURL:destinationURL options:0 error:NULL byAccessor:^(NSURL *newURL) {
			[bookmarksData writeToURL:newURL atomically:YES];
			//TODO: Update modification date
		}];
		
		NSLog(@"2: ... written.");
	});
}

- (void)postChangeNotification
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:BookmarksManagerDidLoadBookmarksNotification object:self];
	});
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
	[self.query enableUpdates];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
	[self.query disableUpdates];
}

+ (id)sharedBookmarksManager
{
	static id sharedManager = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedManager = [[self alloc] init];
	});
	return sharedManager;
}

#pragma mark -

- (NSMutableArray *)bookmarksForDocSet:(DocSet *)docSet
{
	if (!self.bookmarks) return nil;
	NSMutableArray *bookmarksForDocSet = [self.bookmarks objectForKey:docSet.bundleID];
	if (!bookmarksForDocSet) {
		bookmarksForDocSet = [NSMutableArray array];
		[self.bookmarks setObject:bookmarksForDocSet forKey:docSet.bundleID];
		[self saveBookmarks];
	}
	return bookmarksForDocSet;
}

- (BOOL)addBookmarkWithURL:(NSString *)bookmarkURL title:(NSString *)bookmarkTitle subtitle:(NSString *)subtitle forDocSet:(DocSet *)docSet
{
	if (!self.bookmarks) return NO;
	
	NSString *relativePath = [self relativeBookmarkPathWithBookmarkURL:bookmarkURL inDocSetWithPath:docSet.path];
	
	//TODO: Move bookmark to the top if one with the same path already exists...
	
	NSMutableArray *bookmarksForDocSet = [self.bookmarks objectForKey:docSet.bundleID];
	if (!bookmarksForDocSet) {
		bookmarksForDocSet = [NSMutableArray array];
		[self.bookmarks setObject:bookmarksForDocSet forKey:docSet.bundleID];
	}
	
	NSDictionary *bookmark = [NSDictionary dictionaryWithObjectsAndKeys:relativePath, @"path", bookmarkTitle, @"title", subtitle, @"subtitle", nil];
	[bookmarksForDocSet insertObject:bookmark atIndex:0];
	[self saveBookmarks];
	
	return YES;
}

- (NSString *)relativeBookmarkPathWithBookmarkURL:(NSString *)bookmarkURL inDocSetWithPath:(NSString *)docSetPath
{
	NSString *fragment = [[NSURL URLWithString:bookmarkURL] fragment];
	if (!fragment) fragment = @"";
	NSString *bookmarkPath = [[NSURL URLWithString:bookmarkURL] path];
	NSString *relativePath = [bookmarkPath relativePathFromBaseDirPath:docSetPath];
	if (fragment.length > 0) {
		relativePath = [relativePath stringByAppendingFormat:@"#%@", fragment];
	}
	return relativePath;
}

- (NSURL *)URLForBookmark:(NSDictionary *)bookmark inDocSet:(DocSet *)docSet
{
	NSString *relativeBookmarkPath = [bookmark objectForKey:@"path"];
	NSString *docSetPath = docSet.path;
	NSString *bookmarkURLString = [[[NSURL fileURLWithPath:docSetPath] absoluteString] stringByAppendingString:relativeBookmarkPath];
	if ([bookmarkURLString rangeOfString:@"__cached__"].location != NSNotFound) {
		bookmarkURLString = [bookmarkURLString stringByReplacingOccurrencesOfString:@"__cached__" withString:@""];
	}
	NSURL *bookmarkURL = [NSURL URLWithString:bookmarkURLString];
	return bookmarkURL;
}

- (NSURL *)webURLForBookmark:(NSDictionary *)bookmark inDocSet:(DocSet *)docSet
{
	NSURL *localBookmarkURL = [self URLForBookmark:bookmark inDocSet:docSet];
	return [docSet webURLForLocalURL:localBookmarkURL];
}

- (BOOL)deleteBookmarkAtIndex:(NSInteger)bookmarkIndex fromDocSet:(DocSet *)docSet
{
	if (!self.bookmarks) return NO;
	NSMutableArray *bookmarks = [self bookmarksForDocSet:docSet];
	[bookmarks removeObjectAtIndex:bookmarkIndex];
	[self saveBookmarks];
	return YES;
}

- (BOOL)moveBookmarkAtIndex:(NSInteger)fromIndex inDocSet:(DocSet *)docSet toIndex:(NSInteger)toIndex
{
	if (!self.bookmarks) return NO;
	
	NSMutableArray *bookmarks = [self.bookmarks objectForKey:docSet.bundleID];
	NSDictionary *movedBookmark = [bookmarks objectAtIndex:fromIndex];
	[bookmarks removeObjectAtIndex:fromIndex];
	if (toIndex >= [bookmarks count]) {
		[bookmarks addObject:movedBookmark];
	} else {
		[bookmarks insertObject:movedBookmark atIndex:toIndex];
	}
	[self saveBookmarks];
	return YES;
}


@end
