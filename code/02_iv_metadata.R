################################################################################
# 02 — Metadata-based IV / 2SLS replication
#
# Metadata sheet used: IV
# Model: outcome ~ controls | municipality FE + year FE | treatment ~ instruments
################################################################################

source("R/00_functions.R")

required_iv <- c("lmtest", "sandwich")
install_missing(required_iv)
invisible(lapply(required_iv, library, character.only = TRUE))

panel <- load_panel()
panel <- add_standard_transforms(panel)

metadata <- read_metadata(sheet = "IV")
specs <- spec_columns(metadata)

models <- list()
coef_rows <- list()
diagnostics <- list()

for (sp in specs) {
  cat("\nIV:", sp, "\n")

  s <- get_spec(metadata, sp)

  y <- keep_existing(s$dependent, panel, sp, "dependent_var")
  d <- keep_existing(c(s$treatment, s$interaction), panel, sp, "independent_vars")
  z <- keep_existing(s$instruments, panel, sp, "instrument_vars")
  x <- keep_existing(s$controls, panel, sp, "control_vars")

  if (length(y) == 0 || length(d) == 0 || length(z) == 0) {
    cat("Skipped", sp, "- missing dependent, endogenous treatment or instruments.\n")
    next
  }

  y <- y[1]

  # fixest IV syntax:
  # y ~ controls | FE | endogenous ~ instruments
  controls_part <- safe_formula_part(x)
  endog_part <- safe_formula_part(d)
  instr_part <- safe_formula_part(z)

  fml <- as.formula(
    paste0(
      y, " ~ ", controls_part,
      " | PRO_COM + anno | ",
      endog_part, " ~ ", instr_part
    )
  )

  vars_used <- unique(c(y, d, z, x, "PRO_COM", "anno"))
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
      endogenous = paste(d, collapse = "; "),
      instruments = paste(z, collapse = "; "),
      model = "IV-2SLS-TWFE",
      n_obs = nobs(est)
    )

  # First-stage diagnostics from fixest, when available
  fs <- tryCatch(fixest::fitstat(est, ~ ivf1 + ivwald1), error = function(e) NULL)

  diagnostics[[sp]] <- data.frame(
    spec = sp,
    dependent = y,
    endogenous = paste(d, collapse = "; "),
    instruments = paste(z, collapse = "; "),
    n_obs = nobs(est),
    first_stage_diagnostics = ifelse(is.null(fs), NA_character_, paste(capture.output(print(fs)), collapse = " | "))
  )
}

if (length(models) == 0) {
  stop("No IV models estimated. Check metadata and panel variable names.")
}

modelsummary::modelsummary(
  models,
  output = "results/tables/02_iv_metadata.html",
  stars = TRUE,
  gof_omit = "IC|Log|Adj|Within|RMSE",
  notes = "Municipality and year fixed effects included. Standard errors clustered at municipality level."
)

iv_coef <- dplyr::bind_rows(coef_rows)
iv_diag <- dplyr::bind_rows(diagnostics)

readr::write_csv(iv_coef, "results/tables/02_iv_coefficients.csv")
readr::write_csv(iv_diag, "results/tables/02_iv_diagnostics.csv")

saveRDS(models, "results/tables/02_iv_models.rds")

cat("\nIV replication completed.\n")
cat("Outputs saved in results/tables/.\n")
