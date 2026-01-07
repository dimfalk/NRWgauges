#' Get water level, discharge or velocity measurements for selected EGLV gauges
#'
#' @param x Sf object containing gauges to be used for subsequent queries,
#'     as provided by `get_eglv_gauges()`.
#' @param par character. Parameter to be queried: `"waterlevel"`, `"discharge"`, or `"velocity"`.
#'
#' @return List of xts objects.
#' @export
#'
#' @seealso [get_eglv_gauges()]
#'
#' @examples
#' \dontrun{
#' gauge <- get_eglv_gauges() |> dplyr::filter(id == "10103")
#'
#' get_eglv_measurements(gauge)
#' get_eglv_measurements(gauge, par = "discharge")
#'
#' gauges <- get_eglv_gauges() |> dplyr::filter(waterbody == "Hammbach")
#'
#' get_eglv_measurements(gauges)
#' }
get_eglv_measurements <- function(x = NULL,
                                  par = "waterlevel") {

  # debugging ------------------------------------------------------------------

  # x <- get_eglv_gauges() |> dplyr::filter(id == "10103")

  # par <- "waterlevel"
  # par <- "discharge"
  # par <- "velocity"

  # check arguments ------------------------------------------------------------

  checkmate::assert_tibble(x)

  allowed_par <- c("waterlevel", "discharge", "velocity")
  checkmate::assert_choice(par, allowed_par)

  # pre-processing -------------------------------------------------------------

  # n for original object
  n <- dim(x)[1]

  # subset gauges to avail. parameters only
  cname <- paste0("has_current_", par)

  x_subset <- x |> dplyr::filter(!!rlang::sym(cname) == TRUE)

  # pull ids
  ids <- x_subset[["id"]]

  # n after subsetting
  n_subset <- dim(x_subset)[1]

  if (n_subset == 0) {

    paste0("The requested parameter '", par, "' is not available for any gauge. Aborting.") |> stop()

  } else if (n > n_subset) {

    paste(ids, collapse = ", ") |>
      paste0("The requested parameter '", par, "' is only available for the subsequent gauges: \n ",
             x = _,
             "\n Returning xts objects for a subset of 'x'.") |> warning()
  }

  # main -----------------------------------------------------------------------

  # init object to be returned
  xtslist <- list()

  base_url <- "https://pegel.eglv.de/measurements/"

  # set relevant parameter
  par_ger <- switch(par,

                    "waterlevel" = "Wasserstand",
                    "discharge" = "Durchfluss",
                    "velocity" = "Fließgeschwindigkeit")

  # iterate over individual stations, initialize progress bar
  pb <- progress::progress_bar$new(format = "(:spin) [:bar] :percent || Iteration: :current/:total || Elapsed time: :elapsedfull",
                                   total = n_subset,
                                   complete = "#",
                                   incomplete = "-",
                                   current = ">",
                                   clear = FALSE,
                                   width = 100)

  for (i in 1:n_subset) {

    # query definition
    query <- list("serial" = ids[i],
                  "unit_name" = par_ger)

    # send request
    r_raw <- httr::GET(base_url, query = query)

    # parse response: raw to json
    r_json <- httr::content(r_raw, "text", encoding = "UTF-8")

    r_mat <- jsonlite::fromJSON(r_json)[["gauge_measurements"]]

    meas <- xts::xts(as.numeric(r_mat[, 2]),
                     order.by = strptime(r_mat[, 1],
                                         format = "%Y-%m-%dT%H:%M:%SZ",
                                         tz = "etc/GMT-1"))

    # fix name
    names(meas) <- par_ger

    # add meta data
    meta <- get_eglv_meta(x_subset[i, ])

    attr(meas, "STAT_ID") <- meta |> dplyr::pull("id")
    attr(meas, "STAT_NAME") <- meta |> dplyr::pull("name")

    coords <- sf::st_geometry(meta) |> sf::st_coordinates()

    attr(meas, "X") <- coords[, "X"] |> as.numeric()
    attr(meas, "Y") <- coords[, "Y"] |> as.numeric()
    attr(meas, "Z") <- meta |> dplyr::pull("level_zero")
    attr(meas, "CRS_EPSG") <- "25832"
    attr(meas, "HRS_EPSG") <- "7873"
    attr(meas, "TZONE") <- "etc/GMT-1"

    attr(meas, "PARAMETER") <- par_ger

    attr(meas, "TS_START") <- xts::first(meas) |> zoo::index()
    attr(meas, "TS_END") <- xts::last(meas) |> zoo::index()
    attr(meas, "TS_DEFLATE") <- FALSE
    attr(meas, "TS_TYPE") <- "measurement"

    attr(meas, "MEAS_INTERVALTYPE") <- TRUE
    attr(meas, "MEAS_BLOCKING") <- "right"
    attr(meas, "MEAS_RESOLUTION") <- 5
    attr(meas, "MEAS_UNIT") <- switch(par_ger,

                                      "Wasserstand" = "cm",
                                      "Durchfluss" = "m3/s",
                                      "Fließgeschwindigkeit" = "m/s")
    attr(meas, "MEAS_STATEMENT") <- "mean"

    xtslist[[i]] <- meas

    Sys.sleep(0.5)

    pb$tick()
  }

  names(xtslist) <- ids

  xtslist
}
