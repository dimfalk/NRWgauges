with_mock_api({

  test_that("Output class is as expected.", {

    x <- get_eglv_gauges()

    expect_s3_class(x, c("sf", "tbl_df", "tbl", "data.frame"))
  })

  test_that("Dimensions are as expected.", {

    x <- get_eglv_gauges()

    expect_equal(dim(x), c(122, 7))
  })

  test_that("Column names are as expected.", {

    cnames <- c("id", "name", "waterbody",
                "has_current_waterlevel",
                "has_current_discharge",
                "has_current_velocity",
                "geometry")

    x <- get_eglv_gauges()

    expect_equal(colnames(x), cnames)
  })

  test_that("Types are as expected.", {

    dtype <- c("character", "character", "character",
               "logical", "logical", "logical",
               "list")

    x <- get_eglv_gauges()

    x_dtype <- lapply(x, typeof) |> unlist() |> as.character()

    expect_equal(x_dtype, dtype)
  })
})
