# MacDown

[![](https://img.shields.io/github/release/MacDownApp/macdown.svg)](http://macdown.uranusjr.com/download/latest/)
![Total downloads](https://img.shields.io/github/downloads/MacDownApp/macdown/latest/total.svg)
[![Build Status](https://travis-ci.org/MacDownApp/macdown.svg?branch=master)](https://travis-ci.org/MacDownApp/macdown)


MacDown is an open source Markdown editor for OS X, released under the MIT License. The author stole the idea from [Chen Luo](https://twitter.com/chenluois)’s [Mou](http://mouapp.com) so that people can make crappy clones.

Visit the [project site](http://macdown.uranusjr.com/) for more information, or download [MacDown.app.zip](http://macdown.uranusjr.com/download/latest/) directly from the [latest releases](https://github.com/MacDownApp/macdown/releases/latest) page.

## Install

[Download](http://macdown.uranusjr.com/download/latest/), unzip, and drag the app to Applications folder. MacDown is also available through [Homebrew Cask](https://caskroom.github.io/):

    brew install --cask macdown

## Screenshot

![screenshot](assets/screenshot.png)

## Business Documents

MacDown can be used as a lightweight business-document workbench when a single
report, proposal, policy, or book needs reusable Markdown source files and
polished exports.

### High-value business improvements

The most valuable improvements for business use are:

* Master documents with local includes, so teams can compose reports from
  chapter, appendix, and reusable boilerplate files.
* Front matter metadata for title, subtitle, author, logo, header, footer,
  watermark, brand color, cover-page, page-numbering, and layout defaults.
* A generated table of contents for long documents.
* Export presets for modern, classic, and compact business layouts.
* Cover pages for proposals, board packs, books, and client deliverables.
* DOCX export for editable Microsoft Word handoff.
* PPTX export for turning Markdown briefs into editable presentation drafts.
* PDF export that uses the same branding controls as HTML export.
* HTML export that can be shared as a self-contained review artifact.
* Page numbering controls for printed and formal PDF/DOCX documents.
* Header and footer controls for confidentiality labels, authorship, dates,
  and document status.
* Logo and brand-color controls for client-facing or internal-branded output.
* Watermarking for draft, confidential, and internal-review deliverables.
* Include warnings for missing or circular source files.
* Consistent preview/export titles from document metadata.
* Relative asset paths, so logos and includes can live next to the master file.
* Save/export filename suggestions derived from front matter titles.
* Reusable chapter files for books, manuals, policies, and knowledge bases.
* A compact export style for dense operational reports.
* A clear path to future business controls such as approvals, templates, and
  tracked-review workflows.

### Master documents and includes

Create a master Markdown file and include other Markdown files with any of these
directives:

    !include chapters/introduction.md
    {{include chapters/market-analysis.md}}
    <!-- include: appendices/financials.md -->

Include paths may be absolute, use `~`, or be relative to the file that contains
the directive. Included files may include more files. MacDown skips circular
includes and inserts a warning in the generated Markdown when an include cannot
be read.

For a book, keep each chapter in its own file and assemble them from a master:

    ---
    title: Operating Manual
    subtitle: Field Edition
    author: Operations
    coverPage: true
    pageNumbers: true
    toc: true
    layout: modern
    ---

    # Operating Manual

    !include chapters/01-introduction.md
    !include chapters/02-setup.md
    !include chapters/03-procedures.md
    !include appendices/a-checklists.md

### Concatenating files

For a quick manual concatenation outside MacDown, use the shell:

    cat chapters/*.md > master.md

For repeatable business documents, prefer a MacDown master file with includes.
That keeps chapters independently editable and avoids rebuilding `master.md`
every time a source chapter changes.

### Table of contents

Enable HTML table-of-contents rendering in Markdown preferences, then add this
where the TOC should appear:

    [TOC]

In a master document, you can also set `toc: true` or `tableOfContents: true`
in front matter. MacDown inserts `[TOC]` at the start of the compiled document
when one is not already present.

### Cover pages and branding

Use YAML front matter at the top of the master document to prefill export
branding:

    ---
    title: Quarterly Business Review
    subtitle: Q4 FY26
    author: Strategy and Operations
    header: Confidential
    footer: Board package
    logo: assets/company-logo.png
    watermark: Draft
    brandColor: "#0F766E"
    coverPage: true
    pageNumbers: true
    layout: modern
    toc: true
    ---

Relative logo paths are resolved from the master document's folder. You can
still override these values in the export panel before writing HTML, PDF, DOCX,
or PPTX.

### Managing many open documents

On macOS versions with native window tabs, use the Window menu to reduce clutter:

* **Merge All Documents into Tabs** puts every open Markdown document into one
  tab group.
* **Group Document Tabs by Folder** creates separate tab groups for documents
  that live in the same folder, which is useful for books, policies, and report
  packs made from many chapter files.

## License

MacDown is released under the terms of MIT License. You may find the content of the license [here](http://opensource.org/licenses/MIT), or inside the `LICENSE` directory.

You may find full text of licenses about third-party components in the `LICENSE` directory, or the **About MacDown** panel in the application.

The following editor themes and CSS files are extracted from [Mou](http://mouapp.com), courtesy of Chen Luo:

* Mou Fresh Air
* Mou Fresh Air+
* Mou Night
* Mou Night+
* Mou Paper
* Mou Paper+
* Tomorrow
* Tomorrow Blue
* Tomorrow+
* Writer
* Writer+
* Clearness
* Clearness Dark
* GitHub
* GitHub2

## Development

### Requirements

If you wish to build MacDown yourself, you will need the following components/tools:

* OS X SDK (10.14 or later)
* Git
* [CocoaPods](https://cocoapods.org)

> Note: Old versions of CocoaPods are not supported. Please use the latest CocoaPods available on your system.

> Note: The Command Line Tools (CLT) should be unnecessary. If you failed to compile without it, please install CLT with
>
>     xcode-select --install
>
> and report back.

An appropriate SDK should be bundled with Xcode 5 or later versions.

### Environment Setup

After cloning the repository, run the following commands inside the repository root (directory containing this `README.md` file):

    git submodule update --init
    pod install
    make -C Dependency/peg-markdown-highlight

and open `MacDown.xcworkspace` in Xcode. The first command initialises the dependency submodule(s) used in MacDown; the second one installs dependencies managed by CocoaPods.

Refer to the official guides of Git and CocoaPods if you need more instructions. If you run into build issues later on, try running the following commands to update dependencies:

    git submodule update
    pod install

### Translation

Please help translation on [Transifex](https://www.transifex.com/macdown/macdown/).

![Transifex translation percentage](https://www.transifex.com/projects/p/macdown/resource/macdownxliff/chart/image_png/)

## Discussion

[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/MacDownApp/macdown)

Join our [Gitter channel](https://gitter.im/MacDownApp/macdown) if you have any problems with MacDown. Any suggestions are welcomed, too!

You can also [file an issue directly](https://github.com/MacDownApp/macdown/issues/new) on GitHub if you prefer so. But please, **search first to make sure no-one has reported the same issue already** before opening one yourself. MacDown does not update in your computer immediately when we make changes, so something you experienced might be known, or even fixed in the development version.

MacDown depends a lot on other open source projects, such as [Hoedown](https://github.com/hoedown/hoedown) for Markdown-to-HTML rendering, [Prism](http://prismjs.com) for syntax highlighting (in code blocks), and [PEG Markdown Highlight](https://github.com/ali-rantakari/peg-markdown-highlight) for editor highlighting. If you find problems when using those particular features, you can also consider reporting them directly to upstream projects as well as to MacDown’s issue tracker. I will do what I can if you report it here, but sometimes it can be more beneficial to interact with them directly.

## Tipping

If you find MacDown suitable for your needs, please consider [giving me a tip through PayPal](http://macdown.uranusjr.com/faq/#donation). Or, if you prefer to buy me a drink *personally* instead, just [send me a tweet](https://twitter.com/uranusjr) when you visit [Taipei, Taiwan](http://en.wikipedia.org/wiki/Taipei), where I live. I look forward to meeting you!
