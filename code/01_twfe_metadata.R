################################################################################
# 01 — Metadata-based TWFE replication
#
# Metadata sheet used: GENERAL
# Model: outcome ~ treatment + controls | municipality FE + year FE
################################################################################

source("R/00_functions.R")

panel <- load_panel()
panel <- add_standard_transforms(panel)

metadata <- read_metadata(sheet = "GENERAL")
specs <- spec_columns(metadata)

models <- list()
coef_rows <- list()

for (sp in specs) {
  cat("\nTWFE:", sp, "\n")

  s <- get_spec(metadata, sp)

  y <- keep_existing(s$dependent, panel, sp, "dependent_var")
  d <- keep_existing(c(s$treatment, s$interaction), panel, sp, "independent_vars")
  x <- keep_existing(s$controls, panel, sp, "control_vars")

  if (length(y) == 0 || length(d) == 0) {
    cat("Skipped", sp, "- no dependent or treatment variable.\n")
    next
  }

  y <- y[1]
  rhs <- safe_formula_part(c(d, x))

  fml <- as.formula(
    paste0(y, " ~ ", rhs, " | PRO_COM + anno")
  )

  vars_used <- unique(c(y, d, x, "PRO_COM", "anno"))
  data_used <- panel |>
    dplyr::select(dplyr::all_of(vars_used)) |>
    tidyr::drop_na()

  if (nrow(data_used) < 100) {
    cat("Skipped", sp, "- too few complete observations:", nrow(data_used), "\n")
    next
  }

  est <- fixest::feols(
    fml,
    data = data_used,
    cluster = ~ PRO_COM,
    notes = FALSE
  )

  models[[sp]] <- est

  coef_rows[[sp]] <- broom::tidy(est, conf.int = TRUE) |>
    dplyr::mutate(
      spec = sp,
      dependent = y,
      model = "TWFE",
      n_obs = nobs(est)
    )
}

if (length(models) == 0) {
  stop("No TWFE models estimated. Check metadata and panel variable names.")
}

modelsummary::modelsummary(
  models,
  output = "results/tables/01_twfe_metadata.html",
  stars = TRUE,
  gof_omit = "IC|Log|Adj|Within|RMSE",
  notes = "Municipality and year fixed effects included. Standard errors clustered at municipality level."
)

twfe_coef <- dplyr::bind_rows(coef_rows)
readr::write_csv(twfe_coef, "results/tables/01_twfe_coefficients.csv")

saveRDS(models, "results/tables/01_twfe_models.rds")

cat("\nTWFE replication completed.\n")
cat("Outputs saved in results/tables/.\n")
