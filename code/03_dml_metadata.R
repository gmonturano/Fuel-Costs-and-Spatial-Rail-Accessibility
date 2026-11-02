################################################################################
# 03 — Metadata-based Double / Debiased Machine Learning replication
#
# Metadata sheet used: DBML
# Model: DoubleMLPLR, one treatment per specification
################################################################################

source("R/00_functions.R")

required_dml <- c("DoubleML", "mlr3", "mlr3learners", "data.table")
install_missing(required_dml)
invisible(lapply(required_dml, library, character.only = TRUE))

panel <- load_panel()
panel <- add_standard_transforms(panel)

metadata <- read_metadata(sheet = "DBML")
specs <- spec_columns(metadata)

dml_results <- list()

for (sp in specs) {
  cat("\nDML:", sp, "\n")

  s <- get_spec(metadata, sp)

  y <- keep_existing(s$dependent, panel, sp, "dependent_var")
  d <- keep_existing(c(s$treatment, s$interaction), panel, sp, "independent_vars")
  x <- keep_existing(s$controls, panel, sp, "control_vars")

  if (length(y) == 0 || length(d) == 0) {
    cat("Skipped", sp, "- no dependent or treatment variable.\n")
    next
  }

  y <- y[1]
  d <- d[1]

  x <- setdiff(unique(c(x, "anno")), c(y, d, "PRO_COM"))
  x <- keep_existing(x, panel, sp, "x_cols")

  vars_used <- unique(c(y, d, x))
  data_used <- panel |>
    dplyr::select(dplyr::all_of(vars_used)) |>
    tidyr::drop_na()

  if (nrow(data_used) < 300) {
    cat("Skipped", sp, "- too few complete observations:", nrow(data_used), "\n")
    next
  }

  data_used <- data.table::as.data.table(data_used)

  dml_data <- DoubleML::DoubleMLData$new(
    data = data_used,
    y_col = y,
    d_cols = d,
    x_cols = x
  )

  if (requireNamespace("ranger", quietly = TRUE)) {
    learner_l <- mlr3::lrn("regr.ranger", num.trees = 500, min.node.size = 5)
    learner_m <- learner_l$clone()
    learner_name <- "ranger"
  } else {
    learner_l <- mlr3::lrn("regr.xgboost", nrounds = 200, eta = 0.1, max_depth = 6)
    learner_m <- learner_l$clone()
    learner_name <- "xgboost"
  }

  dml_model <- DoubleML::DoubleMLPLR$new(
    dml_data,
    ml_l = learner_l,
    ml_m = learner_m,
    n_folds = 5
  )

  tryCatch({
    dml_model$fit()

    dml_results[[sp]] <- data.frame(
      spec = sp,
      dependent = y,
      treatment = d,
      estimate = as.numeric(dml_model$coef),
      std_error = as.numeric(dml_model$se),
      t_stat = as.numeric(dml_model$t_stat),
      p_value = as.numeric(dml_model$pval),
      n_obs = nrow(data_used),
      learner = learner_name,
      method = "DoubleMLPLR"
    )

    saveRDS(dml_model, paste0("results/tables/03_dml_model_", sp, ".rds"))

    cat("Completed", sp, "\n")
  }, error = function(e) {
    cat("Error in", sp, ":", e$message, "\n")
  })
}

final_dml <- dplyr::bind_rows(dml_results)

if (nrow(final_dml) == 0) {
  stop("No DML models estimated. Check metadata and panel variable names.")
}

final_dml <- final_dml |>
  dplyr::mutate(
    stars = dplyr::case_when(
      p_value < 0.01 ~ "***",
      p_value < 0.05 ~ "**",
      p_value < 0.10 ~ "*",
      TRUE ~ ""
    ),
    estimate_stars = paste0(round(estimate, 4), stars)
  )

readr::write_csv(final_dml, "results/tables/03_dml_results.csv")

cat("\nDML replication completed.\n")
cat("Outputs saved in results/tables/.\n")
