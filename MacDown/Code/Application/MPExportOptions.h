//
//  MPExportOptions.h
//  MacDown
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, MPExportLayoutStyle) {
    MPExportLayoutStyleModern,
    MPExportLayoutStyleClassic,
    MPExportLayoutStyleCompact,
};

@interface MPExportOptions : NSObject <NSCopying>

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

+ (instancetype)defaultOptions;
+ (NSString *)displayNameForLayoutStyle:(MPExportLayoutStyle)style;

@end
