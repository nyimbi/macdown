//
//  MPDocumentCompiler.m
//  MacDown
//

#import "MPDocumentCompiler.h"
#import "MPExportOptions.h"
#import "NSString+Lookup.h"

static const NSUInteger kMPDocumentCompilerMaximumIncludeDepth = 32;

@implementation MPCompiledDocument
@end

@interface MPDocumentCompiler ()

@property (strong) NSMutableArray *includedFileURLs;
@property (strong) NSMutableArray *warnings;
@property (strong) NSMutableSet *activeIncludePaths;

@end

@implementation MPDocumentCompiler

+ (MPCompiledDocument *)compileMarkdown:(NSString *)markdown
                                baseURL:(NSURL *)baseURL
{
    MPDocumentCompiler *compiler = [[self alloc] init];
    return [compiler compileMarkdown:markdown baseURL:baseURL];
}

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;
    _includedFileURLs = [NSMutableArray array];
    _warnings = [NSMutableArray array];
    _activeIncludePaths = [NSMutableSet set];
    return self;
}

- (MPCompiledDocument *)compileMarkdown:(NSString *)markdown baseURL:(NSURL *)baseURL
{
    NSDictionary *metadata = [self metadataFromMarkdown:markdown] ?: @{};
    NSString *body = [self markdownByStrippingFrontMatter:markdown ?: @""];
    body = [self markdownByApplyingMetadataControlsToMarkdown:body
                                                     metadata:metadata];
    NSString *compiledMarkdown = [self markdownByResolvingIncludesInMarkdown:body
                                                                     baseURL:baseURL
                                                                       depth:0];
    MPCompiledDocument *document = [[MPCompiledDocument alloc] init];
    document.markdown = compiledMarkdown ?: @"";
    document.metadata = metadata;
    document.includedFileURLs = [self.includedFileURLs copy];
    document.warnings = [self.warnings copy];
    return document;
}

- (NSDictionary *)metadataFromMarkdown:(NSString *)markdown
{
    id metadata = [markdown frontMatter:NULL];
    if ([metadata isKindOfClass:[NSDictionary class]])
        return metadata;
    if ([metadata respondsToSelector:@selector(allKeys)]
            && [metadata respondsToSelector:@selector(objectForKey:)])
    {
        NSMutableDictionary *result = [NSMutableDictionary dictionary];
        for (id key in [metadata allKeys])
        {
            id value = [metadata objectForKey:key];
            if (key && value)
                result[key] = value;
        }
        return result;
    }
    return nil;
}

- (NSString *)markdownByStrippingFrontMatter:(NSString *)markdown
{
    NSUInteger offset = 0;
    [markdown frontMatter:&offset];
    if (!offset)
        return markdown ?: @"";
    return [markdown substringFromIndex:offset];
}

- (NSString *)markdownByApplyingMetadataControlsToMarkdown:(NSString *)markdown
                                                   metadata:(NSDictionary *)metadata
{
    BOOL needsTOC = [[self class] boolForMetadataKey:@"toc"
                                           metadata:metadata
                                       defaultValue:NO];
    if (!needsTOC)
    {
        needsTOC = [[self class] boolForMetadataKey:@"tableOfContents"
                                           metadata:metadata
                                       defaultValue:NO];
    }
    if (!needsTOC || [markdown rangeOfString:@"[TOC]"].location != NSNotFound)
        return markdown ?: @"";
    return [NSString stringWithFormat:@"[TOC]\n\n%@", markdown ?: @""];
}

- (NSString *)markdownByResolvingIncludesInMarkdown:(NSString *)markdown
                                           baseURL:(NSURL *)baseURL
                                             depth:(NSUInteger)depth
{
    if (depth >= kMPDocumentCompilerMaximumIncludeDepth)
    {
        [self.warnings addObject:@"Maximum include depth exceeded."];
        return markdown ?: @"";
    }

    NSMutableString *result = [NSMutableString string];
    NSArray *lines = [markdown componentsSeparatedByCharactersInSet:
                      [NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines)
    {
        NSString *path = [self includePathInLine:line];
        if (!path)
        {
            [result appendString:line ?: @""];
            [result appendString:@"\n"];
            continue;
        }

        NSURL *url = [self URLForIncludePath:path baseURL:baseURL];
        NSString *included = [self includedMarkdownAtURL:url
                                             displayPath:path
                                                   depth:depth + 1];
        [result appendFormat:@"\n\n<!-- include: %@ -->\n%@\n<!-- end include: %@ -->\n\n",
                             path, included ?: @"", path];
    }
    return result;
}

- (NSString *)includePathInLine:(NSString *)line
{
    NSString *trimmed =
        [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (!trimmed.length)
        return nil;

    NSArray *patterns = @[
        @"^!include\\s+(.+)$",
        @"^\\{\\{include\\s+(.+)\\}\\}$",
        @"^<!--\\s*include:\\s*(.+?)\\s*-->$",
    ];
    for (NSString *pattern in patterns)
    {
        NSRegularExpression *regex =
            [NSRegularExpression regularExpressionWithPattern:pattern
                                                      options:NSRegularExpressionCaseInsensitive
                                                        error:NULL];
        NSTextCheckingResult *match =
            [regex firstMatchInString:trimmed options:0
                                range:NSMakeRange(0, trimmed.length)];
        if (!match)
            continue;
        NSString *path = [trimmed substringWithRange:[match rangeAtIndex:1]];
        path = [path stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (([path hasPrefix:@"\""] && [path hasSuffix:@"\""])
                || ([path hasPrefix:@"'"] && [path hasSuffix:@"'"]))
            path = [path substringWithRange:NSMakeRange(1, path.length - 2)];
        return path.length ? path : nil;
    }
    return nil;
}

- (NSURL *)URLForIncludePath:(NSString *)path baseURL:(NSURL *)baseURL
{
    NSString *expanded = [path stringByExpandingTildeInPath];
    if ([expanded isAbsolutePath])
        return [NSURL fileURLWithPath:expanded];

    NSURL *directoryURL = baseURL;
    if (directoryURL && !directoryURL.isFileURL)
        directoryURL = nil;
    if (directoryURL && !directoryURL.hasDirectoryPath)
        directoryURL = [directoryURL URLByDeletingLastPathComponent];
    if (!directoryURL)
        directoryURL = [NSURL fileURLWithPath:[[NSFileManager defaultManager] currentDirectoryPath]
                                  isDirectory:YES];
    return [[directoryURL URLByAppendingPathComponent:expanded] absoluteURL];
}

- (NSString *)includedMarkdownAtURL:(NSURL *)url
                         displayPath:(NSString *)displayPath
                               depth:(NSUInteger)depth
{
    if (!url.isFileURL)
    {
        [self.warnings addObject:
         [NSString stringWithFormat:@"Include is not a local file: %@", displayPath]];
        return [self warningMarkdownForPath:displayPath reason:@"not a local file"];
    }

    NSString *path = url.path.stringByStandardizingPath;
    if ([self.activeIncludePaths containsObject:path])
    {
        [self.warnings addObject:
         [NSString stringWithFormat:@"Circular include skipped: %@", displayPath]];
        return [self warningMarkdownForPath:displayPath reason:@"circular include"];
    }

    NSError *error = nil;
    NSString *markdown = [NSString stringWithContentsOfURL:url
                                                  encoding:NSUTF8StringEncoding
                                                     error:&error];
    if (!markdown)
    {
        [self.warnings addObject:
         [NSString stringWithFormat:@"Could not read include %@: %@",
                                    displayPath, error.localizedDescription ?: @"unknown error"]];
        return [self warningMarkdownForPath:displayPath reason:@"could not be read"];
    }

    [self.includedFileURLs addObject:url];
    [self.activeIncludePaths addObject:path];
    NSString *body = [self markdownByStrippingFrontMatter:markdown];
    NSString *included = [self markdownByResolvingIncludesInMarkdown:body
                                                             baseURL:url
                                                               depth:depth];
    [self.activeIncludePaths removeObject:path];
    return included;
}

- (NSString *)warningMarkdownForPath:(NSString *)path reason:(NSString *)reason
{
    return [NSString stringWithFormat:@"> Include `%@` %@.", path, reason];
}

+ (void)applyMetadataFromCompiledDocument:(MPCompiledDocument *)document
                          toExportOptions:(MPExportOptions *)options
{
    NSDictionary *metadata = document.metadata;
    if (!metadata.count || !options)
        return;

    NSString *title = [self stringForMetadataKey:@"title" metadata:metadata];
    if (title.length)
        options.documentTitle = title;
    NSString *subtitle = [self stringForMetadataKey:@"subtitle" metadata:metadata];
    if (subtitle.length)
        options.subtitleText = subtitle;
    NSString *author = [self stringForMetadataKey:@"author" metadata:metadata];
    if (author.length)
        options.authorName = author;
    NSString *header = [self stringForMetadataKey:@"header" metadata:metadata];
    if (header.length)
        options.headerText = header;
    NSString *footer = [self stringForMetadataKey:@"footer" metadata:metadata];
    if (footer.length)
        options.footerText = footer;
    NSString *logo = [self stringForMetadataKey:@"logo" metadata:metadata];
    if (logo.length)
        options.logoPath = logo;
    NSString *watermark = [self stringForMetadataKey:@"watermark" metadata:metadata];
    if (watermark.length)
        options.watermarkText = watermark;
    NSString *brandColor = [self stringForMetadataKey:@"brandColor" metadata:metadata];
    if (!brandColor.length)
        brandColor = [self stringForMetadataKey:@"brand_color" metadata:metadata];
    if (brandColor.length)
        options.brandColor = brandColor;

    options.coverPageIncluded =
        [self boolForMetadataKey:@"coverPage"
                        metadata:metadata
                    defaultValue:options.coverPageIncluded];
    options.pageNumbersIncluded =
        [self boolForMetadataKey:@"pageNumbers"
                        metadata:metadata
                    defaultValue:options.pageNumbersIncluded];

    NSString *layout = [[self stringForMetadataKey:@"layout" metadata:metadata] lowercaseString];
    if ([layout isEqualToString:@"classic"])
        options.layoutStyle = MPExportLayoutStyleClassic;
    else if ([layout isEqualToString:@"compact"])
        options.layoutStyle = MPExportLayoutStyleCompact;
    else if ([layout isEqualToString:@"modern"])
        options.layoutStyle = MPExportLayoutStyleModern;
}

+ (NSString *)titleForCompiledDocument:(MPCompiledDocument *)document
                              fallback:(NSString *)fallback
{
    NSString *title = [self stringForMetadataKey:@"title" metadata:document.metadata];
    if (title.length)
        return title;
    return fallback ?: @"";
}

+ (NSString *)stringForMetadataKey:(NSString *)key metadata:(NSDictionary *)metadata
{
    id value = metadata[key];
    if (!value || value == [NSNull null])
        return nil;
    if ([value isKindOfClass:[NSString class]])
        return value;
    return [value description];
}

+ (BOOL)boolForMetadataKey:(NSString *)key
                  metadata:(NSDictionary *)metadata
              defaultValue:(BOOL)defaultValue
{
    id value = metadata[key];
    if ([value respondsToSelector:@selector(boolValue)])
        return [value boolValue];
    return defaultValue;
}

@end
