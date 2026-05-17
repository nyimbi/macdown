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
    options.brandColor = @"#3A6EA5";
    return options;
}

- (id)copyWithZone:(NSZone *)zone
{
    MPExportOptions *copy = [[[self class] allocWithZone:zone] init];
    copy.stylesIncluded = self.stylesIncluded;
    copy.highlightingIncluded = self.highlightingIncluded;
    copy.pageNumbersIncluded = self.pageNumbersIncluded;
    copy.headerText = self.headerText;
    copy.footerText = self.footerText;
    copy.logoPath = self.logoPath;
    copy.watermarkText = self.watermarkText;
    copy.brandColor = self.brandColor;
    return copy;
}

@end
