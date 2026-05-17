//
//  MPExportOptions.h
//  MacDown
//

#import <Foundation/Foundation.h>

@interface MPExportOptions : NSObject <NSCopying>

@property (getter=isStylesIncluded) BOOL stylesIncluded;
@property (getter=isHighlightingIncluded) BOOL highlightingIncluded;
@property (getter=arePageNumbersIncluded) BOOL pageNumbersIncluded;
@property (copy) NSString *headerText;
@property (copy) NSString *footerText;
@property (copy) NSString *logoPath;
@property (copy) NSString *watermarkText;
@property (copy) NSString *brandColor;

+ (instancetype)defaultOptions;

@end
