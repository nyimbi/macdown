//
//  MPExportPanelAccessoryViewController.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 14/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import "MPExportPanelAccessoryViewController.h"
#import "MPExportOptions.h"

@interface MPExportPanelAccessoryViewController ()

@property (strong) NSButton *stylesButton;
@property (strong) NSButton *highlightingButton;
@property (strong) NSButton *pageNumbersButton;
@property (strong) NSTextField *headerField;
@property (strong) NSTextField *footerField;
@property (strong) NSTextField *logoField;
@property (strong) NSTextField *watermarkField;
@property (strong) NSTextField *brandColorField;

@end


@implementation MPExportPanelAccessoryViewController
{
    BOOL _stylesIncluded;
    BOOL _highlightingIncluded;
    BOOL _pageNumbersIncluded;
    NSString *_headerText;
    NSString *_footerText;
    NSString *_logoPath;
    NSString *_watermarkText;
    NSString *_brandColor;
}

- (id)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self)
        return nil;

    MPExportOptions *options = [MPExportOptions defaultOptions];
    _stylesIncluded = options.stylesIncluded;
    _highlightingIncluded = options.highlightingIncluded;
    _pageNumbersIncluded = options.pageNumbersIncluded;
    _brandColor = [options.brandColor copy];

    return self;
}

- (void)loadView
{
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 420, 252)];
    view.autoresizingMask = NSViewWidthSizable;

    CGFloat y = 222;
    self.stylesButton = [self checkboxWithTitle:@"Include styles"
                                          frame:NSMakeRect(0, y, 190, 20)];
    self.highlightingButton = [self checkboxWithTitle:@"Include syntax highlighting"
                                                frame:NSMakeRect(200, y, 220, 20)];
    y -= 28;
    self.pageNumbersButton = [self checkboxWithTitle:@"Page numbers"
                                               frame:NSMakeRect(0, y, 190, 20)];

    self.headerField = [self textFieldWithFrame:NSMakeRect(110, y - 36, 310, 22)];
    [view addSubview:[self labelWithTitle:@"Header" frame:NSMakeRect(0, y - 33, 100, 17)]];
    [view addSubview:self.headerField];

    self.footerField = [self textFieldWithFrame:NSMakeRect(110, y - 66, 310, 22)];
    [view addSubview:[self labelWithTitle:@"Footer" frame:NSMakeRect(0, y - 63, 100, 17)]];
    [view addSubview:self.footerField];

    self.logoField = [self textFieldWithFrame:NSMakeRect(110, y - 96, 220, 22)];
    NSButton *logoButton = [[NSButton alloc] initWithFrame:NSMakeRect(338, y - 97, 82, 24)];
    logoButton.bezelStyle = NSRoundedBezelStyle;
    logoButton.title = @"Choose...";
    logoButton.target = self;
    logoButton.action = @selector(chooseLogo:);
    [view addSubview:[self labelWithTitle:@"Logo file" frame:NSMakeRect(0, y - 93, 100, 17)]];
    [view addSubview:self.logoField];
    [view addSubview:logoButton];

    self.watermarkField = [self textFieldWithFrame:NSMakeRect(110, y - 126, 310, 22)];
    [view addSubview:[self labelWithTitle:@"Watermark" frame:NSMakeRect(0, y - 123, 100, 17)]];
    [view addSubview:self.watermarkField];

    self.brandColorField = [self textFieldWithFrame:NSMakeRect(110, y - 156, 130, 22)];
    [view addSubview:[self labelWithTitle:@"Brand color" frame:NSMakeRect(0, y - 153, 100, 17)]];
    [view addSubview:self.brandColorField];

    [view addSubview:self.stylesButton];
    [view addSubview:self.highlightingButton];
    [view addSubview:self.pageNumbersButton];

    self.view = view;
    [self syncControlsFromProperties];
}

- (NSButton *)checkboxWithTitle:(NSString *)title frame:(NSRect)frame
{
    NSButton *button = [[NSButton alloc] initWithFrame:frame];
    button.buttonType = NSSwitchButton;
    button.title = title;
    return button;
}

- (NSTextField *)labelWithTitle:(NSString *)title frame:(NSRect)frame
{
    NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
    label.bezeled = NO;
    label.drawsBackground = NO;
    label.editable = NO;
    label.selectable = NO;
    label.stringValue = title;
    return label;
}

- (NSTextField *)textFieldWithFrame:(NSRect)frame
{
    NSTextField *field = [[NSTextField alloc] initWithFrame:frame];
    field.autoresizingMask = NSViewWidthSizable;
    return field;
}

- (NSString *)stringValueForField:(NSTextField *)field fallback:(NSString *)value
{
    if (!field)
        return value ?: @"";
    return field.stringValue ?: @"";
}

- (void)setString:(NSString *)value
          onField:(NSTextField *)field
            store:(NSString * __strong *)store
{
    *store = [value copy];
    if (field)
        field.stringValue = value ?: @"";
}

- (void)syncControlsFromProperties
{
    self.stylesButton.state = self.stylesIncluded ? NSOnState : NSOffState;
    self.highlightingButton.state =
        self.highlightingIncluded ? NSOnState : NSOffState;
    self.pageNumbersButton.state =
        self.pageNumbersIncluded ? NSOnState : NSOffState;
    self.headerField.stringValue = self.headerText ?: @"";
    self.footerField.stringValue = self.footerText ?: @"";
    self.logoField.stringValue = self.logoPath ?: @"";
    self.watermarkField.stringValue = self.watermarkText ?: @"";
    self.brandColorField.stringValue = self.brandColor ?: @"";
}

- (BOOL)isStylesIncluded
{
    if (self.stylesButton)
        return self.stylesButton.state == NSOnState;
    return _stylesIncluded;
}

- (void)setStylesIncluded:(BOOL)stylesIncluded
{
    _stylesIncluded = stylesIncluded;
    if (self.stylesButton)
        self.stylesButton.state = stylesIncluded ? NSOnState : NSOffState;
}

- (BOOL)isHighlightingIncluded
{
    if (self.highlightingButton)
        return self.highlightingButton.state == NSOnState;
    return _highlightingIncluded;
}

- (void)setHighlightingIncluded:(BOOL)highlightingIncluded
{
    _highlightingIncluded = highlightingIncluded;
    if (self.highlightingButton)
        self.highlightingButton.state = highlightingIncluded ? NSOnState : NSOffState;
}

- (BOOL)arePageNumbersIncluded
{
    if (self.pageNumbersButton)
        return self.pageNumbersButton.state == NSOnState;
    return _pageNumbersIncluded;
}

- (void)setPageNumbersIncluded:(BOOL)pageNumbersIncluded
{
    _pageNumbersIncluded = pageNumbersIncluded;
    if (self.pageNumbersButton)
        self.pageNumbersButton.state = pageNumbersIncluded ? NSOnState : NSOffState;
}

- (NSString *)headerText
{
    return [self stringValueForField:self.headerField fallback:_headerText];
}

- (void)setHeaderText:(NSString *)headerText
{
    [self setString:headerText onField:self.headerField store:&_headerText];
}

- (NSString *)footerText
{
    return [self stringValueForField:self.footerField fallback:_footerText];
}

- (void)setFooterText:(NSString *)footerText
{
    [self setString:footerText onField:self.footerField store:&_footerText];
}

- (NSString *)logoPath
{
    return [self stringValueForField:self.logoField fallback:_logoPath];
}

- (void)setLogoPath:(NSString *)logoPath
{
    [self setString:logoPath onField:self.logoField store:&_logoPath];
}

- (NSString *)watermarkText
{
    return [self stringValueForField:self.watermarkField fallback:_watermarkText];
}

- (void)setWatermarkText:(NSString *)watermarkText
{
    [self setString:watermarkText onField:self.watermarkField store:&_watermarkText];
}

- (NSString *)brandColor
{
    return [self stringValueForField:self.brandColorField fallback:_brandColor];
}

- (void)setBrandColor:(NSString *)brandColor
{
    [self setString:brandColor onField:self.brandColorField store:&_brandColor];
}

- (void)chooseLogo:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowedFileTypes = @[@"png", @"jpg", @"jpeg"];
    panel.canChooseDirectories = NO;
    panel.canChooseFiles = YES;
    panel.allowsMultipleSelection = NO;
    [panel beginSheetModalForWindow:self.view.window
                  completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton)
            self.logoPath = panel.URL.path;
    }];
}

- (MPExportOptions *)exportOptions
{
    MPExportOptions *options = [MPExportOptions defaultOptions];
    options.stylesIncluded = self.stylesIncluded;
    options.highlightingIncluded = self.highlightingIncluded;
    options.pageNumbersIncluded = self.pageNumbersIncluded;
    options.headerText = self.headerText;
    options.footerText = self.footerText;
    options.logoPath = self.logoPath;
    options.watermarkText = self.watermarkText;
    options.brandColor = self.brandColor;
    return options;
}

@end
