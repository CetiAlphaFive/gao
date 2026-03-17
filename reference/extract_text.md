# Extract Text from GAO PDF Reports

Reads PDF files from a local directory and extracts their text content
using
[`pdftools::pdf_text()`](https://docs.ropensci.org/pdftools//reference/pdftools.html).
Designed to work with PDFs downloaded via
[`download_pdfs()`](https://cetialphafive.github.io/gao/reference/download_pdfs.md)
or
[`auto_download()`](https://cetialphafive.github.io/gao/reference/auto_download.md).

## Usage

``` r
extract_text(pdf_dir, pattern = "\\.pdf$", verbose = TRUE)
```

## Arguments

- pdf_dir:

  Character. Path to a directory containing PDF files.

- pattern:

  Character. Regex pattern to filter filenames (default: `"\\.pdf$"`).

- verbose:

  Logical. Show progress messages (default: `TRUE`).

## Value

A data.frame with columns:

- file:

  Character. The PDF filename (without directory path).

- text:

  Character. The extracted text, with pages collapsed into a single
  string separated by newlines.

- pages:

  Integer. The number of pages in the PDF.

## Details

Requires the pdftools package. Install it with
`install.packages("pdftools")` if not already available.

Files that fail to parse (e.g., scanned/image-only PDFs) are included in
the result with `NA` text and `NA` pages along with a warning.

## Examples

``` r
if (FALSE) { # \dontrun{
# After downloading PDFs
auto_download(format = "pdf", year = 2024, download_dir = "gao_reports")
texts <- extract_text("gao_reports/pdf")
head(texts$file)
nchar(texts$text[1])
} # }
```
