#let conf(
  lang: "en",
  region: "DE",
  paper: "a4",
  margin: (top: 3cm, bottom: 3cm, inside: 2cm, outside: 2cm),
  cols: 1,
  font: ("Roboto Serif"),
  fontsize: 12pt,
  sectionnumbering: none,
  pagenumbering: "1",
  doc,
) = {
  set page(
    paper: paper,
    margin: margin,
    columns: cols,
    numbering: pagenumbering,
    header-ascent: 40% + 0pt,
    header: context {
      set text(10pt)
      if (here().page()) > 1 {  // skip first page
        if calc.odd(here().page()) {  // different headers on L/R pages
          align(right,smallcaps(all: true)[michaelrommel.com] )
        } else {
          align(left,smallcaps(all: true)[Michael Rommel] )
        }
      }
    },
  )
  set text(lang: lang,
    region: region,
    font: font,
    size: fontsize,
    alternates: false,
    discretionary-ligatures: false,
    historical-ligatures: true,
    number-type: "old-style",
    number-width: "proportional")
  set strong(delta: 200)
  set par(
    spacing: 16pt,  
    leading: 10pt, 
  )
  show raw: set block(inset: (left: 1em, top: 1em, right: 1em, bottom: 1em ))
  show raw: set text(size: 10pt, font: "VictorMono NF")

  show heading: set text(hyphenate: false)
  show heading.where(level: 1): it => align(left, block(above: 24pt, below: 16pt, width: 100% )[
        //#v(12pt) // space above 
        //#set par(leading: 16pt)
        //#set text(font: font, weight: "regular", style: "normal", size: 16pt)
        #block(it.body) 
        //#v(6pt) // space below 
      ])

  show heading.where(level: 2): it => align(left, block(above: 28pt, below: 16pt, width: 80%)[
        #block(it.body) 
      ])

  show heading.where(level: 3): it => align(left, block(above: 20pt, below: 16pt)[
        #block(it.body) 
      ])

  show regex("https?://\S+"): set text(style: "normal", rgb("#33d"))
  show link: set text(style: "normal", rgb("#111177"))
  show link: underline
  doc  // HERE is the actual body content
}
