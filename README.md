# LLMs for bioinformaticians

Slides and a runnable demo from the workshop *LLMs for bioinformaticians: what
they are useful for, how to work with them and where they can fail*. Presented at
[NorthernBUG 17](https://northernbug.github.io/northernbug17) in Liverpool on
18 September 2026, ahead of a panel discussion on the same topic.

- `northernbug17-workshop.html` is the rendered slide deck. It is a single
  self-contained file. Can download and open it in a browser.
- `northernbug17-workshop.qmd` is the Quarto source for the deck. Rebuild the
  HTML with `quarto render northernbug17-workshop.qmd`.
- `local-llm-demo.R` is the local LLM demo from the talk, described below.

## Running a local LLM from R: Ollama + ellmer

A self-contained demo presented at the workshop. The aim is to demonstrate the change in model behaviour with and without tool use. It asks a 0.6B-parameter model the
same question twice, first on its own (own memory) and then with an R function it can call (tool use). The model runs on CPU (a bit slowly), so no API key needed.

[Ollama](https://ollama.com) runs the model.
[ellmer](https://ellmer.tidyverse.org) drives it from R.

### Install

Get Ollama from [ollama.com/download](https://ollama.com/download), or on
Linux:

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

With Homebrew on macOS, `brew install ollama`. The installer starts a server on
`http://localhost:11434`. Check it answers with `ollama list`.

Pull the model, 522 MB:

```bash
ollama pull qwen3:0.6b
```

That tag is the 4-bit build, Q4_K_M. `ollama show qwen3:0.6b` prints the
quantisation, the context length and whether the model can call tools. The
model's page on [the library](https://ollama.com/library) lists the other
quantisations it comes in.

Then ellmer, in R:

```r
install.packages("ellmer")
```

Ran on R 4.5.2, ellmer 0.4.1 and Ollama 0.30.7.

### The script

It is in this repo as `local-llm-demo.R`. Run `Rscript local-llm-demo.R`, or
paste it into an R console.

```r
# A local LLM answering the same question twice: from memory, then from a tool.
# Needs Ollama running with qwen3:0.6b pulled.

library(ellmer)

MODEL <- "qwen3:0.6b"

### Without a tool

# The model can only answer from what it picked up in training, so it guesses.
ask_without_tools <- function(question) {
  chat <- chat_ollama(model = MODEL)
  chat$chat(question)
}

### With a tool

annotation <- data.frame(
  symbol = c("SOX9", "COL2A1", "ACAN", "TGFB1", "MATN3", "ADAMTS4", "IL6", "PRG4"),
  chromosome = c("17", "12", "15", "19", "2", "1", "7", "1"),
  n_exons = c(3L, 54L, 19L, 7L, 8L, 9L, 5L, 13L)
)

lookup_gene <- function(symbol) {
  hit <- annotation[annotation$symbol == toupper(symbol), ]
  if (nrow(hit) == 0) return(paste0(symbol, " is not in the table"))
  paste0(hit$symbol, " is on chromosome ", hit$chromosome, " with ", hit$n_exons, " exons")
}

ask_with_tools <- function(question) {
  chat <- chat_ollama(model = MODEL)

  chat$register_tool(tool(
    lookup_gene,
    "Look up the chromosome and exon count for a gene symbol.",
    arguments = list(symbol = type_string("A HGNC gene symbol, e.g. SOX9"))
  ))

  chat$on_tool_request(function(request) {
    cat("  -> R is being asked to run:", request@name,
        "(", unlist(request@arguments), ")\n")
  })

  chat$chat(question)
}

### Ask

# COL2A1 has 54 exons
cat("\n== no tool ==\n")
invisible(ask_without_tools("How many exons does COL2A1 have?"))

cat("\n== with a tool ==\n")
invisible(ask_with_tools("How many exons does COL2A1 have?"))
```

### What you should see

```
== no tool ==
The COL2A1 gene has 29 exons.

**Answer:** 29 exons.

== with a tool ==

◯ [tool call] lookup_gene(symbol = "COL2A1")
  -> R is being asked to run: lookup_gene ( COL2A1 )
● #> COL2A1 is on chromosome 12 with 54 exons
COL2A1 has 54 exons.
```

The right answer is 54. Without the tool the model states a wrong number with
no hedging, and gives a different one each time you run it, because all it can
do is predict plausible text. With the tool, the number comes from the data
frame and the model only has to decide to ask for it.

### Things to try

Swap in a hosted model with a line change:

```r
chat <- chat_anthropic(model = "claude-sonnet-5")   # needs ANTHROPIC_API_KEY
```

Or `chat_openai()`, `chat_google_gemini()`, and so on.

Give it a live lookup. Replace `lookup_gene()` with a query against biomaRt or
an AnnotationHub object, so the answers come from Ensembl.

### An alternative to Ollama

[llama.cpp](https://github.com/ggml-org/llama.cpp) is the engine Ollama is
built on, and its `llama-server` speaks the OpenAI API. You get more control
over quantisation and GPU offload, and in exchange you pick your own GGUF
files. From R you would point `chat_openai()` at it rather than using
`chat_ollama()`.
