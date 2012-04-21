//
//  BookmarksViewController.h
//  DocSets
//
//  Created by Ole Zorn on 26.01.12.
//  Copyright (c) 2012 omz:software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>

@class DocSet, DetailViewController;

@interface BookmarksViewController : UITableViewController <MFMailComposeViewControllerDelegate> {

	DocSet *docSet;
	__weak DetailViewController *detailViewController;
}

@property (nonatomic, weak) DetailViewController *detailViewController;

- (id)initWithDocSet:(DocSet *)selectedDocSet;

@end
