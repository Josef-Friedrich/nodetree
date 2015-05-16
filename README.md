# luanodelist

Based on the [gist of Patrick Gundlach](https://gist.github.com/pgundlach/556247).

`luanodelist` displays some debug informations of the node list in the
terminal, when you render a Latex document.

```
lualatex example.tex
```

```
This is LuaTeX, Version beta-0.79.1 (TeX Live 2014) (rev 4971)
 restricted \write18 enabled.
...
(./luanodelist.lua)) (./example.aux)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% BEGIN nodelist debug
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

GLUE baselineskip: 5.05556pt;

HLIST width 345pt; height 6.94444pt; depth 1.94444pt; glue_set 205; glue_sign 1; glue_order 2;
WHATSIT name: whatsit; type: local_par;

HLIST width 15pt;
GLYPH char: "L"; lang: 0; font: 15; width: 6.25002pt;
GLYPH char: "o"; lang: 0; font: 15; width: 5.00002pt;
GLYPH char: "r"; lang: 0; font: 15; width: 3.91667pt;
GLYPH char: "e"; lang: 0; font: 15; width: 4.44444pt;
GLYPH char: "m"; lang: 0; font: 15; width: 8.33336pt;
GLUE skip: 3.33333pt + 1.66666pt - 1.11111pt;
GLYPH char: "i"; lang: 0; font: 15; width: 2.77779pt;
GLYPH char: "p"; lang: 0; font: 15; width: 5.55557pt;
DISC prepostreplace;
GLYPH char: "-"; lang: 0; font: 15; width: 3.33333pt;
GLYPH char: "s"; lang: 0; font: 15; width: 3.94444pt;
GLYPH char: "u"; lang: 0; font: 15; width: 5.55557pt;
GLYPH char: "m"; lang: 0; font: 15; width: 8.33336pt;
GLUE skip: 3.33333pt + 1.66666pt - 1.11111pt;
GLYPH char: "d"; lang: 0; font: 15; width: 5.55557pt;
GLYPH char: "o"; lang: 0; font: 15; width: 5.00002pt;
DISC prepostreplace;
GLYPH char: "-"; lang: 0; font: 15; width: 3.33333pt;
GLYPH char: "l"; lang: 0; font: 15; width: 2.77779pt;
GLYPH char: "o"; lang: 0; font: 15; width: 5.00002pt;
GLYPH char: "r"; lang: 0; font: 15; width: 3.91667pt;
GLUE skip: 3.33333pt + 1.66666pt - 1.11111pt;
GLYPH char: "s"; lang: 0; font: 15; width: 3.94444pt;
GLYPH char: "i"; lang: 0; font: 15; width: 2.77779pt;
GLYPH char: "t"; lang: 0; font: 15; width: 3.8889pt;
GLUE skip: 3.33333pt + 1.66666pt - 1.11111pt;
GLYPH char: "a"; lang: 0; font: 15; width: 5.00002pt;
GLYPH char: "m"; lang: 0; font: 15; width: 8.33336pt;
GLYPH char: "e"; lang: 0; font: 15; width: 4.44444pt;
GLYPH char: "t"; lang: 0; font: 15; width: 3.8889pt;
GLYPH char: "."; lang: 0; font: 15; width: 2.77779pt;
PENALTY 10000
GLUE parfillskip: 0pt + 1 fil;
GLUE rightskip: 0pt;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% END nodelist debug
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

...
Output written on example.pdf (1 page, 12841 bytes).
Transcript written on example.log.
```
