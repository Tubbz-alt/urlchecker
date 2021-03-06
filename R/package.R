#' Check urls in a package
#'
#' @param path Path to the package
#' @param db A url database
#' @param parallel If `TRUE`, check the URLs in parallel
#' @param pool A multi handle created by [curl::new_pool()]. If `NULL` use a global pool.
#' @param progress Whether to show the progress bar for parallel checks
#' @export
#' @examples
#' \dontrun{
#' url_check("my_pkg")
#' }
#'
url_check <- function(path = ".", db = NULL, parallel = TRUE, pool = curl::new_pool(), progress = TRUE) {
  if (is.null(db)) {
    db <- url_db_from_package_sources(normalizePath(path))
  }
  res <- check_url_db(db, parallel = parallel, pool = pool, verbose = progress)
  if (NROW(res) > 0) {
    res$root <- normalizePath(path)
  }
  class(res) <- c("urlchecker_db", class(res))
  res
}

#' Update URLs in a package
#'
#' @param path Path to the package
#' @param results results from [url_check].
#' @return The results from `url_check(path)`, invisibly.
#' @export
#' @examples
#' \dontrun{
#' url_update("my_pkg")
#' }
#'
url_update <- function(path = ".", results = url_check(path)) {
  can_update <- vlapply(results[["New"]], nzchar)
  to_update <- results[can_update, ]
  for (row in seq_len(NROW(to_update))) {
    old <- to_update[["URL"]][[row]]
    new <- to_update[["New"]][[row]]
    root <- to_update[["root"]][[row]]
    if (nzchar(new)) {
      from <- to_update[["From"]][[row]]
      if (("README.md" %in% from) && file.exists("README.Rmd")) {
        from <- c(from, "README.Rmd")
      }
      for (file in from) {
        file_path <- file.path(root, file)
        data <- readLines(file_path)
        data <- gsub(old, new, data, fixed = TRUE)
        writeLines(data, file_path)
        cli::cli_alert_success("{.strong Updated:} {.url {old}} to {.url {new}} in {.file {file}}")
      }
    }
  }

  print(results[!can_update, ])

  invisible(results)
}

#' @export
print.urlchecker_db <- function(x, ...) {
  for (row in seq_len(NROW(x))) {
    cran <- x[["CRAN"]][[row]]
    if (nzchar(cran)) {
      status <- "Error"
      message <- "CRAN URL not in canonical form"
      url <- cran
      new <- ""
    } else {
      status <- x[["Status"]][[row]]
      message <- x[["Message"]][[row]]
      url <- x[["URL"]][[row]]
      new <- x[["New"]][[row]]
    }
    root <- x[["root"]][[row]]
    from <- x[["From"]][[row]]

    for (file in from) {
      file_path <- file.path(root, file)
      data <- readLines(file_path)
      match <- regexpr(url, data, fixed = TRUE)
      lines <- which(match != -1)
      starts <- match[match != -1]
      ends <- starts + attr(match, "match.length")[match != -1]
      for (i in seq_along(lines)) {
        pointer <- paste0(strrep(" ", starts[[i]] - 1), "^", strrep("~", ends[[i]] - starts[[i]] - 1))
        if (nzchar(new)) {
          fix_it <- paste0(strrep(" ", starts[[i]] - 1), new)
          cli::cli_alert_warning("
            {.strong Warning:} {file}:{lines[[i]]}:{starts[[i]]} {.emph Moved}
            {data[lines[[i]]]}
            {pointer}
            {fix_it}
            ")
        } else {
        cli::cli_alert_danger("
          {.strong Error:} {file}:{lines[[i]]}:{starts[[i]]} {.emph {status}: {message}}
          {data[lines[[i]]]}
          {pointer}
          ")
        }
      }
    }
  }

    invisible(x)
}

vlapply <- function(x, f, ...) vapply(x, f, logical(1))
