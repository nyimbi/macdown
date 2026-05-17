//
//  MPOfficeExporter.h
//  MacDown
//

#import <Foundation/Foundation.h>
@class MPExportOptions;

@interface MPOfficeExporter : NSObject

+ (BOOL)writeDOCXToURL:(NSURL *)url
              markdown:(NSString *)markdown
                 title:(NSString *)title
               options:(MPExportOptions *)options
                 error:(NSError **)outError;

+ (BOOL)writePPTXToURL:(NSURL *)url
              markdown:(NSString *)markdown
                 title:(NSString *)title
               options:(MPExportOptions *)options
                 error:(NSError **)outError;

@end
