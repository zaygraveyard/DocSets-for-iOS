//
//  BookmarksManager.m
//  DocSets
//
//  Created by Ole Zorn on 19.04.12.
//  Copyright (c) 2012 omz:software. All rights reserved.
//

#import "BookmarksManager.h"
#import "DocSet.h"
#import "NSString+RelativePath.h"

//TODO: Add local bookmarks (if present) when enabling iCloud

//TODO: Don't add duplicate bookmarks (move to top instead)

//TODO: Add a bookmarks button in the DocSetViewController on iPhone

//TODO: Legacy bookmarks should also be merged when opening an existing document
//      (in case the app was updated on another device, so that an iCloud document is already there).


@implementation BookmarksManager

@synthesize document=_document, query=_query;
@synthesize bookmarksAvailable=_bookmarksAvailable, bookmarksEditable=_bookmarksEditable;

- (id)init
{
	self = [super init];
	if (self) {
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(iCloudFileListReceived:) name:NSMetadataQueryDidFinishGatheringNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(iCloudFileListReceived:) name:NSMetadataQueryDidUpdateNotification object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(documentStateChanged:) name:UIDocumentStateChangedNotification object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
	}
	return self;
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

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
	[self loadBookmarksIfNeeded];
}

- (void)loadBookmarksIfNeeded
{
	if (self.query) {
		return;
	}
	
	NSURL *ubiquityContainerURL = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
	BOOL iCloudAvailable = (ubiquityContainerURL != nil);
	BOOL iCloudWasAvailable = [[NSUserDefaults standardUserDefaults] boolForKey:@"iCloudAvailable"];
	BOOL iCloudAvailabilityChanged = (iCloudAvailable != iCloudWasAvailable);
	if (iCloudAvailabilityChanged) {
		//NSLog(@"iCloud availability changed!");
		[[NSUserDefaults standardUserDefaults] setBool:iCloudAvailable forKey:@"iCloudAvailable"];
	}
	
	if (self.document && !iCloudAvailabilityChanged) {
		//Nothing changed and bookmarks are already loaded.
		return;
	}
	
	if (iCloudAvailabilityChanged || !self.document) {
		//Either bookmarks aren't loaded yet (directly after launch), or iCloud was enabled/disabled.
		if (iCloudAvailable) {
			//NSLog(@"iCloud is available, locating bookmarks...");
			//Start metadata query and open/create the document when it has results:
			self.bookmarksAvailable = NO;
			self.bookmarksEditable = NO;
			self.document.delegate = nil;
			self.document = nil;
			[self locateAndOpenDocumentInCloud];
		} else {
			//NSLog(@"iCloud is not available, using local document.");
			self.bookmarksAvailable = NO;
			self.bookmarksEditable = NO;
			self.document.delegate = nil;
			self.document = nil;
			NSString *documentsDirectoryPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES ) objectAtIndex:0];
			NSURL *localDocumentsDirectoryURL = [NSURL fileURLWithPath:documentsDirectoryPath];
			NSString *filename = @"Bookmarks.docsetsbm";
			NSURL *localDocumentFileURL = [localDocumentsDirectoryURL URLByAppendingPathComponent:filename];
			if ([[NSFileManager defaultManager] fileExistsAtPath:localDocumentFileURL.path]) {
				self.document = [[BookmarksDocument alloc] initWithFileURL:localDocumentFileURL];
				self.document.delegate = self;
				[self.document openWithCompletionHandler:^(BOOL success) {
					//NSLog(@"Opened existing local document: %i", success);
					self.bookmarksAvailable = success;
					self.bookmarksEditable = success;
				}];
			} else {
				//NSLog(@"Creating new local document...");
				[self makeNewDocumentAndMoveToCloud:NO];
			}
		}
	}
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
}

#pragma mark - Data Migration

- (NSMutableDictionary *)legacyBookmarks
{
	NSMutableDictionary *allLegacyBookmarks = [NSMutableDictionary dictionary];
	NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
	NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:docPath error:NULL];
	for (NSString *item in items) {
		if ([[item pathExtension] isEqualToString:@"docset"]) {
			NSString *docSetPath = [docPath stringByAppendingPathComponent:item];
			NSString *legacyBookmarksPath = [docSetPath stringByAppendingPathComponent:@"Bookmarks.plist"];
			NSString *infoPlistPath = [docSetPath stringByAppendingPathComponent:@"Contents/Info.plist"];
			NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
			NSString *docSetBundleID = [infoPlist objectForKey:@"CFBundleIdentifier"];
			NSArray *legacyBookmarksForDocSet = [NSArray arrayWithContentsOfFile:legacyBookmarksPath];
			NSMutableArray *bookmarksForDocSet = [NSMutableArray array];
			if (legacyBookmarksForDocSet && docSetBundleID) {
				for (NSDictionary *legacyBookmark in legacyBookmarksForDocSet) {
					NSString *legacyBookmarkURL = [legacyBookmark objectForKey:@"URL"];
					NSString *legacyBookmarkTitle = [legacyBookmark objectForKey:@"title"];
					NSString *bookmarkPath = [self relativeBookmarkPathWithBookmarkURL:legacyBookmarkURL inDocSetWithPath:docSetPath];
					NSDictionary *bookmark = [NSDictionary dictionaryWithObjectsAndKeys:
											  legacyBookmarkTitle, @"title", 
											  @"", @"subtitle",
											  bookmarkPath, @"path", nil];
					[bookmarksForDocSet addObject:bookmark];
				}
			}
			if (bookmarksForDocSet.count > 0) {
				[allLegacyBookmarks setObject:bookmarksForDocSet forKey:docSetBundleID];
			}
		}
	}
	return allLegacyBookmarks;
}

- (void)removeLegacyBookmarks
{
	NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
	NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:docPath error:NULL];
	NSFileManager *fm = [NSFileManager new];
	for (NSString *item in items) {
		if ([[item pathExtension] isEqualToString:@"docset"]) {
			NSString *docSetPath = [docPath stringByAppendingPathComponent:item];
			NSString *legacyBookmarksPath = [docSetPath stringByAppendingPathComponent:@"Bookmarks.plist"];
			[fm removeItemAtPath:legacyBookmarksPath error:NULL];
		}
	}
}

#pragma mark - Bookmarks Document Management

- (void)locateAndOpenDocumentInCloud
{
	if (!self.query) {
		self.query = [[NSMetadataQuery alloc] init];
		[_query setSearchScopes:[NSArray arrayWithObjects:NSMetadataQueryUbiquitousDocumentsScope, nil]];
		[_query setPredicate:[NSPredicate predicateWithFormat:@"%K == 'Bookmarks.docsetsbm'", NSMetadataItemFSNameKey]];
		[_query startQuery];
	}
}

- (void)iCloudFileListReceived:(NSNotification *)notification
{
	if (notification.object != self.query) return;
	
	//NSLog(@"File list received");
	[self.query disableUpdates];
	NSArray *queryResults = [self.query results];
	if (queryResults.count == 0 && !self.document) {
		//NSLog(@"  No document found in iCloud, create a new one...");
		//Create new document...
		[self makeNewDocumentAndMoveToCloud:YES];
	} else {
		if (!self.document) {
			//Open document...
			NSMetadataItem *metadataItem = [queryResults objectAtIndex:0];
			NSURL *fileURL = [metadataItem valueForAttribute:NSMetadataItemURLKey];
			//NSLog(@"  Existing document found in iCloud: %@", fileURL);
			self.document = [[BookmarksDocument alloc] initWithFileURL:fileURL];
			self.document.delegate = self;
			[self.document openWithCompletionHandler:^(BOOL success) {
				self.bookmarksAvailable = success;
				self.bookmarksEditable = success;
				if (!success) {
					//NSLog(@"   Could not open bookmarks document in iCloud");
				}
			}];
		}
	}
	self.query = nil;
	//[self.query enableUpdates];
}

- (void)makeNewDocumentAndMoveToCloud:(BOOL)moveToCloud
{
	NSString *documentsDirectoryPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES ) objectAtIndex:0];
	NSURL *localDocumentsDirectoryURL = [NSURL fileURLWithPath:documentsDirectoryPath];
	
	NSString *filename = @"Bookmarks.docsetsbm";
	NSString *tempFileName = @"Temp.docsetsbm";
	
	NSURL *localDocumentFileURL = [localDocumentsDirectoryURL URLByAppendingPathComponent:(moveToCloud) ? tempFileName : filename];
	
	if (moveToCloud) {
		[[NSFileManager defaultManager] removeItemAtURL:localDocumentFileURL error:NULL];
	}
	
	BookmarksDocument *newDocument = [[BookmarksDocument alloc] initWithFileURL:localDocumentFileURL];
	newDocument.bookmarks = [self legacyBookmarks];
	[self removeLegacyBookmarks];
	
	[newDocument saveToURL:newDocument.fileURL forSaveOperation:UIDocumentSaveForCreating completionHandler:^(BOOL success) {
		if (success && moveToCloud) {
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				NSFileManager *fm = [NSFileManager new];
				NSURL *ubiquityDocumentsURL = [[fm URLForUbiquityContainerIdentifier:nil] URLByAppendingPathComponent:@"Documents"];
				NSURL *destinationURL = [ubiquityDocumentsURL URLByAppendingPathComponent:filename];
				
				NSError *setUbiquitousError = nil;
				BOOL successfullyMovedToCloud = [fm setUbiquitous:YES itemAtURL:newDocument.fileURL destinationURL:destinationURL error:&setUbiquitousError];
				if (!successfullyMovedToCloud) {
					if (setUbiquitousError.code == NSFileWriteFileExistsError) {
						//NSLog(@"Document already exists, trying to open...");
						//The iCloud document already exists, try to open it:
						self.document.delegate = nil;
						self.document = nil;
						self.document = [[BookmarksDocument alloc] initWithFileURL:destinationURL];
						self.document.delegate = self;
						[self.document openWithCompletionHandler:^(BOOL success) {
							//NSLog(@"  document opened.");
							self.bookmarksAvailable = success;
							self.bookmarksEditable = success;
							if (!success) {
								NSLog(@"Could not open bookmarks document");
							}
						}];
					} else {
						NSLog(@"Unhandled error while trying to move document to iCloud: %@", setUbiquitousError);
					}
				} else {
					dispatch_async(dispatch_get_main_queue(), ^{
						self.document = newDocument;
						self.document.delegate = self;
						[self.document openWithCompletionHandler:^(BOOL success) {
							self.bookmarksAvailable = success;
							self.bookmarksEditable = success;
							if (!success) {
								NSLog(@"Could not open bookmarks document");
							}
						}];
					});
				}
			});
		} else if (success && !moveToCloud) {
			self.document = newDocument;
			self.document.delegate = self;
			self.bookmarksAvailable = YES;
			self.bookmarksEditable = YES;
			[self.document openWithCompletionHandler:nil];
		} else if (!success) {
			NSLog(@"Could not create bookmarks document");
		}
	}];
}

- (void)documentStateChanged:(NSNotification *)notification
{
	if (notification.object == self.document) {
		UIDocumentState state = self.document.documentState;
		//NSLog(@"Document state changed: %i", state);
		if (state == UIDocumentStateNormal) {
			self.bookmarksAvailable = YES;
			self.bookmarksEditable = YES;
		} else {
			if (state & UIDocumentStateEditingDisabled) {
				self.bookmarksEditable = NO;
			} else {
				self.bookmarksEditable = YES;
			}
			if (state & UIDocumentStateClosed) {
				self.bookmarksAvailable = NO;
				self.bookmarksEditable = NO;
			}
			if (state & UIDocumentStateSavingError) {
				//Document was probably deleted from iCloud.
				self.document.delegate = nil;
				self.document = nil;
				self.bookmarksAvailable = NO;
				self.bookmarksEditable = NO;
				if (self.query) {
					[self.query disableUpdates];
					self.query = nil;
				}
				[self loadBookmarksIfNeeded];
			}
			if (state & UIDocumentStateInConflict) {
				if (!isResolvingConflict) {
					[self resolveConflict];
				}
			}
		}
	}
}

- (void)resolveConflict
{
	//NSLog(@"Resolving version conflict...");
	//Set a flag, so that multiple state changed notifications don't result in starting the conflict resolution multiple times.
	isResolvingConflict = YES;
	
	//Gather all versions, including the current one:
	NSArray *conflictVersions = [NSFileVersion otherVersionsOfItemAtURL:self.document.fileURL];
	NSMutableArray *allVersions = [NSMutableArray arrayWithArray:conflictVersions];
	NSFileVersion *currentVersion = [NSFileVersion currentVersionOfItemAtURL:self.document.fileURL];
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
		[writeCoordinator coordinateWritingItemAtURL:self.document.fileURL options:NSFileCoordinatorWritingForReplacing error:NULL byAccessor:^(NSURL *newURL) {
			NSData *mergedBookmarksData = [BookmarksDocument dataFromBookmarks:mergedBookmarks error:NULL];
			if (mergedBookmarksData) {
				[mergedBookmarksData writeToURL:newURL atomically:YES];
			}
		}];
		
		//Remove the conflict versions and mark all conflicts as resolved:
		[NSFileVersion removeOtherVersionsOfItemAtURL:self.document.fileURL error:NULL];
		NSArray *remainingConflictVersions = [NSFileVersion unresolvedConflictVersionsOfItemAtURL:self.document.fileURL];
		for (NSFileVersion* fileVersion in remainingConflictVersions) {
			fileVersion.resolved = YES;
		}
		//Finished resolving conflict.
		isResolvingConflict = NO;
	});	
}

- (void)bookmarksDocumentDidLoad:(BookmarksDocument *)document
{
	[[NSNotificationCenter defaultCenter] postNotificationName:BookmarksDidUpdateNotification object:self userInfo:nil];
}

#pragma mark - Accessing and Editing Bookmarks

- (NSMutableArray *)bookmarksForDocSet:(DocSet *)docSet
{
	if (!self.document) return nil;
	NSMutableArray *bookmarksForDocSet = [self.document.bookmarks objectForKey:docSet.bundleID];
	if (!bookmarksForDocSet) {
		bookmarksForDocSet = [NSMutableArray array];
		[self.document.bookmarks setObject:bookmarksForDocSet forKey:docSet.bundleID];
		[self.document updateChangeCount:UIDocumentChangeDone];
	}
	return bookmarksForDocSet;
}

- (BOOL)addBookmarkWithURL:(NSString *)bookmarkURL title:(NSString *)bookmarkTitle subtitle:(NSString *)subtitle forDocSet:(DocSet *)docSet
{
	if (!self.document || !self.bookmarksEditable) {
		return NO;
	}
	
	NSString *relativePath = [self relativeBookmarkPathWithBookmarkURL:bookmarkURL inDocSetWithPath:docSet.path];
				
	//TODO: Move bookmark to the top if one with the same path already exists...
	
	NSMutableArray *bookmarksForDocSet = [self.document.bookmarks objectForKey:docSet.bundleID];
	if (!bookmarksForDocSet) {
		bookmarksForDocSet = [NSMutableArray array];
		[self.document.bookmarks setObject:bookmarksForDocSet forKey:docSet.bundleID];
	}
	
	NSDictionary *bookmark = [NSDictionary dictionaryWithObjectsAndKeys:relativePath, @"path", bookmarkTitle, @"title", subtitle, @"subtitle", nil];
	[bookmarksForDocSet insertObject:bookmark atIndex:0];
	[self.document updateChangeCount:UIDocumentChangeDone];
	
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
	if (!self.document || !self.bookmarksEditable) {
		return NO;
	}
	NSMutableArray *bookmarks = [self bookmarksForDocSet:docSet];
	[bookmarks removeObjectAtIndex:bookmarkIndex];
	[self.document updateChangeCount:UIDocumentChangeDone];
	return YES;
}

- (BOOL)moveBookmarkAtIndex:(NSInteger)fromIndex inDocSet:(DocSet *)docSet toIndex:(NSInteger)toIndex
{
	if (!self.document || !self.bookmarksEditable) {
		return NO;
	}
	NSMutableArray *bookmarks = [self.document.bookmarks objectForKey:docSet.bundleID];
	NSDictionary *movedBookmark = [bookmarks objectAtIndex:fromIndex];
	[bookmarks removeObjectAtIndex:fromIndex];
	if (toIndex >= [bookmarks count]) {
		[bookmarks addObject:movedBookmark];
	} else {
		[bookmarks insertObject:movedBookmark atIndex:toIndex];
	}
	[self.document updateChangeCount:UIDocumentChangeDone];
	return YES;
}

#pragma mark -

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
