#!/usr/bin/env bash

PATHNAME=$1

if [[ -z "$PATHNAME" ]]; then
	echo "Syntax: $0 <path to md file>"
	exit 1
fi

ARTICLENAME=$(basename -s .md "${PATHNAME}")

(
	cd ..
	pandoc \
		-f gfm \
		--pdf-engine=typst \
		-V template=articles/scripts/article.typ \
		"articles/${PATHNAME}" \
		-o "articles/pdf/${ARTICLENAME}.pdf"
)
