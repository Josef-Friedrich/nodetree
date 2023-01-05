# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- ...

### Changed

- ...

### Deprecated

- ...

### Removed

- ...

### Fixed

- ...

### Security

- ...

## [v0.1] - 2015-06-16

Converted to DTX file

## [v1.0] - 2016-07-07

Inital release

## [v1.1] - 2016-07-13

Fix the registration of same callbacks

## [v1.2] - 2016-07-18

Fix difference between README.md in the upload and that from nodetree.dtx

## [v2.0] - 2020-05-29

- Switch from lowercase macro names to PascalCase names for better readability.
- The Lua code is no longer developed inside the DTX file, instead in a separate file named nodetree.lua.
- Add a sub package named nodetree-embed.sty for embedding nodetree views into a \LaTeX{} document.
- Add support for new node subtype names.
- Add support for a new Lua\TeX{} node callback.
- Add support for node properties.
- Less verbose representation of node attributes.
- Minor tree output adjustments.

## [v2.1] - 2020-10-03

- Make the package compatible with the Harfbuzz mode of the luaotfload fontloader.
- Print node properties of copied nodes.

## [v2.2] - 2020-10-23

- Fix unavailable library error (utf8 not in Lua5.1)

## [v2.2.1] - 2022-12-17

- Replace non-printable unicode symbols with ???.
- Add missing newlines for callbacks with multiple node lists.
- Print subtype fields with value 0.
- Fix the presentation of the subtype field of a glyph as a bit field.
