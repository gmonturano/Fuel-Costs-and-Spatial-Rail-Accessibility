################################################################################
# Shared functions for metadata-based replication
################################################################################

required_packages <- c(
  "dplyr", "readxl", "readr", "tibble", "stringr",
  "fixest", "modelsummary", "broom"
)

install_missing <- function(pkgs) {
  miss <- pkgs[!pkgs %in% rownames(installed.packages())]
  if (length(miss) > 0) install.packages(miss)
}

install_missing(required_packages)
invisible(lapply(required_packages, library, character.only = TRUE))

dir.create("results", showWarnings = FALSE)
dir.create("results/tables", recursive = TRUE, showWarnings = FALSE)

clean_panel_names <- function(x) {
  x <- gsub(" ", "_", x)
  x <- gsub("\\.", "_", x)
  x <- gsub("__+", "_", x)
  x
}

load_panel <- function(path = "data/processed/DB_finale_3SFCA_panel.RData") {
  if (!file.exists(path)) {
    stop(
      "Missing panel file: ", path, "\n",
      "Put DB_finale_3SFCA_panel.RData in data/processed/."
    )
  }

  env <- new.env(parent = emptyenv())
  load(path, envir = env)

  if (!exists("Access_norm", envir = env)) {
    stop("Object `Access_norm` not found inside ", path)
  }

  panel <- get("Access_norm", envir = env)
  names(panel) <- clean_panel_names(names(panel))

  panel <- panel |>
    dplyr::mutate(
      PRO_COM = as.character(PRO_COM),
      anno = as.integer(anno)
    )

  # Harmonise a few names used in the original scripts
  if ("Altitudine_del_centro_(metri)" %in% names(panel)) {
    names(panel)[names(panel) == "Altitudine_del_centro_(metri)"] <- "altitudine"
  }

  panel
}

read_metadata <- function(path = "data/metadata/Meta_fusco_dm.xlsx", sheet) {
  if (!file.exists(path)) {
    stop(
      "Missing metadata file: ", path, "\n",
      "Put Meta_fusco_dm.xlsx in data/metadata/."
    )
  }

  metadata <- readxl::read_xlsx(path, sheet = sheet)

  if (!"names.Panel." %in% names(metadata)) {
    stop("Column `names.Panel.` not found in metadata sheet: ", sheet)
  }

  names(metadata) <- clean_panel_names(names(metadata))
  names(metadata)[names(metadata) == "names_Panel_"] <- "names.Panel."

  metadata
}

spec_columns <- function(metadata) {
  grep("^Spec", names(metadata), value = TRUE)
}

get_spec <- function(metadata, spec) {
  get_vars <- function(label) {
    out <- metadata$names.Panel.[metadata[[spec]] == label]
    out <- out[!is.na(out)]
    out <- unique(as.character(out))
    out[out != ""]
  }

  list(
    dependent   = get_vars("dependent_var"),
    treatment   = get_vars("independent_vars"),
    controls    = get_vars("control_vars"),
    instruments = get_vars("instrument_vars"),
    interaction = get_vars("interaction")
  )
}

keep_existing <- function(vars, data, spec = NULL, role = NULL) {
  vars <- unique(as.character(vars))
  vars <- vars[!is.na(vars) & vars != ""]

  missing <- setdiff(vars, names(data))
  if (length(missing) > 0) {
    warning(
      "Missing variables",
      if (!is.null(role)) paste0(" [", role, "]") else "",
      if (!is.null(spec)) paste0(" in ", spec) else "",
      ": ",
      paste(missing, collapse = ", ")
    )
  }

  intersect(vars, names(data))
}

safe_formula_part <- function(vars) {
  vars <- unique(vars)
  vars <- vars[!is.na(vars) & vars != ""]
  if (length(vars) == 0) return("1")
  paste(vars, collapse = " + ")
}

add_standard_transforms <- function(panel) {
  # These are optional. They run only if the source variables exist.
  if ("Redditi_Procapite" %in% names(panel) && !"log_redditi_procapite" %in% names(panel)) {
    panel <- panel |>
      dplyr::mutate(
        log_redditi_procapite = ifelse(Redditi_Procapite > 0, log(Redditi_Procapite), NA_real_)
      )
  }

  if ("TOTALE_ESERCIZI_RICETTIVI" %in% names(panel) && !"log_esercizi_ricettivi" %in% names(panel)) {
    panel <- panel |>
      dplyr::mutate(
        log_esercizi_ricettivi = ifelse(TOTALE_ESERCIZI_RICETTIVI > 0, log(TOTALE_ESERCIZI_RICETTIVI), NA_real_)
      )
  }

  if ("Popolazione_fine_Totale_y" %in% names(panel) && !"log_popolazione" %in% names(panel)) {
    panel <- panel |>
      dplyr::mutate(
        log_popolazione = ifelse(Popolazione_fine_Totale_y > 0, log(Popolazione_fine_Totale_y), NA_real_)
      )
  }

  panel
}
