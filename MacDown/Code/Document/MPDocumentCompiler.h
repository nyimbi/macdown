//
//  MPDocumentCompiler.h
//  MacDown
//

#import <Foundation/Foundation.h>

@class MPExportOptions;

@interface MPCompiledDocument : NSObject

@property (copy) NSString *markdown;
@property (copy) NSDictionary *metadata;
@property (copy) NSArray *includedFileURLs;
@property (copy) NSArray *warnings;

@end

@interface MPDocumentCompiler : NSObject

+ (MPCompiledDocument *)compileMarkdown:(NSString *)markdown
                                baseURL:(NSURL *)baseURL;
+ (void)applyMetadataFromCompiledDocument:(MPCompiledDocument *)document
                          toExportOptions:(MPExportOptions *)options;
+ (NSString *)titleForCompiledDocument:(MPCompiledDocument *)document
                              fallback:(NSString *)fallback;

@end
