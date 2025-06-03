# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v2.4.1] - 2025-06-03

### Fixed

- Skip the data field of a whatsit write node to avoid compilation errors

## [v2.4.0] - 2024-09-17

### Changed

- Sort properties (Patch by Patrick Gundlach)

## [v2.3.0] - 2023-09-10

### Added

- Option `verbosity=0` provides a narrow output without line breaks
- New option `firstline` and `lastline` for `\NodetreeEmbedInput`

### Fixed

- Callback handling

## [v2.2.1] - 2022-12-17

### Added

- Add missing newlines for callbacks with multiple node lists.

### Changed

- Replace non-printable unicode symbols with ???.

### Fixed

- Print subtype fields with value 0.
- Fix the presentation of the subtype field of a glyph as a bit field.

## [v2.2] - 2020-10-23

### Fixed

- Fix unavailable library error (utf8 not in Lua5.1)

## [v2.1] - 2020-10-03

### Added

- Print node properties of copied nodes.

### Fixed

- Make the package compatible with the Harfbuzz mode of the luaotfload
  fontloader.

## [v2.0] - 2020-05-29

### Added

- Add a sub package named nodetree-embed.sty for embedding nodetree
  views into a LaTeX document.
- Add support for new node subtype names.
- Add support for a new LuaTeX node callback.
- Add support for node properties.

### Changed

- Switch from lowercase macro names to PascalCase names for better
  readability.
- The Lua code is no longer developed inside the DTX file, instead in
  a separate file named nodetree.lua.
- Less verbose representation of node attributes.
- Minor tree output adjustments.

## [v1.2] - 2016-07-18

### Fixed

- Fix difference between README.md in the upload and that from
  nodetree.dtx

## [v1.1] - 2016-07-13

### Fixed

- Fix the registration of same callbacks

## [v1.0] - 2016-07-07

### Added

- Inital release

## [v0.1] - 2015-06-16

### Changed

- Converted to DTX file
