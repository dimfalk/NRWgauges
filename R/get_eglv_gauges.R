#' Get EGLV gauge metadata (simplified), locations and latest measurements
#'
#' @return Sf object.
#' @export
#'
#' @examples
#' \dontrun{
#' get_eglv_gauges()
#' }
get_eglv_gauges <- function() {

  # debugging ------------------------------------------------------------------

  # check arguments ------------------------------------------------------------

  # ----------------------------------------------------------------------------

  base_url <- "https://pegel.eglv.de/gauges/"

  # send request
  r_raw <- httr::GET(base_url)

  # parse response: raw to json
  r_json <- httr::content(r_raw, "text", encoding = "UTF-8")

  gauges <- jsonlite::fromJSON(r_json) |>
    tibble::as_tibble() |>
    sf::st_as_sf(coords = c("Rechtswert", "Hochwert"),
                 crs = "epsg:25832")

  # drop columns, tidy velocity
  gauges <- gauges |>
    dplyr::select(-latest_waterlevel, -latest_discharge, -latest_velocity) |>
    dplyr::mutate("has_current_velocity" = ifelse(is.na(has_current_velocity), FALSE, TRUE))

  # rename columns, change order
  gauges <- gauges |> dplyr::rename("name" = "Name",
                                    "id" = "Pegel-Nummer",
                                    "waterbody" = "Gewaesser",
                                    "current_trend" = "Aktueller Trend") |>
    dplyr::select("id", "name", "waterbody",
                  "has_current_waterlevel",
                  "has_current_discharge",
                  "has_current_velocity")

  gauges
}
