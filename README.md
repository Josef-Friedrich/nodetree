# tree

Inspired by a [gist of Patrick Gundlach](https://gist.github.com/pgundlach/556247).

`tree` displays some debug informations of the node list in the
terminal, when you render a Latex document.

```
post_linebreak_filter:
│
├─GLUE subtype: baselineskip; width: 5.06pt;
└─HLIST subtype: line; width: 345pt; height: 6.94pt; dir: TLT; glue_order: 2; glue_sign: 1; glue_set: 304.99993896484;
 ╚═head:
  ├─LOCAL_PAR dir: TLT;
  ├─HLIST subtype: indent; width: 15pt; dir: TLT;
  ├─GLYPH char: "O"; font: 15; left: 2; right: 3; uchyph: 1; width: 7.78pt; height: 6.83pt;
  ├─DISC subtype: regular; penalty: 50;
  │ ╠═post:
  │ ║ └─GLYPH subtype: ghost; char: "\12"; font: 15; width: 5.56pt; height: 6.94pt;
  │ ║  ╚═components:
  │ ║   ├─GLYPH subtype: ligature; char: "f"; font: 15; left: 2; right: 3; uchyph: 1; width: 3.06pt; height: 6.94pt;
  │ ║   └─GLYPH subtype: ligature; char: "i"; font: 15; left: 2; right: 3; uchyph: 1; width: 2.78pt; height: 6.68pt;
  │ ╠═pre:
  │ ║ ├─GLYPH char: "f"; font: 15; left: 2; right: 3; uchyph: 1; width: 3.06pt; height: 6.94pt;
  │ ║ └─GLYPH char: "-"; font: 15; left: 2; right: 3; uchyph: 1; width: 3.33pt; height: 4.31pt;
  │ ╚═replace:
  │  └─GLYPH subtype: ghost; char: "\14"; font: 15; width: 8.33pt; height: 6.94pt;
  │   ╚═components:
  │    ├─GLYPH subtype: ghost; char: "\11"; font: 15; width: 5.83pt; height: 6.94pt;
  │    │ ╚═components:
  │    │  ├─GLYPH subtype: ligature; char: "f"; font: 15; left: 2; right: 3; uchyph: 1; width: 3.06pt; height: 6.94pt;
  │    │  └─GLYPH subtype: ligature; char: "f"; font: 15; left: 2; right: 3; uchyph: 1; width: 3.06pt; height: 6.94pt;
  │    └─GLYPH subtype: ligature; char: "i"; font: 15; left: 2; right: 3; uchyph: 1; width: 2.78pt; height: 6.68pt;
  ├─GLYPH char: "c"; font: 15; left: 2; right: 3; uchyph: 1; width: 4.44pt; height: 4.31pt;
  ├─GLYPH char: "e"; font: 15; left: 2; right: 3; uchyph: 1; width: 4.44pt; height: 4.31pt;
  ├─PENALTY penalty: 10000;
  ├─GLUE subtype: parfillskip; stretch: 65536; stretch_order: 2;
  └─GLUE subtype: rightskip;

```

# UTF8 Box drawing symbols

## Light

```
│ │
│ ├─┤field1: 1pt├┤field2: 1pt│
│ └─
└─
```

## Heavy

```
┃ ┃
┃ ┣━┫field1: 1pt┣┫field2: 1pt┃
┃ ┗━
┗━
```

## Double

```
║ ║
║ ╠═╣field1: 1pt╠╣field2: 1pt║
║ ╚═
╚═
```

