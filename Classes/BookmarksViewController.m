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


@implementation BookmarksViewController

@synthesize detailViewController;

- (id)initWithDocSet:(DocSet *)selectedDocSet
{
	self = [super initWithStyle:UITableViewStylePlain];
	if (self) {
		self.title = NSLocalizedString(@"Bookmarks", nil);
		if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
			self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done:)];
		} else {
			self.contentSizeForViewInPopover = CGSizeMake(320, 480);
		}
				
		UIBarButtonItem *shareItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareBookmarks:)];
		UIBarButtonItem *flexSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
		self.toolbarItems = [NSArray arrayWithObjects:[self editButtonItem], flexSpace, shareItem, nil];
		
		docSet = selectedDocSet;
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bookmarksDidUpdate:) name:BookmarksManagerDidLoadBookmarksNotification object:nil];
	}
	return self;
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
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
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
	
	[self.detailViewController showBookmark:selectedBookmark];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
