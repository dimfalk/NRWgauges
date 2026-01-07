# quiets concerns of R CMD check
c("latest_waterlevel",
  "latest_discharge",
  "latest_velocity",
  "has_current_velocity") |> utils::globalVariables()
