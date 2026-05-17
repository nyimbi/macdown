//
//  MPExportPanelAccessoryViewController.h
//  MacDown
//
//  Created by Tzu-ping Chung  on 14/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MPExportOptions.h"

@interface MPExportPanelAccessoryViewController : NSViewController

@property (getter=isStylesIncluded) BOOL stylesIncluded;
@property (getter=isHighlightingIncluded) BOOL highlightingIncluded;
@property (getter=arePageNumbersIncluded) BOOL pageNumbersIncluded;
@property (getter=isCoverPageIncluded) BOOL coverPageIncluded;
@property MPExportLayoutStyle layoutStyle;
@property (copy) NSString *documentTitle;
@property (copy) NSString *subtitleText;
@property (copy) NSString *authorName;
@property (copy) NSString *headerText;
@property (copy) NSString *footerText;
@property (copy) NSString *logoPath;
@property (copy) NSString *watermarkText;
@property (copy) NSString *brandColor;

- (MPExportOptions *)exportOptions;

@end
