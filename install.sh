#!/usr/bin/env bash
# ==============================================================================
# PL/Nim - Native Nim Procedural Language Handler for PostgreSQL
# Automated Installation and Extension Deployment Tool
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Terminal Formatting & Logging
# ------------------------------------------------------------------------------
if [ -t 1 ]; then
  BOLD=$'\033[1m'
  GREEN=$'\033[0;32m'
  BLUE=$'\033[0;34m'
  YELLOW=$'\033[1;33m'
  RED=$'\033[0;31m'
  CYAN=$'\033[0;36m'
  RESET=$'\033[0m'
else
  BOLD=""
  GREEN=""
  BLUE=""
  YELLOW=""
  RED=""
  CYAN=""
  RESET=""
fi

log_info()    { echo -e "${BLUE}[INFO]${RESET} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${RESET} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# ------------------------------------------------------------------------------
# Default Configuration & Arguments
# ------------------------------------------------------------------------------
PRJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PRJ_DIR"

PG_CONFIG_BIN="${PG_CONFIG:-pg_config}"
TARGET_DB=""
SKIP_BUILD=false

print_usage() {
  cat << EOF
${BOLD}Usage:${RESET} $0 [OPTIONS] [DATABASE_NAME]

${BOLD}Options:${RESET}
  -d, --database <name>   PostgreSQL database name to register 'CREATE EXTENSION plnim;'
  -s, --skip-build        Skip nimble compilation; install existing artifacts only
  -c, --pg-config <path>  Specify path to pg_config executable
  -h, --help              Show this help message and exit

${BOLD}Examples:${RESET}
  $0
  $0 -d my_database
  $0 production_db
  $0 --pg-config /usr/lib/postgresql/16/bin/pg_config -d production_db
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--database)
      TARGET_DB="$2"
      shift 2
      ;;
    -s|--skip-build)
      SKIP_BUILD=true
      shift
      ;;
    -c|--pg-config)
      PG_CONFIG_BIN="$2"
      shift 2
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      if [ -z "$TARGET_DB" ]; then
        TARGET_DB="$1"
        shift
      else
        log_error "Unknown argument: $1"
        print_usage
        exit 1
      fi
      ;;
  esac
done

# ------------------------------------------------------------------------------
# Environment Validation
# ------------------------------------------------------------------------------
echo -e "${CYAN}==============================================================================${RESET}"
echo -e "${BOLD}👑 PL/Nim PostgreSQL Extension Installer${RESET}"
echo -e "${CYAN}==============================================================================${RESET}"

if ! command -v "$PG_CONFIG_BIN" >/dev/null 2>&1; then
  log_error "'$PG_CONFIG_BIN' not found in PATH."
  log_error "Please install PostgreSQL server development packages (e.g. postgresql-server-dev-<version>)"
  exit 1
fi

PG_VERSION="$("$PG_CONFIG_BIN" --version)"
PKGLIBDIR="$("$PG_CONFIG_BIN" --pkglibdir)"
SHAREDIR="$("$PG_CONFIG_BIN" --sharedir)"
EXTDIR="${SHAREDIR}/extension"

log_info "Detected PostgreSQL: ${BOLD}${PG_VERSION}${RESET}"
log_info "Library destination:  ${PKGLIBDIR}"
log_info "Extension directory:  ${EXTDIR}"

# Detect elevation requirements
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if [ ! -w "$PKGLIBDIR" ] || [ ! -w "$EXTDIR" ]; then
    log_info "Elevated permissions required for installation directories. Using sudo."
    SUDO="sudo"
  fi
fi

# ------------------------------------------------------------------------------
# 1. Build & Compile PL/Nim Shared Library
# ------------------------------------------------------------------------------
if [ "$SKIP_BUILD" = false ]; then
  if ! command -v nimble >/dev/null 2>&1; then
    log_error "'nimble' compiler tool not found in PATH. Please install Nim (>= 2.0.0)."
    exit 1
  fi

  log_info "Building and installing PL/Nim package via Nimble..."
  nimble install -y
  log_success "Build completed successfully."
else
  log_info "Skipping build step as requested."
fi

if [ ! -f "plnim.so" ]; then
  log_error "'plnim.so' binary was not found in '${PRJ_DIR}'. Build failed or artifact missing."
  exit 1
fi

# ------------------------------------------------------------------------------
# 2. Deploy Shared Library and Extension Specifications
# ------------------------------------------------------------------------------
log_info "Installing dynamic library into PostgreSQL..."
$SUDO cp -f "plnim.so" "$PKGLIBDIR/"

log_info "Deploying extension control and SQL definitions..."
$SUDO mkdir -p "$EXTDIR"
$SUDO cp -f "plnim.control" "$EXTDIR/"
$SUDO cp -f plnim*.sql "$EXTDIR/"

log_success "PL/Nim core files installed into PostgreSQL system tree."

# ------------------------------------------------------------------------------
# 3. Optional Database Extension Registration
# ------------------------------------------------------------------------------
if [ -n "$TARGET_DB" ]; then
  log_info "Registering extension in database '${TARGET_DB}'..."
  if command -v psql >/dev/null 2>&1; then
    psql -d "$TARGET_DB" -v ON_ERROR_STOP=1 -c "CREATE EXTENSION IF NOT EXISTS plnim;"
    log_success "Extension 'plnim' is now active in database '${TARGET_DB}'!"
  else
    log_warn "'psql' command not found. Please run the following command manually:"
    echo "  CREATE EXTENSION IF NOT EXISTS plnim;"
  fi
else
  echo ""
  log_success "Installation complete!"
  echo -e "To enable PL/Nim in any database, connect with superuser privileges and run:"
  echo -e "  ${BOLD}psql -d <your_database> -c \"CREATE EXTENSION plnim;\"${RESET}"
fi

echo -e "${CYAN}==============================================================================${RESET}"
