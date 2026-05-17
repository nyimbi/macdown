//
//  MPOfficeExporter.m
//  MacDown
//

#import "MPOfficeExporter.h"
#import "MPExportOptions.h"

static NSString * const MPOfficeExporterErrorDomain = @"MPOfficeExporterErrorDomain";

typedef NS_ENUM(NSInteger, MPOfficeBlockType) {
    MPOfficeBlockTypeParagraph,
    MPOfficeBlockTypeHeading1,
    MPOfficeBlockTypeHeading2,
    MPOfficeBlockTypeBullet,
    MPOfficeBlockTypeCode,
};

@interface MPOfficeBlock : NSObject
@property MPOfficeBlockType type;
@property (copy) NSString *text;
@end

@implementation MPOfficeBlock
@end

@interface MPOfficeSlide : NSObject
@property (copy) NSString *title;
@property (copy) NSString *subtitle;
@property (copy) NSString *author;
@property BOOL coverSlide;
@property (strong) NSMutableArray *lines;
@end

@implementation MPOfficeSlide
- (instancetype)init
{
    self = [super init];
    if (self)
        _lines = [NSMutableArray array];
    return self;
}
@end

@implementation MPOfficeExporter

+ (BOOL)writeDOCXToURL:(NSURL *)url
              markdown:(NSString *)markdown
                 title:(NSString *)title
               options:(MPExportOptions *)options
                 error:(NSError **)outError
{
    NSString *root = [self temporaryExportDirectoryWithError:outError];
    if (!root)
        return NO;

    BOOL ok = [self buildDOCXAtPath:root
                           markdown:markdown
                              title:title
                            options:options
                              error:outError];
    if (ok)
        ok = [self zipDirectoryAtPath:root toURL:url error:outError];
    [[NSFileManager defaultManager] removeItemAtPath:root error:NULL];
    return ok;
}

+ (BOOL)writePPTXToURL:(NSURL *)url
              markdown:(NSString *)markdown
                 title:(NSString *)title
               options:(MPExportOptions *)options
                 error:(NSError **)outError
{
    NSString *root = [self temporaryExportDirectoryWithError:outError];
    if (!root)
        return NO;

    BOOL ok = [self buildPPTXAtPath:root
                           markdown:markdown
                              title:title
                            options:options
                              error:outError];
    if (ok)
        ok = [self zipDirectoryAtPath:root toURL:url error:outError];
    [[NSFileManager defaultManager] removeItemAtPath:root error:NULL];
    return ok;
}

#pragma mark - Packages

+ (BOOL)buildDOCXAtPath:(NSString *)root
               markdown:(NSString *)markdown
                  title:(NSString *)title
                options:(MPExportOptions *)options
                  error:(NSError **)outError
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray *directories = @[@"_rels", @"docProps", @"word", @"word/_rels", @"word/media"];
    for (NSString *directory in directories)
    {
        NSString *path = [root stringByAppendingPathComponent:directory];
        if (![manager createDirectoryAtPath:path withIntermediateDirectories:YES
                                 attributes:nil error:outError])
            return NO;
    }

    NSString *logoExtension = [self supportedImageExtensionForPath:options.logoPath];
    NSString *logoRelationship = @"";
    NSString *logoOverride = @"";
    if (logoExtension)
    {
        NSString *mediaName = [@"logo" stringByAppendingPathExtension:logoExtension];
        NSString *target = [@"word/media" stringByAppendingPathComponent:mediaName];
        if (![manager copyItemAtPath:options.logoPath
                              toPath:[root stringByAppendingPathComponent:target]
                               error:outError])
            return NO;
        logoRelationship = [NSString stringWithFormat:
            @"<Relationship Id=\"rIdLogo\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/%@\"/>",
            mediaName];
        logoOverride = [self contentTypeDefaultForImageExtension:logoExtension];
    }

    NSDictionary *files = @{
        @"[Content_Types].xml": [self docxContentTypesWithLogoDefault:logoOverride],
        @"_rels/.rels": [self rootRelationshipsForOfficeDocument:@"word/document.xml"],
        @"docProps/core.xml": [self corePropertiesWithTitle:title],
        @"docProps/app.xml": [self appPropertiesForApplication:@"MacDown"],
        @"word/document.xml": [self docxDocumentXMLForMarkdown:markdown
                                                         title:title
                                                       options:options],
        @"word/styles.xml": [self docxStylesXMLWithOptions:options],
        @"word/settings.xml": @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><w:settings xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"/>",
        @"word/_rels/document.xml.rels": [self docxDocumentRelationshipsWithLogo:logoRelationship],
        @"word/header1.xml": [self docxHeaderXMLWithOptions:options hasLogo:(logoExtension != nil)],
        @"word/footer1.xml": [self docxFooterXMLWithOptions:options],
    };
    return [self writeFiles:files root:root error:outError];
}

+ (BOOL)buildPPTXAtPath:(NSString *)root
               markdown:(NSString *)markdown
                  title:(NSString *)title
                options:(MPExportOptions *)options
                  error:(NSError **)outError
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray *directories = @[@"_rels", @"docProps", @"ppt", @"ppt/_rels",
                             @"ppt/slides", @"ppt/slides/_rels", @"ppt/media",
                             @"ppt/slideMasters", @"ppt/slideMasters/_rels",
                             @"ppt/slideLayouts", @"ppt/slideLayouts/_rels",
                             @"ppt/theme"];
    for (NSString *directory in directories)
    {
        NSString *path = [root stringByAppendingPathComponent:directory];
        if (![manager createDirectoryAtPath:path withIntermediateDirectories:YES
                                 attributes:nil error:outError])
            return NO;
    }

    NSString *logoExtension = [self supportedImageExtensionForPath:options.logoPath];
    if (logoExtension)
    {
        NSString *mediaName = [@"logo" stringByAppendingPathExtension:logoExtension];
        NSString *target = [@"ppt/media" stringByAppendingPathComponent:mediaName];
        if (![manager copyItemAtPath:options.logoPath
                              toPath:[root stringByAppendingPathComponent:target]
                               error:outError])
            return NO;
    }

    NSArray *slides = [self slidesFromMarkdown:markdown title:title options:options];
    NSMutableDictionary *files = [NSMutableDictionary dictionaryWithDictionary:@{
        @"[Content_Types].xml": [self pptxContentTypesForSlideCount:slides.count
                                                       logoExtension:logoExtension],
        @"_rels/.rels": [self rootRelationshipsForOfficeDocument:@"ppt/presentation.xml"],
        @"docProps/core.xml": [self corePropertiesWithTitle:title],
        @"docProps/app.xml": [self appPropertiesForApplication:@"MacDown"],
        @"ppt/presentation.xml": [self pptxPresentationXMLForSlideCount:slides.count],
        @"ppt/_rels/presentation.xml.rels": [self pptxPresentationRelationshipsForSlideCount:slides.count],
        @"ppt/slideMasters/slideMaster1.xml": [self pptxSlideMasterXML],
        @"ppt/slideMasters/_rels/slideMaster1.xml.rels": [self pptxSlideMasterRelationshipsXML],
        @"ppt/slideLayouts/slideLayout1.xml": [self pptxSlideLayoutXML],
        @"ppt/slideLayouts/_rels/slideLayout1.xml.rels": [self pptxSlideLayoutRelationshipsXML],
        @"ppt/theme/theme1.xml": [self pptxThemeXMLWithOptions:options],
    }];

    NSUInteger index = 1;
    for (MPOfficeSlide *slide in slides)
    {
        NSString *slidePath = [NSString stringWithFormat:@"ppt/slides/slide%lu.xml",
                               (unsigned long)index];
        files[slidePath] = [self pptxSlideXML:slide
                                      options:options
                                  slideNumber:index
                                      hasLogo:(logoExtension != nil)];
        files[[NSString stringWithFormat:@"ppt/slides/_rels/slide%lu.xml.rels",
               (unsigned long)index]] =
            [self pptxSlideRelationshipsXMLWithLogoExtension:logoExtension];
        index++;
    }

    return [self writeFiles:files root:root error:outError];
}

#pragma mark - DOCX XML

+ (NSString *)docxContentTypesWithLogoDefault:(NSString *)logoDefault
{
    return [NSString stringWithFormat:
        @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        @"<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">"
        @"<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>"
        @"<Default Extension=\"xml\" ContentType=\"application/xml\"/>%@"
        @"<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>"
        @"<Override PartName=\"/word/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml\"/>"
        @"<Override PartName=\"/word/settings.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml\"/>"
        @"<Override PartName=\"/word/header1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml\"/>"
        @"<Override PartName=\"/word/footer1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml\"/>"
        @"<Override PartName=\"/docProps/core.xml\" ContentType=\"application/vnd.openxmlformats-package.core-properties+xml\"/>"
        @"<Override PartName=\"/docProps/app.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.extended-properties+xml\"/>"
        @"</Types>", logoDefault ?: @""];
}

+ (NSString *)docxDocumentRelationshipsWithLogo:(NSString *)logoRelationship
{
    return [NSString stringWithFormat:
        @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        @"<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
        @"<Relationship Id=\"rIdHeader1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/header\" Target=\"header1.xml\"/>"
        @"<Relationship Id=\"rIdFooter1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer\" Target=\"footer1.xml\"/>%@"
        @"</Relationships>", logoRelationship ?: @""];
}

+ (NSString *)docxDocumentXMLForMarkdown:(NSString *)markdown
                                   title:(NSString *)title
                                 options:(MPExportOptions *)options
{
    NSMutableString *body = [NSMutableString string];
    if (options.coverPageIncluded)
        [body appendString:[self docxCoverPageXMLWithTitle:title options:options]];
    for (MPOfficeBlock *block in [self blocksFromMarkdown:markdown])
        [body appendString:[self docxParagraphForBlock:block options:options]];

    return [NSString stringWithFormat:
        @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        @"<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" "
        @"xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">"
        @"<w:body>%@"
        @"<w:sectPr><w:headerReference w:type=\"default\" r:id=\"rIdHeader1\"/>"
        @"<w:footerReference w:type=\"default\" r:id=\"rIdFooter1\"/>"
        @"<w:pgSz w:w=\"12240\" w:h=\"15840\"/>"
        @"<w:pgMar w:top=\"1440\" w:right=\"1440\" w:bottom=\"1440\" w:left=\"1440\" w:header=\"720\" w:footer=\"720\" w:gutter=\"0\"/>"
        @"</w:sectPr></w:body></w:document>", body];
}

+ (NSString *)docxCoverPageXMLWithTitle:(NSString *)title
                                options:(MPExportOptions *)options
{
    NSMutableString *cover = [NSMutableString string];
    NSString *coverTitle = [self effectiveTitleForTitle:title options:options];
    [cover appendFormat:
     @"<w:p><w:pPr><w:jc w:val=\"center\"/><w:spacing w:before=\"2600\" w:after=\"300\"/></w:pPr>"
     @"<w:r><w:rPr><w:b/><w:color w:val=\"111827\"/><w:sz w:val=\"68\"/></w:rPr><w:t>%@</w:t></w:r></w:p>",
     [self xmlEscape:coverTitle]];
    if ([self stringHasContent:options.subtitleText])
    {
        [cover appendFormat:
         @"<w:p><w:pPr><w:jc w:val=\"center\"/><w:spacing w:after=\"520\"/></w:pPr>"
         @"<w:r><w:rPr><w:color w:val=\"4B5563\"/><w:sz w:val=\"30\"/></w:rPr><w:t>%@</w:t></w:r></w:p>",
         [self xmlEscape:options.subtitleText]];
    }
    if ([self stringHasContent:options.authorName])
    {
        [cover appendFormat:
         @"<w:p><w:pPr><w:jc w:val=\"center\"/><w:spacing w:before=\"600\" w:after=\"1000\"/></w:pPr>"
         @"<w:r><w:rPr><w:caps/><w:color w:val=\"6B7280\"/><w:sz w:val=\"20\"/></w:rPr><w:t>%@</w:t></w:r></w:p>",
         [self xmlEscape:options.authorName]];
    }
    [cover appendFormat:
     @"<w:p><w:pPr><w:jc w:val=\"center\"/><w:spacing w:before=\"400\" w:after=\"900\"/></w:pPr>"
     @"<w:r><w:rPr><w:color w:val=\"%@\"/><w:sz w:val=\"18\"/></w:rPr><w:t>━━━</w:t></w:r></w:p>",
     [self colorHexWithoutHash:options.brandColor]];
    return cover;
}

+ (NSString *)docxParagraphForBlock:(MPOfficeBlock *)block
                            options:(MPExportOptions *)options
{
    NSString *style = @"Normal";
    NSString *runFormatting = @"<w:sz w:val=\"22\"/>";
    NSString *paragraphFormatting = @"<w:spacing w:after=\"160\" w:line=\"320\" w:lineRule=\"auto\"/>";
    if (block.type == MPOfficeBlockTypeHeading1)
    {
        style = @"Heading1";
        runFormatting = [NSString stringWithFormat:
                         @"<w:b/><w:color w:val=\"%@\"/><w:sz w:val=\"38\"/>",
                         [self colorHexWithoutHash:options.brandColor]];
        paragraphFormatting = @"<w:spacing w:before=\"420\" w:after=\"160\"/><w:pBdr><w:bottom w:val=\"single\" w:sz=\"8\" w:space=\"6\" w:color=\"D8DEE9\"/></w:pBdr>";
    }
    else if (block.type == MPOfficeBlockTypeHeading2)
    {
        style = @"Heading2";
        runFormatting = @"<w:b/><w:color w:val=\"111827\"/><w:sz w:val=\"30\"/>";
        paragraphFormatting = @"<w:spacing w:before=\"300\" w:after=\"120\"/>";
    }
    else if (block.type == MPOfficeBlockTypeCode)
    {
        style = @"Code";
        runFormatting = @"<w:rFonts w:ascii=\"Menlo\" w:hAnsi=\"Menlo\"/><w:sz w:val=\"20\"/><w:color w:val=\"111827\"/>";
        paragraphFormatting = @"<w:spacing w:before=\"120\" w:after=\"160\"/><w:shd w:fill=\"F3F4F6\"/>";
    }

    NSString *prefix = block.type == MPOfficeBlockTypeBullet ? @"- " : @"";
    return [NSString stringWithFormat:
        @"<w:p><w:pPr><w:pStyle w:val=\"%@\"/>%@</w:pPr><w:r><w:rPr>%@</w:rPr><w:t xml:space=\"preserve\">%@%@</w:t></w:r></w:p>",
        style, paragraphFormatting, runFormatting, prefix, [self xmlEscape:block.text]];
}

+ (NSString *)docxHeaderXMLWithOptions:(MPExportOptions *)options
                               hasLogo:(BOOL)hasLogo
{
    NSMutableString *content = [NSMutableString stringWithFormat:
        @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        @"<w:hdr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" "
        @"xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" "
        @"xmlns:v=\"urn:schemas-microsoft-com:vml\" "
        @"xmlns:wp=\"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing\" "
        @"xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" "
        @"xmlns:pic=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">"];
    if ([self stringHasContent:options.watermarkText])
        [content appendString:[self docxWatermarkForText:options.watermarkText]];
    if ([self stringHasContent:options.headerText] || hasLogo)
    {
        [content appendString:@"<w:p>"];
        if ([self stringHasContent:options.headerText])
            [content appendFormat:@"<w:r><w:t>%@</w:t></w:r>",
             [self xmlEscape:options.headerText]];
        if (hasLogo)
            [content appendString:[self docxLogoRunXML]];
        [content appendString:@"</w:p>"];
    }
    [content appendString:@"</w:hdr>"];
    return content;
}

+ (NSString *)docxFooterXMLWithOptions:(MPExportOptions *)options
{
    NSMutableString *footer = [NSMutableString stringWithString:
        @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        @"<w:ftr xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">"
        @"<w:p>"];
    if ([self stringHasContent:options.footerText])
        [footer appendFormat:@"<w:r><w:t>%@</w:t></w:r>",
         [self xmlEscape:options.footerText]];
    if (options.pageNumbersIncluded)
        [footer appendString:@"<w:r><w:tab/></w:r><w:r><w:t>Page </w:t></w:r><w:fldSimple w:instr=\" PAGE \"><w:r><w:t>1</w:t></w:r></w:fldSimple>"];
    [footer appendString:@"</w:p></w:ftr>"];
    return footer;
}

+ (NSString *)docxLogoRunXML
{
    return
        @"<w:r><w:tab/></w:r><w:r><w:drawing><wp:inline distT=\"0\" distB=\"0\" distL=\"0\" distR=\"0\">"
        @"<wp:extent cx=\"1371600\" cy=\"457200\"/><wp:docPr id=\"1\" name=\"Logo\"/>"
        @"<a:graphic><a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">"
        @"<pic:pic><pic:nvPicPr><pic:cNvPr id=\"1\" name=\"Logo\"/><pic:cNvPicPr/></pic:nvPicPr>"
        @"<pic:blipFill><a:blip r:embed=\"rIdLogo\"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>"
        @"<pic:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"1371600\" cy=\"457200\"/></a:xfrm>"
        @"<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>"
        @"</a:graphicData></a:graphic></wp:inline></w:drawing></w:r>";
}

+ (NSString *)docxWatermarkForText:(NSString *)text
{
    return [NSString stringWithFormat:
        @"<w:p><w:r><w:pict><v:shape id=\"MacDownWatermark\" type=\"#_x0000_t136\" "
        @"style=\"position:absolute;width:468pt;height:117pt;rotation:315;z-index:-251654144;"
        @"mso-position-horizontal:center;mso-position-vertical:center\" fillcolor=\"#d8d8d8\" stroked=\"f\">"
        @"<v:textpath style=\"font-family:Helvetica;font-size:1pt\" string=\"%@\"/>"
        @"</v:shape></w:pict></w:r></w:p>", [self xmlEscape:text]];
}

+ (NSString *)docxStylesXMLWithOptions:(MPExportOptions *)options
{
    NSString *brand = [self colorHexWithoutHash:options.brandColor];
    return [NSString stringWithFormat:
        @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        @"<w:styles xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">"
        @"<w:style w:type=\"paragraph\" w:styleId=\"CoverTitle\"><w:name w:val=\"Cover Title\"/><w:rPr><w:b/><w:color w:val=\"111827\"/><w:sz w:val=\"64\"/></w:rPr></w:style>"
        @"<w:style w:type=\"paragraph\" w:styleId=\"CoverSubtitle\"><w:name w:val=\"Cover Subtitle\"/><w:rPr><w:color w:val=\"4B5563\"/><w:sz w:val=\"30\"/></w:rPr></w:style>"
        @"<w:style w:type=\"paragraph\" w:styleId=\"CoverMeta\"><w:name w:val=\"Cover Meta\"/><w:rPr><w:caps/><w:color w:val=\"6B7280\"/><w:sz w:val=\"20\"/></w:rPr></w:style>"
        @"<w:style w:type=\"paragraph\" w:default=\"1\" w:styleId=\"Normal\"><w:name w:val=\"Normal\"/><w:rPr><w:sz w:val=\"22\"/></w:rPr><w:pPr><w:spacing w:after=\"160\" w:line=\"320\" w:lineRule=\"auto\"/></w:pPr></w:style>"
        @"<w:style w:type=\"paragraph\" w:styleId=\"Heading1\"><w:name w:val=\"heading 1\"/><w:basedOn w:val=\"Normal\"/><w:pPr><w:spacing w:before=\"420\" w:after=\"160\"/></w:pPr><w:rPr><w:b/><w:color w:val=\"%@\"/><w:sz w:val=\"38\"/></w:rPr></w:style>"
        @"<w:style w:type=\"paragraph\" w:styleId=\"Heading2\"><w:name w:val=\"heading 2\"/><w:basedOn w:val=\"Normal\"/><w:pPr><w:spacing w:before=\"300\" w:after=\"120\"/></w:pPr><w:rPr><w:b/><w:color w:val=\"111827\"/><w:sz w:val=\"28\"/></w:rPr></w:style>"
        @"<w:style w:type=\"paragraph\" w:styleId=\"Code\"><w:name w:val=\"Code\"/><w:basedOn w:val=\"Normal\"/><w:rPr><w:rFonts w:ascii=\"Menlo\" w:hAnsi=\"Menlo\"/><w:sz w:val=\"20\"/></w:rPr></w:style>"
        @"</w:styles>", brand];
}

#pragma mark - PPTX XML

+ (NSString *)pptxContentTypesForSlideCount:(NSUInteger)count
                              logoExtension:(NSString *)logoExtension
{
    NSMutableString *overrides = [NSMutableString string];
    for (NSUInteger i = 1; i <= count; i++)
    {
        [overrides appendFormat:
         @"<Override PartName=\"/ppt/slides/slide%lu.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slide+xml\"/>",
         (unsigned long)i];
    }
    return [NSString stringWithFormat:
        @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        @"<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">"
        @"<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>"
        @"<Default Extension=\"xml\" ContentType=\"application/xml\"/>%@"
        @"<Override PartName=\"/ppt/presentation.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml\"/>"
        @"<Override PartName=\"/ppt/slideMasters/slideMaster1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml\"/>"
        @"<Override PartName=\"/ppt/slideLayouts/slideLayout1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml\"/>"
        @"<Override PartName=\"/ppt/theme/theme1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.theme+xml\"/>"
        @"<Override PartName=\"/docProps/core.xml\" ContentType=\"application/vnd.openxmlformats-package.core-properties+xml\"/>"
        @"<Override PartName=\"/docProps/app.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.extended-properties+xml\"/>%@"
        @"</Types>",
        [self contentTypeDefaultForImageExtension:logoExtension], overrides];
}

+ (NSString *)pptxPresentationXMLForSlideCount:(NSUInteger)count
{
    NSMutableString *ids = [NSMutableString string];
    for (NSUInteger i = 1; i <= count; i++)
        [ids appendFormat:@"<p:sldId id=\"%lu\" r:id=\"rId%lu\"/>",
         (unsigned long)(255 + i), (unsigned long)i];
    return [NSString stringWithFormat:
        @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        @"<p:presentation xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" "
        @"xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" "
        @"xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">"
        @"<p:sldMasterIdLst><p:sldMasterId id=\"2147483648\" r:id=\"rIdMaster1\"/></p:sldMasterIdLst>"
        @"<p:sldIdLst>%@</p:sldIdLst>"
        @"<p:sldSz cx=\"12192000\" cy=\"6858000\" type=\"wide\"/>"
        @"<p:notesSz cx=\"6858000\" cy=\"9144000\"/>"
        @"<p:defaultTextStyle><a:defPPr><a:defRPr lang=\"en-US\"/></a:defPPr></p:defaultTextStyle>"
        @"</p:presentation>", ids];
}

+ (NSString *)pptxPresentationRelationshipsForSlideCount:(NSUInteger)count
{
    NSMutableString *rels = [NSMutableString stringWithString:
        @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        @"<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"];
    for (NSUInteger i = 1; i <= count; i++)
    {
        [rels appendFormat:
         @"<Relationship Id=\"rId%lu\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide\" Target=\"slides/slide%lu.xml\"/>",
         (unsigned long)i, (unsigned long)i];
    }
    [rels appendString:
     @"<Relationship Id=\"rIdMaster1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster\" Target=\"slideMasters/slideMaster1.xml\"/>"];
    [rels appendString:@"</Relationships>"];
    return rels;
}

+ (NSString *)pptxSlideRelationshipsXMLWithLogoExtension:(NSString *)logoExtension
{
    NSMutableString *rels = [NSMutableString stringWithString:
        @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        @"<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
        @"<Relationship Id=\"rIdLayout\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout\" Target=\"../slideLayouts/slideLayout1.xml\"/>"];
    if (logoExtension)
    {
        [rels appendFormat:
         @"<Relationship Id=\"rIdLogo\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"../media/logo.%@\"/>",
         logoExtension];
    }
    [rels appendString:@"</Relationships>"];
    return rels;
}

+ (NSString *)pptxSlideMasterXML
{
    return
        @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        @"<p:sldMaster xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" "
        @"xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" "
        @"xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">"
        @"<p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>"
        @"<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>"
        @"</p:spTree></p:cSld>"
        @"<p:clrMap bg1=\"lt1\" tx1=\"dk1\" bg2=\"lt2\" tx2=\"dk2\" accent1=\"accent1\" accent2=\"accent2\" accent3=\"accent3\" accent4=\"accent4\" accent5=\"accent5\" accent6=\"accent6\" hlink=\"hlink\" folHlink=\"folHlink\"/>"
        @"<p:sldLayoutIdLst><p:sldLayoutId id=\"1\" r:id=\"rIdLayout1\"/></p:sldLayoutIdLst>"
        @"<p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles></p:sldMaster>";
}

+ (NSString *)pptxSlideMasterRelationshipsXML
{
    return
        @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        @"<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
        @"<Relationship Id=\"rIdLayout1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout\" Target=\"../slideLayouts/slideLayout1.xml\"/>"
        @"<Relationship Id=\"rIdTheme1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme\" Target=\"../theme/theme1.xml\"/>"
        @"</Relationships>";
}

+ (NSString *)pptxSlideLayoutXML
{
    return
        @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        @"<p:sldLayout xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" "
        @"xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" "
        @"xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\" type=\"blank\" preserve=\"1\">"
        @"<p:cSld name=\"MacDown Blank\"><p:spTree><p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>"
        @"<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>"
        @"</p:spTree></p:cSld></p:sldLayout>";
}

+ (NSString *)pptxSlideLayoutRelationshipsXML
{
    return
        @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        @"<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
        @"<Relationship Id=\"rIdMaster\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster\" Target=\"../slideMasters/slideMaster1.xml\"/>"
        @"</Relationships>";
}

+ (NSString *)pptxThemeXMLWithOptions:(MPExportOptions *)options
{
    NSString *brand = [self colorHexWithoutHash:options.brandColor];
    return [NSString stringWithFormat:
        @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        @"<a:theme xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" name=\"MacDown Export\">"
        @"<a:themeElements><a:clrScheme name=\"MacDown\">"
        @"<a:dk1><a:srgbClr val=\"111827\"/></a:dk1><a:lt1><a:srgbClr val=\"FFFFFF\"/></a:lt1>"
        @"<a:dk2><a:srgbClr val=\"374151\"/></a:dk2><a:lt2><a:srgbClr val=\"F7F9FC\"/></a:lt2>"
        @"<a:accent1><a:srgbClr val=\"%@\"/></a:accent1><a:accent2><a:srgbClr val=\"6B7280\"/></a:accent2>"
        @"<a:accent3><a:srgbClr val=\"D8DEE9\"/></a:accent3><a:accent4><a:srgbClr val=\"93C5FD\"/></a:accent4>"
        @"<a:accent5><a:srgbClr val=\"F59E0B\"/></a:accent5><a:accent6><a:srgbClr val=\"10B981\"/></a:accent6>"
        @"<a:hlink><a:srgbClr val=\"%@\"/></a:hlink><a:folHlink><a:srgbClr val=\"7C3AED\"/></a:folHlink>"
        @"</a:clrScheme><a:fontScheme name=\"MacDown\"><a:majorFont><a:latin typeface=\"Aptos Display\"/></a:majorFont><a:minorFont><a:latin typeface=\"Aptos\"/></a:minorFont></a:fontScheme>"
        @"<a:fmtScheme name=\"MacDown\"><a:fillStyleLst><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:fillStyleLst><a:lnStyleLst><a:ln w=\"6350\"><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:ln></a:lnStyleLst><a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst><a:bgFillStyleLst><a:solidFill><a:schemeClr val=\"phClr\"/></a:solidFill></a:bgFillStyleLst></a:fmtScheme>"
        @"</a:themeElements></a:theme>", brand, brand];
}

+ (NSString *)pptxSlideXML:(MPOfficeSlide *)slide
                   options:(MPExportOptions *)options
               slideNumber:(NSUInteger)slideNumber
                   hasLogo:(BOOL)hasLogo
{
    if (slide.coverSlide)
        return [self pptxCoverSlideXML:slide
                               options:options
                           slideNumber:slideNumber
                               hasLogo:hasLogo];

    NSMutableString *shapes = [NSMutableString string];
    [shapes appendFormat:@"%@%@",
     [self pptxTextBoxWithId:2 text:slide.title x:685800 y:457200
                          cx:10515600 cy:800000 fontSize:3600 bold:YES],
     [self pptxBodyLines:slide.lines]];
    if ([self stringHasContent:options.watermarkText])
        [shapes appendString:[self pptxWatermark:options.watermarkText]];
    if ([self stringHasContent:options.footerText])
        [shapes appendString:[self pptxTextBoxWithId:70 text:options.footerText
                                                   x:685800 y:6400000
                                                  cx:6000000 cy:300000
                                            fontSize:1200 bold:NO]];
    if (options.pageNumbersIncluded)
    {
        NSString *page = [NSString stringWithFormat:@"%lu", (unsigned long)slideNumber];
        [shapes appendString:[self pptxTextBoxWithId:71 text:page
                                                   x:11200000 y:6400000
                                                  cx:450000 cy:300000
                                            fontSize:1200 bold:NO]];
    }
    if (hasLogo)
        [shapes appendString:[self pptxLogoPicture]];

    return [NSString stringWithFormat:
        @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        @"<p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" "
        @"xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" "
        @"xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">"
        @"<p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>"
        @"<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>"
        @"<p:sp><p:nvSpPr><p:cNvPr id=\"90\" name=\"Brand\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>"
        @"<p:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"12192000\" cy=\"110000\"/></a:xfrm>"
        @"<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val=\"%@\"/></a:solidFill><a:ln><a:noFill/></a:ln></p:spPr><p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody></p:sp>"
        @"%@</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>",
        [self colorHexWithoutHash:options.brandColor], shapes];
}

+ (NSString *)pptxCoverSlideXML:(MPOfficeSlide *)slide
                         options:(MPExportOptions *)options
                     slideNumber:(NSUInteger)slideNumber
                         hasLogo:(BOOL)hasLogo
{
    NSMutableString *shapes = [NSMutableString string];
    [shapes appendString:[self pptxFullBleedBackgroundWithColor:
                          [self paleColorForBrand:options.brandColor]]];
    [shapes appendString:[self pptxAccentBlockWithOptions:options]];
    [shapes appendString:[self pptxTextBoxWithId:2 text:slide.title
                                               x:850000 y:2100000
                                              cx:8800000 cy:900000
                                        fontSize:4600 bold:YES]];
    if ([self stringHasContent:slide.subtitle])
    {
        [shapes appendString:[self pptxTextBoxWithId:3 text:slide.subtitle
                                                   x:850000 y:3100000
                                                  cx:7600000 cy:520000
                                            fontSize:2100 bold:NO]];
    }
    if ([self stringHasContent:slide.author])
    {
        [shapes appendString:[self pptxTextBoxWithId:4 text:slide.author
                                                   x:850000 y:5600000
                                                  cx:5600000 cy:300000
                                            fontSize:1300 bold:NO]];
    }
    if (hasLogo)
        [shapes appendString:[self pptxLogoPicture]];

    return [self pptxSlideWithShapes:shapes options:options];
}

+ (NSString *)pptxBodyLines:(NSArray *)lines
{
    NSMutableString *body = [NSMutableString string];
    NSUInteger shapeId = 10;
    CGFloat y = 1500000;
    for (NSString *line in lines)
    {
        [body appendString:[self pptxTextBoxWithId:shapeId++ text:line
                                                 x:900000 y:y
                                                cx:10300000 cy:360000
                                          fontSize:1800 bold:NO]];
        y += 420000;
    }
    return body;
}

+ (NSString *)pptxTextBoxWithId:(NSUInteger)shapeId
                            text:(NSString *)text
                               x:(CGFloat)x
                               y:(CGFloat)y
                              cx:(CGFloat)cx
                              cy:(CGFloat)cy
                        fontSize:(NSUInteger)fontSize
                            bold:(BOOL)bold
{
    return [NSString stringWithFormat:
        @"<p:sp><p:nvSpPr><p:cNvPr id=\"%lu\" name=\"Text %lu\"/><p:cNvSpPr txBox=\"1\"/><p:nvPr/></p:nvSpPr>"
        @"<p:spPr><a:xfrm><a:off x=\"%.0f\" y=\"%.0f\"/><a:ext cx=\"%.0f\" cy=\"%.0f\"/></a:xfrm>"
        @"<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom><a:noFill/><a:ln><a:noFill/></a:ln></p:spPr>"
        @"<p:txBody><a:bodyPr wrap=\"square\"/><a:lstStyle/><a:p><a:r><a:rPr lang=\"en-US\" sz=\"%lu\"%@/>"
        @"<a:t>%@</a:t></a:r></a:p></p:txBody></p:sp>",
        (unsigned long)shapeId, (unsigned long)shapeId, x, y, cx, cy,
        (unsigned long)fontSize, bold ? @" b=\"1\"" : @"", [self xmlEscape:text]];
}

+ (NSString *)pptxWatermark:(NSString *)text
{
    return [NSString stringWithFormat:
        @"<p:sp><p:nvSpPr><p:cNvPr id=\"80\" name=\"Watermark\"/><p:cNvSpPr txBox=\"1\"/><p:nvPr/></p:nvSpPr>"
        @"<p:spPr><a:xfrm rot=\"-1800000\"><a:off x=\"1700000\" y=\"2400000\"/><a:ext cx=\"8800000\" cy=\"1000000\"/></a:xfrm>"
        @"<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom><a:noFill/><a:ln><a:noFill/></a:ln></p:spPr>"
        @"<p:txBody><a:bodyPr/><a:lstStyle/><a:p><a:r><a:rPr lang=\"en-US\" sz=\"5200\" b=\"1\">"
        @"<a:solidFill><a:srgbClr val=\"BBBBBB\"><a:alpha val=\"22000\"/></a:srgbClr></a:solidFill></a:rPr>"
        @"<a:t>%@</a:t></a:r></a:p></p:txBody></p:sp>", [self xmlEscape:text]];
}

+ (NSString *)pptxLogoPicture
{
    return
        @"<p:pic><p:nvPicPr><p:cNvPr id=\"81\" name=\"Logo\"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>"
        @"<p:blipFill><a:blip r:embed=\"rIdLogo\"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>"
        @"<p:spPr><a:xfrm><a:off x=\"10400000\" y=\"250000\"/><a:ext cx=\"1200000\" cy=\"500000\"/></a:xfrm>"
        @"<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom></p:spPr></p:pic>";
}

+ (NSString *)pptxFullBleedBackgroundWithColor:(NSString *)color
{
    return [NSString stringWithFormat:
        @"<p:sp><p:nvSpPr><p:cNvPr id=\"91\" name=\"Background\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>"
        @"<p:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"12192000\" cy=\"6858000\"/></a:xfrm>"
        @"<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val=\"%@\"/></a:solidFill><a:ln><a:noFill/></a:ln></p:spPr><p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody></p:sp>",
        color];
}

+ (NSString *)pptxAccentBlockWithOptions:(MPExportOptions *)options
{
    return [NSString stringWithFormat:
        @"<p:sp><p:nvSpPr><p:cNvPr id=\"92\" name=\"Accent\"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>"
        @"<p:spPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"450000\" cy=\"6858000\"/></a:xfrm>"
        @"<a:prstGeom prst=\"rect\"><a:avLst/></a:prstGeom><a:solidFill><a:srgbClr val=\"%@\"/></a:solidFill><a:ln><a:noFill/></a:ln></p:spPr><p:txBody><a:bodyPr/><a:lstStyle/><a:p/></p:txBody></p:sp>",
        [self colorHexWithoutHash:options.brandColor]];
}

+ (NSString *)pptxSlideWithShapes:(NSString *)shapes options:(MPExportOptions *)options
{
    return [NSString stringWithFormat:
        @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        @"<p:sld xmlns:a=\"http://schemas.openxmlformats.org/drawingml/2006/main\" "
        @"xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" "
        @"xmlns:p=\"http://schemas.openxmlformats.org/presentationml/2006/main\">"
        @"<p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id=\"1\" name=\"\"/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>"
        @"<p:grpSpPr><a:xfrm><a:off x=\"0\" y=\"0\"/><a:ext cx=\"0\" cy=\"0\"/><a:chOff x=\"0\" y=\"0\"/><a:chExt cx=\"0\" cy=\"0\"/></a:xfrm></p:grpSpPr>"
        @"%@</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>",
        shapes];
}

#pragma mark - Parsing

+ (NSArray *)blocksFromMarkdown:(NSString *)markdown
{
    NSMutableArray *blocks = [NSMutableArray array];
    NSArray *lines = [markdown componentsSeparatedByCharactersInSet:
                      [NSCharacterSet newlineCharacterSet]];
    BOOL inCode = NO;
    NSMutableArray *paragraph = [NSMutableArray array];
    NSMutableArray *code = [NSMutableArray array];

    void (^flushParagraph)(void) = ^{
        if (!paragraph.count)
            return;
        [blocks addObject:[self blockWithType:MPOfficeBlockTypeParagraph
                                         text:[paragraph componentsJoinedByString:@" "]]];
        [paragraph removeAllObjects];
    };

    for (NSString *line in lines)
    {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:
                             [NSCharacterSet whitespaceCharacterSet]];
        if ([trimmed hasPrefix:@"```"])
        {
            if (inCode)
            {
                [blocks addObject:[self blockWithType:MPOfficeBlockTypeCode
                                                 text:[code componentsJoinedByString:@"\n"]]];
                [code removeAllObjects];
            }
            else
            {
                flushParagraph();
            }
            inCode = !inCode;
            continue;
        }
        if (inCode)
        {
            [code addObject:line];
            continue;
        }
        if (!trimmed.length)
        {
            flushParagraph();
            continue;
        }
        if ([trimmed hasPrefix:@"# "])
        {
            flushParagraph();
            [blocks addObject:[self blockWithType:MPOfficeBlockTypeHeading1
                                             text:[trimmed substringFromIndex:2]]];
        }
        else if ([trimmed hasPrefix:@"## "])
        {
            flushParagraph();
            [blocks addObject:[self blockWithType:MPOfficeBlockTypeHeading2
                                             text:[trimmed substringFromIndex:3]]];
        }
        else if ([trimmed hasPrefix:@"- "] || [trimmed hasPrefix:@"* "])
        {
            flushParagraph();
            [blocks addObject:[self blockWithType:MPOfficeBlockTypeBullet
                                             text:[trimmed substringFromIndex:2]]];
        }
        else
        {
            [paragraph addObject:trimmed];
        }
    }
    flushParagraph();
    if (code.count)
        [blocks addObject:[self blockWithType:MPOfficeBlockTypeCode
                                         text:[code componentsJoinedByString:@"\n"]]];
    return blocks;
}

+ (NSArray *)slidesFromMarkdown:(NSString *)markdown
                           title:(NSString *)title
                         options:(MPExportOptions *)options
{
    NSMutableArray *slides = [NSMutableArray array];
    MPOfficeSlide *current = [[MPOfficeSlide alloc] init];
    current.title = [self effectiveTitleForTitle:title options:options];
    if (options.coverPageIncluded)
    {
        MPOfficeSlide *cover = [[MPOfficeSlide alloc] init];
        cover.coverSlide = YES;
        cover.title = [self effectiveTitleForTitle:title options:options];
        cover.subtitle = options.subtitleText;
        cover.author = options.authorName;
        [slides addObject:cover];
    }

    for (MPOfficeBlock *block in [self blocksFromMarkdown:markdown])
    {
        if (block.type == MPOfficeBlockTypeHeading1 ||
            block.type == MPOfficeBlockTypeHeading2)
        {
            if (!current.lines.count &&
                (!slides.count || (slides.count == 1 && options.coverPageIncluded)))
            {
                current.title = block.text;
                continue;
            }
            if (current.lines.count)
                [slides addObject:current];
            current = [[MPOfficeSlide alloc] init];
            current.title = block.text;
        }
        else
        {
            [current.lines addObject:block.text];
            if (current.lines.count >= 10)
            {
                [slides addObject:current];
                current = [[MPOfficeSlide alloc] init];
                current.title = [self effectiveTitleForTitle:title options:options];
            }
        }
    }
    if (current.lines.count || !slides.count)
        [slides addObject:current];
    return slides;
}

+ (MPOfficeBlock *)blockWithType:(MPOfficeBlockType)type text:(NSString *)text
{
    MPOfficeBlock *block = [[MPOfficeBlock alloc] init];
    block.type = type;
    block.text = [self stripMarkdownInline:text ?: @""];
    return block;
}

+ (NSString *)stripMarkdownInline:(NSString *)text
{
    NSMutableString *result = [text mutableCopy];
    NSArray *markers = @[@"**", @"__", @"`", @"*", @"_"];
    for (NSString *marker in markers)
        [result replaceOccurrencesOfString:marker withString:@""
                                    options:0 range:NSMakeRange(0, result.length)];
    return result;
}

#pragma mark - Shared XML and Files

+ (NSString *)rootRelationshipsForOfficeDocument:(NSString *)target
{
    return [NSString stringWithFormat:
        @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        @"<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
        @"<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"%@\"/>"
        @"<Relationship Id=\"rId2\" Type=\"http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties\" Target=\"docProps/core.xml\"/>"
        @"<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties\" Target=\"docProps/app.xml\"/>"
        @"</Relationships>", target];
}

+ (NSString *)corePropertiesWithTitle:(NSString *)title
{
    return [NSString stringWithFormat:
        @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        @"<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\" "
        @"xmlns:dc=\"http://purl.org/dc/elements/1.1/\" "
        @"xmlns:dcterms=\"http://purl.org/dc/terms/\" "
        @"xmlns:dcmitype=\"http://purl.org/dc/dcmitype/\" "
        @"xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">"
        @"<dc:title>%@</dc:title><dc:creator>MacDown</dc:creator>"
        @"<cp:lastModifiedBy>MacDown</cp:lastModifiedBy></cp:coreProperties>",
        [self xmlEscape:title ?: @""]];
}

+ (NSString *)appPropertiesForApplication:(NSString *)application
{
    return [NSString stringWithFormat:
        @"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        @"<Properties xmlns=\"http://schemas.openxmlformats.org/officeDocument/2006/extended-properties\" "
        @"xmlns:vt=\"http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes\">"
        @"<Application>%@</Application></Properties>", [self xmlEscape:application]];
}

+ (NSString *)xmlEscape:(NSString *)value
{
    NSMutableString *escaped = [NSMutableString stringWithString:value ?: @""];
    [escaped replaceOccurrencesOfString:@"&" withString:@"&amp;"
                                options:0 range:NSMakeRange(0, escaped.length)];
    [escaped replaceOccurrencesOfString:@"<" withString:@"&lt;"
                                options:0 range:NSMakeRange(0, escaped.length)];
    [escaped replaceOccurrencesOfString:@">" withString:@"&gt;"
                                options:0 range:NSMakeRange(0, escaped.length)];
    [escaped replaceOccurrencesOfString:@"\"" withString:@"&quot;"
                                options:0 range:NSMakeRange(0, escaped.length)];
    return escaped;
}

+ (NSString *)colorHexWithoutHash:(NSString *)color
{
    NSString *candidate = [color stringByTrimmingCharactersInSet:
                           [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([candidate hasPrefix:@"#"])
        candidate = [candidate substringFromIndex:1];
    if (candidate.length == 6)
        return candidate;
    return @"3A6EA5";
}

+ (BOOL)stringHasContent:(NSString *)value
{
    return [value stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0;
}

+ (NSString *)effectiveTitleForTitle:(NSString *)title options:(MPExportOptions *)options
{
    if ([self stringHasContent:options.documentTitle])
        return options.documentTitle;
    if ([self stringHasContent:title])
        return title;
    return @"MacDown Export";
}

+ (NSString *)paleColorForBrand:(NSString *)brand
{
    NSString *color = [self colorHexWithoutHash:brand];
    if ([color isEqualToString:@"3A6EA5"])
        return @"F1F6FB";
    return @"F7F9FC";
}

+ (NSString *)supportedImageExtensionForPath:(NSString *)path
{
    if (![self stringHasContent:path])
        return nil;
    NSString *extension = path.pathExtension.lowercaseString;
    if ([extension isEqualToString:@"jpg"])
        return @"jpeg";
    if ([extension isEqualToString:@"jpeg"] || [extension isEqualToString:@"png"])
        return extension;
    return nil;
}

+ (NSString *)contentTypeDefaultForImageExtension:(NSString *)extension
{
    if (!extension)
        return @"";
    NSString *type = [extension isEqualToString:@"png"] ? @"image/png" : @"image/jpeg";
    return [NSString stringWithFormat:
            @"<Default Extension=\"%@\" ContentType=\"%@\"/>", extension, type];
}

+ (BOOL)writeFiles:(NSDictionary *)files root:(NSString *)root error:(NSError **)outError
{
    for (NSString *relativePath in files)
    {
        NSString *path = [root stringByAppendingPathComponent:relativePath];
        NSString *content = files[relativePath];
        if (![content writeToFile:path atomically:NO encoding:NSUTF8StringEncoding
                            error:outError])
            return NO;
    }
    return YES;
}

+ (NSString *)temporaryExportDirectoryWithError:(NSError **)outError
{
    NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:
                           [NSString stringWithFormat:@"MacDownExport-%@",
                            [NSProcessInfo processInfo].globallyUniqueString]];
    if (![[NSFileManager defaultManager] createDirectoryAtPath:directory
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:outError])
        return nil;
    return directory;
}

+ (BOOL)zipDirectoryAtPath:(NSString *)root toURL:(NSURL *)url error:(NSError **)outError
{
    [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];

    NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:root
                                                                         error:outError];
    if (!items)
        return NO;

    NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"-r", @"-X",
                                 url.path, nil];
    [arguments addObjectsFromArray:items];

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/zip";
    task.currentDirectoryPath = root;
    task.arguments = arguments;
    task.standardOutput = [NSPipe pipe];
    task.standardError = [NSPipe pipe];

    @try
    {
        [task launch];
        [task waitUntilExit];
    }
    @catch (NSException *exception)
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain:MPOfficeExporterErrorDomain
                                            code:1
                                        userInfo:@{NSLocalizedDescriptionKey:
                                                   @"Unable to launch /usr/bin/zip for Office export."}];
        }
        return NO;
    }

    if (task.terminationStatus != 0)
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain:MPOfficeExporterErrorDomain
                                            code:task.terminationStatus
                                        userInfo:@{NSLocalizedDescriptionKey:
                                                   @"Unable to package Office export."}];
        }
        return NO;
    }
    return YES;
}

@end
