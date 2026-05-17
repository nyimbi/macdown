//
//  MPDocumentCompilerTests.m
//  MacDown
//

#import <XCTest/XCTest.h>
#import "MPDocumentCompiler.h"
#import "MPExportOptions.h"

@interface MPDocumentCompilerTests : XCTestCase

@property (strong) NSURL *temporaryDirectoryURL;

@end

@implementation MPDocumentCompilerTests

- (void)setUp
{
    [super setUp];
    NSString *name = [[NSUUID UUID] UUIDString];
    self.temporaryDirectoryURL =
        [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]
                   isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:self.temporaryDirectoryURL
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:NULL];
}

- (void)tearDown
{
    [[NSFileManager defaultManager] removeItemAtURL:self.temporaryDirectoryURL
                                              error:NULL];
    [super tearDown];
}

- (void)testCompilesIncludesAndRootMetadata
{
    NSURL *chapterURL =
        [self.temporaryDirectoryURL URLByAppendingPathComponent:@"chapter.md"];
    [@"---\ntitle: Ignored Chapter Title\n---\n\n## Chapter\nBody."
        writeToURL:chapterURL atomically:YES encoding:NSUTF8StringEncoding
        error:NULL];

    NSString *markdown =
        @"---\n"
        @"title: Annual Plan\n"
        @"subtitle: FY27\n"
        @"author: Strategy\n"
        @"coverPage: true\n"
        @"pageNumbers: true\n"
        @"layout: compact\n"
        @"toc: true\n"
        @"---\n"
        @"# Overview\n"
        @"!include chapter.md\n";

    MPCompiledDocument *document =
        [MPDocumentCompiler compileMarkdown:markdown
                                    baseURL:self.temporaryDirectoryURL];

    XCTAssertEqualObjects(document.metadata[@"title"], @"Annual Plan");
    XCTAssertTrue([document.markdown hasPrefix:@"[TOC]"]);
    XCTAssertNotEqual([document.markdown rangeOfString:@"## Chapter"].location,
                      NSNotFound);
    XCTAssertEqual(document.includedFileURLs.count, 1U);
    XCTAssertEqual(document.warnings.count, 0U);

    MPExportOptions *options = [[MPExportOptions alloc] init];
    [MPDocumentCompiler applyMetadataFromCompiledDocument:document
                                          toExportOptions:options];
    XCTAssertEqualObjects(options.documentTitle, @"Annual Plan");
    XCTAssertEqualObjects(options.subtitleText, @"FY27");
    XCTAssertEqualObjects(options.authorName, @"Strategy");
    XCTAssertTrue(options.coverPageIncluded);
    XCTAssertTrue(options.pageNumbersIncluded);
    XCTAssertEqual(options.layoutStyle, MPExportLayoutStyleCompact);
}

- (void)testMissingIncludeProducesWarningMarkdown
{
    MPCompiledDocument *document =
        [MPDocumentCompiler compileMarkdown:@"Before\n!include missing.md\nAfter"
                                    baseURL:self.temporaryDirectoryURL];

    XCTAssertEqual(document.warnings.count, 1U);
    XCTAssertNotEqual([document.markdown rangeOfString:@"missing.md"].location,
                      NSNotFound);
    XCTAssertNotEqual([document.markdown rangeOfString:@"could not be read"].location,
                      NSNotFound);
}

- (void)testCircularIncludesAreSkipped
{
    NSURL *firstURL =
        [self.temporaryDirectoryURL URLByAppendingPathComponent:@"first.md"];
    NSURL *secondURL =
        [self.temporaryDirectoryURL URLByAppendingPathComponent:@"second.md"];
    [@"First\n!include second.md" writeToURL:firstURL atomically:YES
                                    encoding:NSUTF8StringEncoding error:NULL];
    [@"Second\n!include first.md" writeToURL:secondURL atomically:YES
                                     encoding:NSUTF8StringEncoding error:NULL];

    MPCompiledDocument *document =
        [MPDocumentCompiler compileMarkdown:@"!include first.md"
                                    baseURL:self.temporaryDirectoryURL];

    XCTAssertEqual(document.warnings.count, 1U);
    XCTAssertNotEqual([document.markdown rangeOfString:@"circular include"].location,
                      NSNotFound);
}

@end
