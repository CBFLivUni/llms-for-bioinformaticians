# A local LLM answering the same question twice from memory, then from a tool

library(ellmer)

MODEL <- "qwen3:0.6b"

## Without a tool

# The model can only answer from what it picked up in training, so it guesses.
ask_without_tools <- function(question) {
  chat <- chat_ollama(model = MODEL)
  chat$chat(question)
}

## With a tool

annotation <- data.frame(
  symbol = c(
    "SOX9",
    "COL2A1",
    "ACAN",
    "TGFB1",
    "MATN3",
    "ADAMTS4",
    "IL6",
    "PRG4"
  ),
  chromosome = c("17", "12", "15", "19", "2", "1", "7", "1"),
  n_exons = c(3L, 54L, 19L, 7L, 8L, 9L, 5L, 13L)
)

lookup_gene <- function(symbol) {
  hit <- annotation[annotation$symbol == toupper(symbol), ]
  if (nrow(hit) == 0) {
    return(paste0(symbol, " is not in the table"))
  }
  paste0(
    hit$symbol,
    " is on chromosome ",
    hit$chromosome,
    " with ",
    hit$n_exons,
    " exons"
  )
}

ask_with_tools <- function(question) {
  chat <- chat_ollama(model = MODEL)

  chat$register_tool(tool(
    lookup_gene,
    "Look up the chromosome and exon count for a gene symbol.",
    arguments = list(symbol = type_string("A HGNC gene symbol, e.g. SOX9"))
  ))

  # print the request as it comes in so clear it is two steps
  chat$on_tool_request(function(request) {
    cat(
      "  -> R is being asked to run:",
      request@name,
      "(",
      unlist(request@arguments),
      ")\n"
    )
  })

  chat$chat(question)
}

## Ask

# COL2A1 has 54 exons
cat("\n== no tool ==\n")
invisible(ask_without_tools("How many exons does COL2A1 have?"))

cat("\n== with a tool ==\n")
invisible(ask_with_tools("How many exons does COL2A1 have?"))
