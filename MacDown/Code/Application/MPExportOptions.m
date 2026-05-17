//
//  MPExportOptions.m
//  MacDown
//

#import "MPExportOptions.h"

@implementation MPExportOptions

+ (instancetype)defaultOptions
{
    MPExportOptions *options = [[self alloc] init];
    options.stylesIncluded = YES;
    options.highlightingIncluded = YES;
    options.pageNumbersIncluded = YES;
    options.coverPageIncluded = YES;
    options.layoutStyle = MPExportLayoutStyleModern;
    options.brandColor = @"#3A6EA5";
    return options;
}

+ (NSString *)displayNameForLayoutStyle:(MPExportLayoutStyle)style
{
    switch (style)
    {
        case MPExportLayoutStyleClassic:
            return @"Classic";
        case MPExportLayoutStyleCompact:
            return @"Compact";
        case MPExportLayoutStyleModern:
        default:
            return @"Modern";
    }
}

- (id)copyWithZone:(NSZone *)zone
{
    MPExportOptions *copy = [[[self class] allocWithZone:zone] init];
    copy.stylesIncluded = self.stylesIncluded;
    copy.highlightingIncluded = self.highlightingIncluded;
    copy.pageNumbersIncluded = self.pageNumbersIncluded;
    copy.coverPageIncluded = self.coverPageIncluded;
    copy.layoutStyle = self.layoutStyle;
    copy.documentTitle = self.documentTitle;
    copy.subtitleText = self.subtitleText;
    copy.authorName = self.authorName;
    copy.headerText = self.headerText;
    copy.footerText = self.footerText;
    copy.logoPath = self.logoPath;
    copy.watermarkText = self.watermarkText;
    copy.brandColor = self.brandColor;
    return copy;
}

@end
