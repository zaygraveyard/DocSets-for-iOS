//
//  BookmarksViewController.m
//  DocSets
//
//  Created by Ole Zorn on 26.01.12.
//  Copyright (c) 2012 omz:software. All rights reserved.
//

#import "BookmarksViewController.h"
#import "DetailViewController.h"
#import "DocSet.h"
#import "BookmarksManager.h"
#import "BookmarkSyncLogViewController.h"

#define SYNC_STATUS_ALERT_TAG	1

@implementation BookmarksViewController

@synthesize syncInfoButtonItem = _syncInfoButtonItem;
@synthesize syncInfoTitleItem = _syncInfoTitleItem;
@synthesize syncTitleLabel = _syncTitleLabel;
@synthesize delegate=_delegate;

- (id)initWithDocSet:(DocSet *)selectedDocSet
{
	self = [super initWithStyle:UITableViewStylePlain];
	if (self) {
		self.title = NSLocalizedString(@"Bookmarks", nil);
		if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
			self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done:)];
		else
			self.contentSizeForViewInPopover = CGSizeMake(320, 480);
		
        self.navigationItem.leftBarButtonItem = self.editButtonItem;
        
        self.syncTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, 220.0, 29.0)];
        self.syncTitleLabel.textColor = [UIColor whiteColor];
        self.syncTitleLabel.font = [UIFont systemFontOfSize:12.0];
        self.syncTitleLabel.backgroundColor = [UIColor clearColor];
        self.syncInfoTitleItem = [[UIBarButtonItem alloc] initWithCustomView:self.syncTitleLabel];
        
        UIBarButtonItem *flexSpace1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        UIBarButtonItem *flexSpace2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
		UIBarButtonItem *shareItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareBookmarks:)];
		self.toolbarItems = [NSArray arrayWithObjects:flexSpace1, flexSpace2, shareItem, nil];
        
		docSet = selectedDocSet;
		
		UIButton *cloudButton = [UIButton buttonWithType:UIButtonTypeCustom];
		[cloudButton setImage:[UIImage imageNamed:@"CloudLog.png"] forState:UIControlStateNormal];
		cloudButton.showsTouchWhenHighlighted = YES;
		cloudButton.frame = CGRectMake(0, 0, 29, 29);
		[cloudButton addTarget:self action:@selector(showBookmarkSyncLogViewController) forControlEvents:UIControlEventTouchUpInside];
		self.syncInfoButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cloudButton];
		
		[[BookmarksManager sharedBookmarksManager] addObserver:self forKeyPath:@"iCloudEnabled" options:NSKeyValueObservingOptionNew context:nil];
		[self showOrHideSyncLogButton];
		
        if ([[BookmarksManager sharedBookmarksManager] iCloudEnabled])
            [self updateSyncState];
        
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bookmarksDidUpdate:) name:BookmarksManagerDidLoadBookmarksNotification object:nil];
	}
	return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[self showOrHideSyncLogButton];
}

- (void)showOrHideSyncLogButton
{
	BOOL iCloudEnabled = [[BookmarksManager sharedBookmarksManager] iCloudEnabled];
	if (iCloudEnabled) {
		NSMutableArray *items = self.toolbarItems.mutableCopy;
        if (![items containsObject:self.syncInfoButtonItem])
            [items insertObject:self.syncInfoButtonItem atIndex:0];
        if (![items containsObject:self.syncInfoTitleItem])
            [items insertObject:self.syncInfoTitleItem atIndex:2];
        self.toolbarItems = items;
	} else {
		NSMutableArray *items = self.toolbarItems.mutableCopy;
        [items removeObject:self.syncInfoButtonItem];
        [items removeObject:self.syncInfoTitleItem];
        self.toolbarItems = items;
	}
}

- (void)updateSyncState
{
	NSDate *modifiedDate = [[BookmarksManager sharedBookmarksManager] bookmarksModificationDate];
    
    if (modifiedDate) {
        NSString *modifiedDateString = [NSDateFormatter localizedStringFromDate:modifiedDate dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterShortStyle];
        NSString *shortSyncStatus = [NSString stringWithFormat:NSLocalizedString(@"Last modified: %@", nil), modifiedDateString];
        self.syncTitleLabel.text = shortSyncStatus;
    }
}

- (void)showBookmarkSyncLogViewController
{
    BookmarkSyncLogViewController *vc = [[BookmarkSyncLogViewController alloc] initWithStyle:UITableViewStylePlain];
    vc.title = NSLocalizedString(@"iCloud Sync Log", nil);
    vc.contentSizeForViewInPopover = self.contentSizeForViewInPopover;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if (alertView.tag == SYNC_STATUS_ALERT_TAG) {
		if (buttonIndex != alertView.cancelButtonIndex) {
			[self showBookmarkSyncLogViewController];
		}
	}
}

- (void)shareBookmarks:(id)sender
{
	if (![MFMailComposeViewController canSendMail]) {
		[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cannot Send Mail", nil)
									message:NSLocalizedString(@"Your device is not configured for sending email. Please use the Settings app to set up an email account.", nil)
								   delegate:nil
						  cancelButtonTitle:NSLocalizedString(@"OK", nil)
						  otherButtonTitles:nil] show];
		return;
	}
	
	MFMailComposeViewController *mailComposer = [[MFMailComposeViewController alloc] init];
	[mailComposer setSubject:NSLocalizedString(@"DocSets Bookmarks", nil)];
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		mailComposer.modalPresentationStyle = UIModalPresentationFormSheet;
	}
	mailComposer.mailComposeDelegate = self;
	
	NSMutableString *html = [NSMutableString string];
	NSArray *bookmarks = [[BookmarksManager sharedBookmarksManager] bookmarksForDocSet:docSet];
	for (NSDictionary *bookmark in bookmarks) {
		[html appendFormat:@"<p><a href='%@'>%@</a><br/><span style='color:#666'>%@</span></p>", [[BookmarksManager sharedBookmarksManager] webURLForBookmark:bookmark inDocSet:docSet], [bookmark objectForKey:@"title"], [bookmark objectForKey:@"subtitle"] ? [bookmark objectForKey:@"subtitle"] : @""];
	}
	[mailComposer setMessageBody:html isHTML:YES];
	
	[self presentModalViewController:mailComposer animated:YES];
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
	[controller dismissModalViewControllerAnimated:YES];
}

- (void)bookmarksDidUpdate:(NSNotification *)notification
{
	[self.tableView reloadData];
    [self updateSyncState];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		return YES;
	}
	return UIInterfaceOrientationIsLandscape(interfaceOrientation) || (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)done:(id)sender
{
	[self dismissModalViewControllerAnimated:YES];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
	[super setEditing:editing animated:animated];
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
		if (editing) {
			self.navigationItem.rightBarButtonItem = nil;
		} else {
			self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done:)];
		}
	}
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [[[BookmarksManager sharedBookmarksManager] bookmarksForDocSet:docSet] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *CellIdentifier = @"Cell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
		cell.textLabel.minimumFontSize = 13.0;
		cell.textLabel.adjustsFontSizeToFitWidth = YES;
		cell.textLabel.lineBreakMode = UILineBreakModeMiddleTruncation;
	}
	
	NSDictionary *bookmark = [[[BookmarksManager sharedBookmarksManager] bookmarksForDocSet:docSet] objectAtIndex:indexPath.row];
	
	cell.textLabel.text = [bookmark objectForKey:@"title"];
	cell.detailTextLabel.text = [bookmark objectForKey:@"subtitle"];
    
	return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		if ([[BookmarksManager sharedBookmarksManager] deleteBookmarkAtIndex:indexPath.row fromDocSet:docSet]) {
			[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
		} else {
			[[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
										message:NSLocalizedString(@"Bookmarks are currently being synced. Please try again in a moment.", nil)
									   delegate:nil
							  cancelButtonTitle:NSLocalizedString(@"OK", nil)
							  otherButtonTitles:nil] show];
		}
	}
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
	if (toIndexPath.row != fromIndexPath.row) {
		[[BookmarksManager sharedBookmarksManager] moveBookmarkAtIndex:fromIndexPath.row inDocSet:docSet toIndex:toIndexPath.row];
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	NSDictionary *selectedBookmark = [[[BookmarksManager sharedBookmarksManager] bookmarksForDocSet:docSet] objectAtIndex:indexPath.row];
	
	if ([self.delegate respondsToSelector:@selector(bookmarksViewController:didSelectBookmark:)]) {
		[self.delegate bookmarksViewController:self didSelectBookmark:selectedBookmark];
	}
}

- (void)dealloc
{
	[[BookmarksManager sharedBookmarksManager] removeObserver:self forKeyPath:@"iCloudEnabled"];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
