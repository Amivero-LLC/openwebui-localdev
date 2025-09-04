#!/usr/bin/env bash
# Enhanced LLM API Testing Tool
#
# Purpose
# - Test connectivity and responses from multiple LLM providers with modern UI
# - Beautiful output, streaming support, progress indicators, and comprehensive logging
# - Interactive file selection, connection health checks, and detailed analytics
#
# Maintainer Notes
# - Works with Bash 3.x and zsh
# - Auto-detects terminal capabilities and adjusts styling accordingly
# - Requires `api-testing/.env` (see `.env.example`)
# - DEBUG=1 for verbose logs; DEBUG=2 enables `set -x`
set -eu
# Enable pipefail when supported (bash/zsh)
if [ -n "${BASH_VERSION:-}" ]; then
  set -o pipefail
elif [ -n "${ZSH_VERSION:-}" ]; then
  set -o pipefail 2>/dev/null || setopt pipefail 2>/dev/null || true
else
  (set -o pipefail) 2>/dev/null && set -o pipefail || true
fi

# Ensure we run under a capable shell (bash or zsh)
if [ -z "${BASH_VERSION:-}" ] && [ -z "${ZSH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

# =====================================
# 🎨 ENHANCED UI SYSTEM
# =====================================

# Extended color palette with gradients and effects (portable: no associative arrays)
COLOR_RESET=$'\033[0m'
COLOR_BOLD=$'\033[1m'
COLOR_DIM=$'\033[2m'
COLOR_ITALIC=$'\033[3m'
COLOR_UNDERLINE=$'\033[4m'
COLOR_BLINK=$'\033[5m'
COLOR_REVERSE=$'\033[7m'
COLOR_STRIKE=$'\033[9m'

# Standard colors
BLACK=$'\033[30m'
RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
BLUE=$'\033[34m'
MAGENTA=$'\033[35m'
CYAN=$'\033[36m'
WHITE=$'\033[37m'

# Bright colors
BRIGHT_BLACK=$'\033[90m'
BRIGHT_RED=$'\033[91m'
BRIGHT_GREEN=$'\033[92m'
BRIGHT_YELLOW=$'\033[93m'
BRIGHT_BLUE=$'\033[94m'
BRIGHT_MAGENTA=$'\033[95m'
BRIGHT_CYAN=$'\033[96m'
BRIGHT_WHITE=$'\033[97m'

# Background colors
BG_BLACK=$'\033[40m'
BG_RED=$'\033[41m'
BG_GREEN=$'\033[42m'
BG_YELLOW=$'\033[43m'
BG_BLUE=$'\033[44m'
BG_MAGENTA=$'\033[45m'
BG_CYAN=$'\033[46m'
BG_WHITE=$'\033[47m'

# Bright backgrounds
BG_BRIGHT_BLACK=$'\033[100m'
BG_BRIGHT_RED=$'\033[101m'
BG_BRIGHT_GREEN=$'\033[102m'
BG_BRIGHT_YELLOW=$'\033[103m'
BG_BRIGHT_BLUE=$'\033[104m'
BG_BRIGHT_MAGENTA=$'\033[105m'
BG_BRIGHT_CYAN=$'\033[106m'
BG_BRIGHT_WHITE=$'\033[107m'

# Emojis are provided via a portable helper function (no associative arrays)

# Terminal capability detection
TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
TERM_HEIGHT=$(tput lines 2>/dev/null || echo 24)
USE_COLORS=0
USE_EMOJIS=0
USE_ANIMATIONS=0
SUPPORTS_UTF8=0

# Enhanced feature detection
detect_terminal_capabilities() {
  # Check if stdout/stderr are TTY
  if [ -t 1 ] && [ -t 2 ]; then
    USE_COLORS=1
    
    # Check for color support
    if command -v tput >/dev/null 2>&1; then
      local colors
      colors=$(tput colors 2>/dev/null || echo 0)
      [ "$colors" -ge 8 ] && USE_COLORS=1
    fi
    
    # Check UTF-8 support
    if [[ "${LANG:-}" =~ UTF-8 ]] || [[ "${LC_ALL:-}" =~ UTF-8 ]] || [[ "${LC_CTYPE:-}" =~ UTF-8 ]]; then
      USE_EMOJIS=1
      SUPPORTS_UTF8=1
    fi
    
    # Check for animation support (basic check for interactive terminals)
    if [ -n "${TERM:-}" ] && [[ ! "$TERM" =~ (dumb|unknown) ]]; then
      USE_ANIMATIONS=1
    fi
  fi
}

# Initialize terminal capabilities
detect_terminal_capabilities

# Enhanced color/emoji helper functions (portable)
c() {
  [ "$USE_COLORS" -eq 1 ] || return 0
  case "$1" in
    RESET) printf "%s" "$COLOR_RESET" ;;
    BOLD) printf "%s" "$COLOR_BOLD" ;;
    DIM) printf "%s" "$COLOR_DIM" ;;
    ITALIC) printf "%s" "$COLOR_ITALIC" ;;
    UNDERLINE) printf "%s" "$COLOR_UNDERLINE" ;;
    BLINK) printf "%s" "$COLOR_BLINK" ;;
    REVERSE) printf "%s" "$COLOR_REVERSE" ;;
    STRIKE) printf "%s" "$COLOR_STRIKE" ;;
    BLACK) printf "%s" "$BLACK" ;;
    RED) printf "%s" "$RED" ;;
    GREEN) printf "%s" "$GREEN" ;;
    YELLOW) printf "%s" "$YELLOW" ;;
    BLUE) printf "%s" "$BLUE" ;;
    MAGENTA) printf "%s" "$MAGENTA" ;;
    CYAN) printf "%s" "$CYAN" ;;
    WHITE) printf "%s" "$WHITE" ;;
    BRIGHT_BLACK) printf "%s" "$BRIGHT_BLACK" ;;
    BRIGHT_RED) printf "%s" "$BRIGHT_RED" ;;
    BRIGHT_GREEN) printf "%s" "$BRIGHT_GREEN" ;;
    BRIGHT_YELLOW) printf "%s" "$BRIGHT_YELLOW" ;;
    BRIGHT_BLUE) printf "%s" "$BRIGHT_BLUE" ;;
    BRIGHT_MAGENTA) printf "%s" "$BRIGHT_MAGENTA" ;;
    BRIGHT_CYAN) printf "%s" "$BRIGHT_CYAN" ;;
    BRIGHT_WHITE) printf "%s" "$BRIGHT_WHITE" ;;
    BG_BLACK) printf "%s" "$BG_BLACK" ;;
    BG_RED) printf "%s" "$BG_RED" ;;
    BG_GREEN) printf "%s" "$BG_GREEN" ;;
    BG_YELLOW) printf "%s" "$BG_YELLOW" ;;
    BG_BLUE) printf "%s" "$BG_BLUE" ;;
    BG_MAGENTA) printf "%s" "$BG_MAGENTA" ;;
    BG_CYAN) printf "%s" "$BG_CYAN" ;;
    BG_WHITE) printf "%s" "$BG_WHITE" ;;
    BG_BRIGHT_BLACK) printf "%s" "$BG_BRIGHT_BLACK" ;;
    BG_BRIGHT_RED) printf "%s" "$BG_BRIGHT_RED" ;;
    BG_BRIGHT_GREEN) printf "%s" "$BG_BRIGHT_GREEN" ;;
    BG_BRIGHT_YELLOW) printf "%s" "$BG_BRIGHT_YELLOW" ;;
    BG_BRIGHT_BLUE) printf "%s" "$BG_BRIGHT_BLUE" ;;
    BG_BRIGHT_MAGENTA) printf "%s" "$BG_BRIGHT_MAGENTA" ;;
    BG_BRIGHT_CYAN) printf "%s" "$BG_BRIGHT_CYAN" ;;
    BG_BRIGHT_WHITE) printf "%s" "$BG_BRIGHT_WHITE" ;;
  esac
}

e() {
  [ "$USE_EMOJIS" -eq 1 ] || return 0
  case "$1" in
    ROCKET) printf "🚀 " ;;
    CHECK) printf "✅ " ;;
    ERROR) printf "❌ " ;;
    WARNING) printf "⚠️ " ;;
    INFO) printf "ℹ️ " ;;
    SUCCESS) printf "🎉 " ;;
    LOADING) printf "⏳ " ;;
    CLOCK) printf "⏰ " ;;
    STOPWATCH) printf "⏱️ " ;;
    COMPUTER) printf "💻 " ;;
    ROBOT) printf "🤖 " ;;
    GEAR) printf "⚙️ " ;;
    WRENCH) printf "🔧 " ;;
    HAMMER) printf "🔨 " ;;
    TOOLBOX) printf "🧰 " ;;
    MICROSCOPE) printf "🔬 " ;;
    GLOBE) printf "🌐 " ;;
    SATELLITE) printf "📡 " ;;
    ANTENNA|WIFI) printf "📶 " ;;
    LINK|CHAIN) printf "🔗 " ;;
    BRIDGE) printf "🌉 " ;;
    KEY) printf "🔑 " ;;
    LOCK) printf "🔒 " ;;
    UNLOCK) printf "🔓 " ;;
    SHIELD|SECURITY) printf "🛡️ " ;;
    PLAY) printf "▶️ " ;;
    PAUSE) printf "⏸️ " ;;
    STOP) printf "⏹️ " ;;
    UPLOAD) printf "⬆️ " ;;
    DOWNLOAD) printf "⬇️ " ;;
    REFRESH|SYNC) printf "🔄 " ;;
    SPEECH) printf "💬 " ;;
    MESSAGE) printf "💌 " ;;
    ENVELOPE) printf "📧 " ;;
    MEGAPHONE|BULLHORN) printf "📢 " ;;
    FILE) printf "📄 " ;;
    FOLDER) printf "📁 " ;;
    PACKAGE|BOX) printf "📦 " ;;
    ARCHIVE|DATABASE) printf "🗄️ " ;;
    STAR) printf "⭐ " ;;
    SPARKLES) printf "✨ " ;;
    FIRE) printf "🔥 " ;;
    ZAP|LIGHTNING) printf "⚡ " ;;
    BOOM) printf "💥 " ;;
    DIAMOND|GEM) printf "💎 " ;;
    TARGET) printf "🎯 " ;;
    COMPASS) printf "🧭 " ;;
    SEARCH|MAGNIFYING) printf "🔍 " ;;
    TELESCOPE) printf "🔭 " ;;
    CHART_UP) printf "📈 " ;;
    CHART_DOWN) printf "📉 " ;;
    BAR_CHART|PIE_CHART) printf "📊 " ;;
    THINKING) printf "🤔 " ;;
    QUESTION) printf "❓ " ;;
    EXCLAMATION) printf "❗ " ;;
    IDEA) printf "💡 " ;;
    BRAIN) printf "🧠 " ;;
    MAGIC) printf "🪄 " ;;
    CRYSTAL) printf "🔮 " ;;
    RAINBOW) printf "🌈 " ;;
    COMET) printf "☄️ " ;;
    METEOR) printf "🌠 " ;;
  esac
}

# Progress bar function
show_progress() {
  local current="$1"
  local total="$2"
  local width=40
  local percentage=$((current * 100 / total))
  local filled=$((current * width / total))
  local empty=$((width - filled))
  
  printf "\r$(c BRIGHT_CYAN)["
  printf "%*s" "$filled" | tr ' ' '█'
  printf "%*s" "$empty" | tr ' ' '░'
  printf "] %d%% (%d/%d)$(c RESET)" "$percentage" "$current" "$total"
}

# Spinner animation
show_spinner() {
  local pid="$1"
  local message="${2:-Working...}"
  local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local temp
  
  if [ "$USE_ANIMATIONS" -eq 0 ]; then
    printf "$(c BRIGHT_CYAN)$(e LOADING)%s$(c RESET)\n" "$message"
    return
  fi
  
  printf "$(c BRIGHT_CYAN)"
  while kill -0 "$pid" 2>/dev/null; do
    temp=${spinstr#?}
    printf "\r$(e LOADING)%s %c" "$message" "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep 0.1
  done
  printf "\r$(e CHECK)%s ✓$(c RESET)\n" "$message"
}

# =====================================
# 📐 ENHANCED LAYOUT FUNCTIONS
# =====================================

# Box drawing characters (portable variables)
BOX_TL="╭"  # top-left
BOX_TR="╮"  # top-right
BOX_BL="╰"  # bottom-left
BOX_BR="╯"  # bottom-right
BOX_H="─"   # horizontal
BOX_V="│"   # vertical
BOX_T="┬"   # top junction
BOX_B="┴"   # bottom junction
BOX_L="├"   # left junction
BOX_R="┤"   # right junction
BOX_X="┼"   # cross junction

# Fallback for non-UTF8 terminals
if [ "$SUPPORTS_UTF8" -eq 0 ]; then
  BOX_TL="+"
  BOX_TR="+"
  BOX_BL="+"
  BOX_BR="+"
  BOX_H="-"
  BOX_V="|"
  BOX_T="+"
  BOX_B="+"
  BOX_L="+"
  BOX_R="+"
  BOX_X="+"
fi

# Draw a box around content
draw_box() {
  local title="$1"
  local content="$2"
  local width="${3:-60}"
  local color="${4:-BRIGHT_CYAN}"
  
  # Calculate dimensions
  local title_len=${#title}
  local content_width=$((width - 4))
  
  # Top border with title
  printf "$(c "$color")%s" "$BOX_TL"
  if [ -n "$title" ]; then
    local padding=$(( (width - title_len - 4) / 2 ))
    printf "%*s %s %*s" "$padding" "" "$title" "$padding" "" | tr ' ' "$BOX_H"
  else
    printf "%*s" "$((width - 2))" "" | tr ' ' "$BOX_H"
  fi
  printf "%s$(c RESET)\n" "$BOX_TR"
  
  # Content
  if [ -n "$content" ]; then
    printf "%s" "$content" | while IFS= read -r line; do
      printf "$(c "$color")%s$(c RESET) %-*s $(c "$color")%s$(c RESET)\n" "$BOX_V" "$content_width" "$line" "$BOX_V"
    done
  fi
  
  # Bottom border
  printf "$(c "$color")%s%*s%s$(c RESET)\n" "$BOX_BL" "$((width - 2))" "" "$BOX_BR" | tr ' ' "$BOX_H"
}

# Enhanced header with gradient effect
print_header() {
  local title="$1"
  local subtitle="${2:-}"
  local width=80
  
  printf "\n"
  
  # Main title with decorative border
  printf "$(c BRIGHT_MAGENTA)$(c BOLD)"
  printf "╔%*s╗\n" $((width - 2)) "" | tr ' ' '═'
  printf "║%*s║\n" $((width - 2)) ""
  
  # Center the title
  local title_padding=$(( (width - ${#title} - 2) / 2 ))
  printf "║%*s$(c BRIGHT_WHITE)%s$(c BRIGHT_MAGENTA)%*s║\n" \
    "$title_padding" "" "$title" "$title_padding" ""
  
  if [ -n "$subtitle" ]; then
    local subtitle_padding=$(( (width - ${#subtitle} - 2) / 2 ))
    printf "║%*s$(c BRIGHT_CYAN)%s$(c BRIGHT_MAGENTA)%*s║\n" \
      "$subtitle_padding" "" "$subtitle" "$subtitle_padding" ""
  fi
  
  printf "║%*s║\n" $((width - 2)) ""
  printf "╚%*s╝$(c RESET)\n" $((width - 2)) "" | tr ' ' '═'
  printf "\n"
}

# Section headers with improved styling
print_section() {
  local title="$1"
  local emoji="${2:-PACKAGE}"
  local color="${3:-BRIGHT_BLUE}"
  
  printf "\n$(c "$color")$(c BOLD)$(e "$emoji")%s$(c RESET)\n" "$title"
  printf "$(c "$color")%s$(c RESET)\n" "$(printf '▔%.0s' $(seq 1 ${#title}))"
}

# Status indicators with consistent styling
print_status() {
  local status="$1"
  local message="$2"
  local color=""
  local emoji=""
  
  case "$status" in
    "success"|"ok"|"pass")
      color="BRIGHT_GREEN"
      emoji="CHECK"
      ;;
    "error"|"fail"|"failed")
      color="BRIGHT_RED"
      emoji="ERROR"
      ;;
    "warning"|"warn")
      color="BRIGHT_YELLOW"
      emoji="WARNING"
      ;;
    "info"|"information")
      color="BRIGHT_CYAN"
      emoji="INFO"
      ;;
    "loading"|"working")
      color="BRIGHT_BLUE"
      emoji="LOADING"
      ;;
    *)
      color="WHITE"
      emoji="INFO"
      ;;
  esac
  
  printf "$(c "$color")$(c BOLD)$(e "$emoji")%s$(c RESET)\n" "$message"
}

# Enhanced key-value display with better alignment
print_kv() {
  local key="$1"
  local value="$2"
  local emoji="${3:-}"
  local indent="${4:-2}"
  local key_width="${5:-20}"
  
  local indent_str=""
  [ "$indent" -gt 0 ] && indent_str="$(printf '%*s' "$indent" "")"
  
  if [ -n "$emoji" ]; then
    printf "%s$(c CYAN)$(e "$emoji")%-*s$(c RESET) $(c BRIGHT_WHITE)%s$(c RESET)\n" \
      "$indent_str" "$key_width" "$key:" "$value"
  else
    printf "%s$(c CYAN)%-*s$(c RESET) $(c BRIGHT_WHITE)%s$(c RESET)\n" \
      "$indent_str" "$key_width" "$key:" "$value"
  fi
}

# Progress step indicator
print_step() {
  local step_num="$1"
  local total_steps="$2"
  local description="$3"
  local status="${4:-active}"  # active, complete, pending, error
  
  local color=""
  local emoji=""
  
  case "$status" in
    "complete")
      color="BRIGHT_GREEN"
      emoji="CHECK"
      ;;
    "active")
      color="BRIGHT_BLUE"
      emoji="ROCKET"
      ;;
    "pending")
      color="DIM"
      emoji="CLOCK"
      ;;
    "error")
      color="BRIGHT_RED"
      emoji="ERROR"
      ;;
  esac
  
  printf "$(c "$color")$(c BOLD)[%d/%d]$(c RESET) $(c "$color")$(e "$emoji")%s$(c RESET)\n" \
    "$step_num" "$total_steps" "$description"
}

# Collapsible section (simulated with indentation)
print_collapsible() {
  local title="$1"
  local content="$2"
  local expanded="${3:-1}"  # 1=expanded, 0=collapsed
  
  if [ "$expanded" -eq 1 ]; then
    printf "$(c BRIGHT_WHITE)$(c BOLD)▼ %s$(c RESET)\n" "$title"
    printf "%s" "$content" | sed 's/^/  /'
  else
    printf "$(c BRIGHT_WHITE)$(c BOLD)▶ %s$(c RESET) $(c DIM)(collapsed)$(c RESET)\n" "$title"
  fi
}

# Table formatting
print_table_header() {
  local -a headers=("$@")
  local total_width=0
  local col_width=20
  
  printf "$(c BRIGHT_CYAN)$(c BOLD)"
  for header in "${headers[@]}"; do
    printf "%-*s " "$col_width" "$header"
    total_width=$((total_width + col_width + 1))
  done
  printf "$(c RESET)\n"
  
  printf "$(c CYAN)"
  printf "%*s" "$total_width" "" | tr ' ' '─'
  printf "$(c RESET)\n"
}

print_table_row() {
  local -a cells=("$@")
  local col_width=20
  
  for cell in "${cells[@]}"; do
    printf "%-*s " "$col_width" "$cell"
  done
  printf "\n"
}

# =====================================
# 🔧 CORE FUNCTIONALITY (ENHANCED)
# =====================================

# Enhanced environment loading with validation
load_environment() {
  print_section "Environment Configuration" "GEAR" "BRIGHT_MAGENTA"
  
  local script_dir="$(dirname "$0")"
  local env_file="$script_dir/.env"
  
  if [ ! -f "$env_file" ]; then
    print_status "error" "Environment file missing: $env_file"
    printf "\n$(c BRIGHT_YELLOW)$(e IDEA)Quick Setup:$(c RESET)\n"
    printf "  $(c WHITE)1.$(c RESET) Copy the example file: $(c CYAN)cp $script_dir/.env.example $env_file$(c RESET)\n"
    printf "  $(c WHITE)2.$(c RESET) Edit the configuration: $(c CYAN)nano $env_file$(c RESET)\n"
    printf "  $(c WHITE)3.$(c RESET) Run the script again\n\n"
    exit 1
  fi
  
  print_step 1 3 "Loading environment variables" "active"
  
  # Load with validation
  set -a
  # shellcheck source=/dev/null
  source "$env_file"
  set +a
  
  print_step 2 3 "Validating configuration" "active"
  
  # Validate required variables
  local missing_vars=()
  local required_vars=(
    "MAX_TOKENS"
    "TEMPERATURE"
  )
  
  for var in "${required_vars[@]}"; do
    if [ -z "${!var:-}" ]; then
      missing_vars+=("$var")
    fi
  done
  
  if [ ${#missing_vars[@]} -gt 0 ]; then
    print_step 3 3 "Configuration validation" "error"
    print_status "error" "Missing required environment variables:"
    for var in "${missing_vars[@]}"; do
      printf "  $(c BRIGHT_RED)$(e ERROR)%s$(c RESET)\n" "$var"
    done
    exit 1
  fi
  
  print_step 3 3 "Environment ready" "complete"
  print_status "success" "Configuration loaded and validated"
}

# Enhanced connection health check
check_connection_health() {
  local target="$1"
  local base_url="$2"
  
  print_section "Connection Health Check" "ANTENNA" "BRIGHT_GREEN"
  
  # DNS resolution check
  print_step 1 4 "Checking DNS resolution" "active"
  local hostname
  hostname=$(echo "$base_url" | sed -E 's|https?://([^/]+).*|\1|')
  
  if command -v nslookup >/dev/null 2>&1; then
    if nslookup "$hostname" >/dev/null 2>&1; then
      print_step 1 4 "DNS resolution" "complete"
    else
      print_step 1 4 "DNS resolution failed" "error"
      return 1
    fi
  else
    print_step 1 4 "DNS check skipped (nslookup not available)" "pending"
  fi
  
  # Connectivity check
  print_step 2 4 "Testing connectivity" "active"
  if command -v curl >/dev/null 2>&1; then
    local curl_insecure=""
    [ "$INSECURE_FLAG" -eq 1 ] && curl_insecure="-k"
    if curl -s $curl_insecure --connect-timeout 5 "$base_url" >/dev/null 2>&1; then
      print_step 2 4 "Connectivity established" "complete"
    else
      print_step 2 4 "Connection failed" "error"
      return 1
    fi
  else
    print_status "error" "curl is required but not installed"
    return 1
  fi
  
  # SSL certificate check (for HTTPS)
  if [[ "$base_url" =~ ^https:// ]]; then
    print_step 3 4 "Verifying SSL certificate" "active"
    if [ "$INSECURE_FLAG" -eq 1 ]; then
      print_step 3 4 "SSL check skipped (insecure mode)" "pending"
    else
      # --cert-status enables OCSP; many servers don’t respond to it. If it fails,
      # fall back to a simple TLS negotiation check.
      if curl -s --connect-timeout 5 --cert-status "$base_url" >/dev/null 2>&1 \
         || curl -s --connect-timeout 5 -I "$base_url" >/dev/null 2>&1; then
        print_step 3 4 "SSL certificate valid" "complete"
      else
        print_step 3 4 "SSL certificate issues detected" "error"
        return 1
      fi
    fi
  else
    print_step 3 4 "SSL check skipped (HTTP connection)" "pending"
  fi
  
  print_step 4 4 "Health check complete" "complete"
  return 0
}

# Enhanced connection setup with health checks
setup_connection() {
  local target="$1"
  
  print_section "Connection Setup" "LINK" "BRIGHT_BLUE"
  
  case "$target" in
    openwebui)
      print_kv "Provider" "OpenWebUI" "COMPUTER" 2 15
      check_required_vars "OPENWEBUI_BASE_URL" "OPENWEBUI_API_KEY"
      BASE_URL="$OPENWEBUI_BASE_URL"
      API_KEY="$OPENWEBUI_API_KEY"
      MODEL="${OPENWEBUI_MODEL:-${BEDROCK_BASE_MODEL_ID:-$MODEL}}"
      ;;
    bag)
      print_kv "Provider" "Bedrock Access Gateway" "CHAIN" 2 15
      check_required_vars "BAG_BASE_URL" "BAG_API_KEY"
      BASE_URL="$BAG_BASE_URL"
      API_KEY="$BAG_API_KEY"
      MODEL="${BAG_MODEL:-${BEDROCK_BASE_MODEL_ID:-$MODEL}}"
      ;;
    aws)
      print_kv "Provider" "AWS Bedrock Direct" "SHIELD" 2 15
      check_required_vars "AWS_REGION" "AWS_BEARER_TOKEN_BEDROCK"
      MODEL="${BEDROCK_BASE_MODEL_ID:-$MODEL}"
      BASE_URL="https://bedrock-runtime.${AWS_REGION}.amazonaws.com"
      API_KEY="$AWS_BEARER_TOKEN_BEDROCK"
      if [ "$STREAM_FLAG" -eq 1 ]; then
        print_status "warning" "Streaming not supported for AWS Direct - disabling"
        STREAM_FLAG=0
      fi
      ;;
    openai)
      print_kv "Provider" "OpenAI Direct" "ROBOT" 2 15
      check_required_vars "OPENAI_DIRECT_BASE_URL" "OPENAI_DIRECT_API_KEY"
      BASE_URL="$OPENAI_DIRECT_BASE_URL"
      API_KEY="$OPENAI_DIRECT_API_KEY"
      MODEL="${OPENAI_DIRECT_MODEL:-${MODEL:-gpt-4o-mini}}"
      ;;
    *)
      print_status "error" "Unknown connection target: $target"
      exit 1
      ;;
  esac
  
  # Set endpoint URL
  if [ "$target" = "aws" ]; then
    URL="${BASE_URL%/}/model/${MODEL}/converse"
  else
    URL="${BASE_URL%/}/chat/completions"
  fi
  
  # Perform health check only in debug mode; stay silent otherwise
  if [ "${DEBUG:-0}" -ge 1 ]; then
    if check_connection_health "$target" "$BASE_URL"; then
      print_status "success" "Connection setup complete and healthy"
    else
      print_status "warning" "Health check reported issues; proceeding anyway"
    fi
  fi
}

# Helper function to check required variables
check_required_vars() {
  local missing=()
  
  for var in "$@"; do
    if [ -z "${!var:-}" ]; then
      missing+=("$var")
    fi
  done
  
  if [ ${#missing[@]} -gt 0 ]; then
    print_status "error" "Missing required environment variables for this provider:"
    for var in "${missing[@]}"; do
      printf "  $(c BRIGHT_RED)$(e ERROR)%s$(c RESET)\n" "$var"
    done
    exit 1
  fi
}

# Enhanced interactive connection selection with visual status (Bash 3 compatible)
select_connection() {
  print_section "Provider Selection" "TARGET" "BRIGHT_MAGENTA"
  
  # Check provider availability using individual variables
  local openwebui_available=0
  local bag_available=0
  local aws_available=0
  local openai_available=0
  
  [ -n "${OPENWEBUI_BASE_URL:-}" ] && [ -n "${OPENWEBUI_API_KEY:-}" ] && openwebui_available=1
  [ -n "${BAG_BASE_URL:-}" ] && [ -n "${BAG_API_KEY:-}" ] && bag_available=1
  [ -n "${AWS_REGION:-}" ] && [ -n "${AWS_BEARER_TOKEN_BEDROCK:-}" ] && aws_available=1
  [ -n "${OPENAI_DIRECT_BASE_URL:-}" ] && [ -n "${OPENAI_DIRECT_API_KEY:-}" ] && openai_available=1
  
  # Display options in a table format
  printf "\n$(c BRIGHT_WHITE)$(c BOLD)Available Providers:$(c RESET)\n\n"
  
  print_table_header "Option" "Provider" "Status" "Description"
  
  # Show each provider option
  printf "$(c BRIGHT_CYAN)1$(c RESET)    $(e COMPUTER)%-15s " "OpenWebUI"
  if [ "$openwebui_available" -eq 1 ]; then
    printf "$(c BRIGHT_GREEN)Available$(c RESET)      "
  else
    printf "$(c DIM)Not Configured$(c RESET)  "
  fi
  printf "Local OpenWebUI instance\n"
  
  printf "$(c BRIGHT_CYAN)2$(c RESET)    $(e CHAIN)%-15s " "Bedrock Gateway"
  if [ "$bag_available" -eq 1 ]; then
    printf "$(c BRIGHT_GREEN)Available$(c RESET)      "
  else
    printf "$(c DIM)Not Configured$(c RESET)  "
  fi
  printf "Bedrock Access Gateway\n"
  
  printf "$(c BRIGHT_CYAN)3$(c RESET)    $(e SHIELD)%-15s " "AWS Bedrock"
  if [ "$aws_available" -eq 1 ]; then
    printf "$(c BRIGHT_GREEN)Available$(c RESET)      "
  else
    printf "$(c DIM)Not Configured$(c RESET)  "
  fi
  printf "Direct AWS Bedrock API\n"
  
  printf "$(c BRIGHT_CYAN)4$(c RESET)    $(e ROBOT)%-15s " "OpenAI"
  if [ "$openai_available" -eq 1 ]; then
    printf "$(c BRIGHT_GREEN)Available$(c RESET)      "
  else
    printf "$(c DIM)Not Configured$(c RESET)  "
  fi
  printf "Direct OpenAI API\n"
  
  # Find default (first available)
  local default_option=1
  if [ "$openwebui_available" -eq 1 ]; then
    default_option=1
  elif [ "$bag_available" -eq 1 ]; then
    default_option=2
  elif [ "$aws_available" -eq 1 ]; then
    default_option=3
  elif [ "$openai_available" -eq 1 ]; then
    default_option=4
  fi
  
  # Get user selection
  if [ -t 0 ]; then
    printf "\n"
    while :; do
      printf "%s" "$(c BRIGHT_WHITE)$(e THINKING)Select provider [1-4] (default: $default_option): $(c RESET)"
      read -r sel || true
      sel=${sel:-$default_option}
      
      if [[ "$sel" =~ ^[1-4]$ ]]; then
        # Check if selected provider is available
        local selected_available=0
        case "$sel" in
          1) selected_available=$openwebui_available; API_TEST_TARGET="openwebui" ;;
          2) selected_available=$bag_available; API_TEST_TARGET="bag" ;;
          3) selected_available=$aws_available; API_TEST_TARGET="aws" ;;
          4) selected_available=$openai_available; API_TEST_TARGET="openai" ;;
        esac
        
        if [ "$selected_available" -eq 1 ]; then
          break
        else
          print_status "warning" "Selected provider is not configured. Please choose an available provider."
        fi
      else
        print_status "warning" "Please enter a valid option (1-4)"
      fi
    done
  else
    # Non-interactive mode - use first available
    if [ "$openwebui_available" -eq 1 ]; then
      API_TEST_TARGET="openwebui"
    elif [ "$bag_available" -eq 1 ]; then
      API_TEST_TARGET="bag"
    elif [ "$aws_available" -eq 1 ]; then
      API_TEST_TARGET="aws"
    elif [ "$openai_available" -eq 1 ]; then
      API_TEST_TARGET="openai"
    else
      API_TEST_TARGET="openwebui"  # Fallback
    fi
  fi
  
  print_status "info" "Selected provider: $API_TEST_TARGET"
}

# Enhanced settings display with better organization
display_settings() {
  print_section "Configuration Summary" "SETTINGS" "BRIGHT_CYAN"
  
  # Connection details
  printf "$(c BRIGHT_WHITE)$(c BOLD)Connection Details:$(c RESET)\n"
  print_kv "Provider" "$(get_provider_display_name "$API_TEST_TARGET")" "TARGET" 2 15
  print_kv "Model" "$MODEL" "ROBOT" 2 15
  print_kv "Base URL" "$BASE_URL" "GLOBE" 2 15
  print_kv "Endpoint" "$(truncate_url "$URL" 50)" "LINK" 2 15
  
  # Request parameters
  printf "\n$(c BRIGHT_WHITE)$(c BOLD)Request Parameters:$(c RESET)\n"
  print_kv "Max Tokens" "$MAX_TOKENS" "PACKAGE" 2 15
  print_kv "Temperature" "$TEMPERATURE" "FIRE" 2 15
  print_kv "Streaming" "$([ "$STREAM_FLAG" -eq 1 ] && echo "$(c BRIGHT_GREEN)Enabled$(c RESET)" || echo "$(c DIM)Disabled$(c RESET)")" "ZAP" 2 15
  
  # Security
  printf "\n$(c BRIGHT_WHITE)$(c BOLD)Security:$(c RESET)\n"
  local masked_key=$(mask_api_key "$API_KEY")
  print_kv "Auth Key" "$masked_key" "KEY" 2 15
  
  # Content
  if [ -n "${USER_MESSAGE:-}" ]; then
    printf "\n$(c BRIGHT_WHITE)$(c BOLD)Content:$(c RESET)\n"
    local truncated_message=$(truncate_text "$USER_MESSAGE" 80)
    print_kv "Prompt" "$truncated_message" "SPEECH" 2 15
  fi
  
  if [ "$INCLUDE_FILE_FLAG" -eq 1 ]; then
    local file_label="file"
    [ "${FILE_SELECTED_COUNT:-0}" -ne 1 ] && file_label="files"
    print_kv "Attachments" "${FILE_SELECTED_COUNT:-0} $file_label" "FILE" 2 15
    
    if [ "${FILE_SELECTED_COUNT:-0}" -gt 0 ] && [ -n "${SELECTED_FILES_FILE:-}" ] && [ -f "$SELECTED_FILES_FILE" ]; then
      local count=1
      while IFS= read -r file_path; do
        [ -z "$file_path" ] && continue
        local filename=$(basename "$file_path")
        local filesize=$(get_file_size "$file_path")
        printf "  $(c CYAN)$(e FILE)File $count:$(c RESET) $(c BRIGHT_WHITE)$filename$(c RESET) $(c DIM)($filesize)$(c RESET)\n"
        ((count++))
      done < "$SELECTED_FILES_FILE"
    fi
  else
    print_kv "Attachments" "None" "FILE" 2 15
  fi
}

# Helper functions for display
get_provider_display_name() {
  case "$1" in
    openwebui) echo "OpenWebUI" ;;
    bag) echo "Bedrock Access Gateway" ;;
    aws) echo "AWS Bedrock Direct" ;;
    openai) echo "OpenAI Direct" ;;
    *) echo "$1" ;;
  esac
}

truncate_url() {
  local url="$1"
  local max_len="$2"
  
  if [ ${#url} -le "$max_len" ]; then
    echo "$url"
  else
    echo "${url:0:$((max_len-3))}..."
  fi
}

truncate_text() {
  local text="$1"
  local max_len="$2"
  
  if [ ${#text} -le "$max_len" ]; then
    echo "$text"
  else
    echo "${text:0:$((max_len-3))}..."
  fi
}

mask_api_key() {
  local key="$1"
  local key_len=${#key}
  
  if [ "$key_len" -le 8 ]; then
    echo "****"
  else
    echo "${key:0:4}***${key: -4}"
  fi
}

get_file_size() {
  local file="$1"
  if [ -f "$file" ]; then
    if command -v stat >/dev/null 2>&1; then
      local size
      if stat -c%s "$file" >/dev/null 2>&1; then
        size=$(stat -c%s "$file")
      else
        size=$(stat -f%z "$file" 2>/dev/null || echo "0")
      fi
      format_file_size "$size"
    else
      echo "unknown size"
    fi
  else
    echo "not found"
  fi
}

format_file_size() {
  local size="$1"
  
  if [ "$size" -lt 1024 ]; then
    echo "${size}B"
  elif [ "$size" -lt 1048576 ]; then
    echo "$((size / 1024))KB"
  else
    echo "$((size / 1048576))MB"
  fi
}

# Enhanced request execution with detailed progress
execute_request() {
  local user_message="$1"
  
  print_section "Request Execution" "ROCKET" "BRIGHT_GREEN"
  
  # Step 1: Build payload
  print_step 1 4 "Building request payload" "active"
  local payload
  payload=$(build_request_payload "$user_message")
  
  if [ $? -eq 0 ]; then
    print_step 1 4 "Request payload built" "complete"
  else
    print_step 1 4 "Failed to build payload" "error"
    exit 1
  fi
  
  # Step 2: Show request preview
  print_step 2 4 "Preparing request" "active"
  show_request_preview "$payload"
  print_step 2 4 "Request prepared" "complete"
  
  # Step 3: Execute request
  print_step 3 4 "Sending request" "active"
  local start_time=$(date +%s.%N 2>/dev/null || date +%s)
  
  if [ "$STREAM_FLAG" -eq 1 ]; then
    execute_streaming_request "$payload"
  else
    execute_non_streaming_request "$payload"
  fi
  
  local end_time=$(date +%s.%N 2>/dev/null || date +%s)
  local duration
  if command -v bc >/dev/null 2>&1; then
    duration=$(echo "$end_time - $start_time" | bc)
  else
    duration=$((${end_time%.*} - ${start_time%.*}))
  fi
  
  print_step 3 4 "Request completed" "complete"
  
  # Step 4: Show metrics
  print_step 4 4 "Analyzing response" "active"
  show_response_metrics "$duration"
  print_step 4 4 "Analysis complete" "complete"
}

# Build request payload with enhanced error handling
build_request_payload() {
  local user_message="$1"
  local payload=""
  
  if command -v jq >/dev/null 2>&1; then
    # Use jq for reliable JSON construction
    local stream_bool
    stream_bool=$([ "$STREAM_FLAG" -eq 1 ] && echo "true" || echo "false")
    
    if [ "$API_TEST_TARGET" = "aws" ]; then
      # AWS Bedrock format
      payload=$(jq -n \
        --arg user "$user_message" \
        --argjson max_tokens "$MAX_TOKENS" \
        --argjson temperature "$TEMPERATURE" \
        '{
          system: [{text: "You are a helpful assistant."}],
          messages: [
            {role: "user", content: [{text: $user}]}
          ],
          inferenceConfig: {
            maxTokens: $max_tokens,
            temperature: $temperature
          }
        }')
    else
      # OpenAI-compatible format
      payload=$(jq -n \
        --arg model "$MODEL" \
        --argjson max_tokens "$MAX_TOKENS" \
        --argjson temperature "$TEMPERATURE" \
        --argjson stream "$stream_bool" \
        --arg user "$user_message" \
        '{
          model: $model,
          max_tokens: $max_tokens,
          temperature: $temperature,
          stream: $stream,
          messages: [
            {role: "system", content: "You are a helpful assistant."},
            {role: "user", content: $user}
          ]
        }')
    fi
    
    # Add file attachments if present
    if [ "$INCLUDE_FILE_FLAG" -eq 1 ] && [ "${FILE_SELECTED_COUNT:-0}" -gt 0 ] && [ -n "${SELECTED_FILES_FILE:-}" ] && [ -f "$SELECTED_FILES_FILE" ]; then
      while IFS= read -r file_path; do
        [ -z "$file_path" ] && continue
        local filename content
        filename=$(basename "$file_path")
        content=$(cat "$file_path")
        
        if [ "$API_TEST_TARGET" = "aws" ]; then
          payload=$(echo "$payload" | jq \
            --arg name "$filename" \
            --arg text "$content" \
            '.messages += [{role: "user", content: [{text: ("Attached file (" + $name + "):\n" + $text)}]}]')
        else
          payload=$(echo "$payload" | jq \
            --arg name "$filename" \
            --arg text "$content" \
            '.messages += [{role: "user", content: ("Attached file (" + $name + "):\n" + $text)}]')
        fi
      done < "$SELECTED_FILES_FILE"
    fi
  else
    # Fallback without jq (less reliable but functional)
    print_status "warning" "jq not available - using fallback JSON construction"
    payload=$(build_payload_fallback "$user_message")
  fi
  
  echo "$payload"
}

# Fallback payload builder without jq
build_payload_fallback() {
  local user_message="$1"
  local escaped_message
  
  # Basic JSON escaping
  escaped_message=$(echo "$user_message" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/g' | tr -d '\n' | sed 's/\\n$//')
  
  if [ "$API_TEST_TARGET" = "aws" ]; then
    cat <<JSON
{
  "system": [{"text": "You are a helpful assistant."}],
  "messages": [
    {"role": "user", "content": [{"text": "$escaped_message"}]}
  ],
  "inferenceConfig": {
    "maxTokens": $MAX_TOKENS,
    "temperature": $TEMPERATURE
  }
}
JSON
  else
    cat <<JSON
{
  "model": "$MODEL",
  "max_tokens": $MAX_TOKENS,
  "temperature": $TEMPERATURE,
  "stream": $([ "$STREAM_FLAG" -eq 1 ] && echo "true" || echo "false"),
  "messages": [
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "$escaped_message"}
  ]
}
JSON
  fi
}

# Enhanced request preview
show_request_preview() {
  local payload="$1"
  
  printf "\n$(c BRIGHT_WHITE)$(c BOLD)$(e SEARCH)Request Preview:$(c RESET)\n"
  printf "$(c BLUE)%s$(c RESET)\n" "$(printf '▔%.0s' $(seq 1 60))"
  
  # Show HTTP details
  print_kv "Method" "POST" "ROCKET" 2 12
  print_kv "URL" "$(truncate_url "$URL" 60)" "GLOBE" 2 12
  print_kv "Content-Type" "application/json" "GEAR" 2 12
  print_kv "Authorization" "Bearer $(mask_api_key "$API_KEY")" "KEY" 2 12
  
  # Show payload (pretty-printed if possible)
  printf "\n$(c CYAN)$(c BOLD)Payload:$(c RESET)\n"
  if command -v jq >/dev/null 2>&1; then
    echo "$payload" | jq --color-output . 2>/dev/null || echo "$payload"
  else
    echo "$payload"
  fi
  
  printf "$(c BLUE)%s$(c RESET)\n" "$(printf '▁%.0s' $(seq 1 60))"
}

# Enhanced streaming request with better error handling and progress
execute_streaming_request() {
  local payload="$1"
  
  print_status "info" "$(e ZAP)Streaming mode enabled - real-time response"
  
  # Pre-flight connectivity check
  local preflight_response
  preflight_response=$(mktemp)
  local http_status
  
  # Preflight attempt (try strict first, then fallback to -k if SSL blocks)
  http_status=$(curl -sS -w "%{http_code}" -o "$preflight_response" \
    --connect-timeout 10 \
    --max-time 30 \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_KEY" \
    -X POST "$URL" \
    -d "$payload" 2>/dev/null) || {
    http_status="000"
  }
  
  # If strict failed and we're using HTTPS, try insecure fallback
  if [[ ! "$http_status" =~ ^2 ]] && [[ "$URL" =~ ^https:// ]] && [ "$INSECURE_FLAG" -eq 0 ]; then
    http_status=$(curl -sS -k -w "%{http_code}" -o "$preflight_response" \
      --connect-timeout 10 \
      --max-time 30 \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $API_KEY" \
      -X POST "$URL" \
      -d "$payload" 2>/dev/null || echo "000")
    if [[ "$http_status" =~ ^2 ]]; then
      INSECURE_RUNTIME=1
    fi
  fi
  
  # Check for immediate errors
  if [[ ! "$http_status" =~ ^2 ]]; then
    print_status "error" "HTTP $http_status error"
    if [ -s "$preflight_response" ]; then
      printf "$(c BRIGHT_RED)Response:$(c RESET)\n"
      if command -v jq >/dev/null 2>&1; then
        jq --color-output . < "$preflight_response" 2>/dev/null || cat "$preflight_response"
      else
        cat "$preflight_response"
      fi
    fi
    rm -f "$preflight_response"
    return 1
  fi
  rm -f "$preflight_response"
  
  # Stream the actual response
  printf "\n$(c BRIGHT_WHITE)$(c BOLD)$(e SPEECH)Streaming Response:$(c RESET)\n"
  printf "$(c BLUE)%s$(c RESET)\n" "$(printf '▔%.0s' $(seq 1 70))"
  printf "$(c BRIGHT_WHITE)"
  
  local token_count=0
  local line_count=0
  
  curl -sS -N \
    --connect-timeout 10 \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_KEY" \
    -X POST "$URL" \
    $([ "$INSECURE_FLAG" -eq 1 -o "$INSECURE_RUNTIME" -eq 1 ] && echo "-k") \
    -d "$payload" 2>/dev/null |
  while IFS= read -r line; do
    case "$line" in
      data:*)
        local data="${line#data: }"
        [ "$data" = "[DONE]" ] && break
        
        local content
        if command -v jq >/dev/null 2>&1; then
          content=$(echo "$data" | jq -r 'try .choices[0].delta.content // ""' 2>/dev/null)
        else
          # Fallback extraction without jq
          content=$(echo "$data" | grep -o '"content":"[^"]*"' | sed 's/"content":"//' | sed 's/"$//' | head -1)
        fi
        
        if [ -n "$content" ] && [ "$content" != "null" ]; then
          printf "%s" "$content"
          ((token_count++))
          
          # Add periodic newlines for readability
          if [[ "$content" =~ [.!?] ]]; then
            ((line_count++))
            [ $((line_count % 3)) -eq 0 ] && printf "\n"
          fi
        fi
        ;;
    esac
  done
  
  printf "$(c RESET)\n"
  printf "$(c BLUE)%s$(c RESET)\n" "$(printf '▁%.0s' $(seq 1 70))"
  printf "$(c DIM)Estimated tokens streamed: %d$(c RESET)\n" "$token_count"
}

# Enhanced non-streaming request with detailed response analysis
execute_non_streaming_request() {
  local payload="$1"
  local response_file
  response_file=$(mktemp)
  local http_status
  
  # Show a progress indicator for long requests
  {
    sleep 1
    if kill -0 $ 2>/dev/null; then
      printf "$(c BRIGHT_BLUE)$(e LOADING)Waiting for response...$(c RESET)\n"
    fi
  } &
  local progress_pid=$!
  
  # Execute request
  # Execute request (strict first, then insecure fallback if needed)
  http_status=$(curl -sS -w "%{http_code}" -o "$response_file" \
    --connect-timeout 10 \
    --max-time 60 \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_KEY" \
    -X POST "$URL" \
    -d "$payload" 2>/dev/null) || {
    kill $progress_pid 2>/dev/null || true
    wait $progress_pid 2>/dev/null || true
    print_status "error" "Request failed - check network connectivity"
    [ -s "$response_file" ] && cat "$response_file" >&2
    rm -f "$response_file"
    return 1
  }
  
  if [[ ! "$http_status" =~ ^2 ]] && [[ "$URL" =~ ^https:// ]] && [ "$INSECURE_FLAG" -eq 0 ]; then
    http_status=$(curl -sS -k -w "%{http_code}" -o "$response_file" \
      --connect-timeout 10 \
      --max-time 60 \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $API_KEY" \
      -X POST "$URL" \
      -d "$payload" 2>/dev/null || echo "000")
    if [[ "$http_status" =~ ^2 ]]; then
      INSECURE_RUNTIME=1
    fi
  fi
  
  # Stop progress indicator
  kill $progress_pid 2>/dev/null || true
  wait $progress_pid 2>/dev/null || true
  
  local response_body
  response_body=$(cat "$response_file")
  rm -f "$response_file"
  
  # Process response based on status
  case "$http_status" in
    2**)
      print_status "success" "Request completed successfully (HTTP $http_status)"
      show_response_details "$response_body"
      ;;
    4**)
      print_status "error" "Client error (HTTP $http_status)"
      show_error_details "$response_body"
      return 1
      ;;
    5**)
      print_status "error" "Server error (HTTP $http_status)"
      show_error_details "$response_body"
      return 1
      ;;
    *)
      print_status "error" "Unexpected HTTP status: $http_status"
      echo "$response_body" >&2
      return 1
      ;;
  esac
}

# Show detailed response information
show_response_details() {
  local response="$1"
  
  printf "\n$(c BRIGHT_WHITE)$(c BOLD)$(e SPEECH)Response Details:$(c RESET)\n"
  printf "$(c BLUE)%s$(c RESET)\n" "$(printf '▔%.0s' $(seq 1 70))"
  
  # Extract and show metadata
  if command -v jq >/dev/null 2>&1; then
    local content usage_info
    
    if [ "$API_TEST_TARGET" = "aws" ]; then
      content=$(echo "$response" | jq -r 'try .output.message.content[0].text // .outputText // ""' 2>/dev/null)
      usage_info=$(echo "$response" | jq -r 'try .usage // {}' 2>/dev/null)
    else
      content=$(echo "$response" | jq -r 'try .choices[0].message.content // ""' 2>/dev/null)
      usage_info=$(echo "$response" | jq -r 'try .usage // {}' 2>/dev/null)
    fi
    
    # Show usage statistics if available
    if [ "$usage_info" != "{}" ] && [ "$usage_info" != "null" ]; then
      printf "\n$(c CYAN)$(c BOLD)Usage Statistics:$(c RESET)\n"
      echo "$usage_info" | jq --color-output . 2>/dev/null
    fi
    
    # Show the main content
    printf "\n$(c BRIGHT_WHITE)$(c BOLD)Response Content:$(c RESET)\n"
    if [ "$RAW_FLAG" -eq 1 ]; then
      echo "$response" | jq --color-output . 2>/dev/null || echo "$response"
    else
      printf "$(c BRIGHT_WHITE)%s$(c RESET)\n" "$content"
    fi
  else
    # Fallback without jq
    if [ "$RAW_FLAG" -eq 1 ]; then
      echo "$response"
    else
      printf "$(c BRIGHT_WHITE)%s$(c RESET)\n" "$response"
    fi
  fi
  
  printf "$(c BLUE)%s$(c RESET)\n" "$(printf '▁%.0s' $(seq 1 70))"
}

# Show error details with helpful suggestions
show_error_details() {
  local error_response="$1"
  
  printf "$(c BRIGHT_RED)$(c BOLD)Error Details:$(c RESET)\n"
  
  if command -v jq >/dev/null 2>&1; then
    local error_message error_type
    error_message=$(echo "$error_response" | jq -r 'try .error.message // .message // .error // ""' 2>/dev/null)
    error_type=$(echo "$error_response" | jq -r 'try .error.type // .type // ""' 2>/dev/null)
    
    if [ -n "$error_message" ] && [ "$error_message" != "null" ]; then
      printf "$(c RED)Message: %s$(c RESET)\n" "$error_message"
    fi
    
    if [ -n "$error_type" ] && [ "$error_type" != "null" ]; then
      printf "$(c RED)Type: %s$(c RESET)\n" "$error_type"
    fi
    
    # Show full error for debugging
    printf "\n$(c DIM)Full error response:$(c RESET)\n"
    echo "$error_response" | jq --color-output . 2>/dev/null || echo "$error_response"
  else
    echo "$error_response"
  fi
  
  # Provide helpful suggestions
  printf "\n$(c BRIGHT_YELLOW)$(c BOLD)$(e IDEA)Troubleshooting suggestions:$(c RESET)\n"
  printf "  $(c WHITE)•$(c RESET) Check your API key and permissions\n"
  printf "  $(c WHITE)•$(c RESET) Verify the model name and availability\n"
  printf "  $(c WHITE)•$(c RESET) Review rate limits and quotas\n"
  printf "  $(c WHITE)•$(c RESET) Ensure your request parameters are valid\n"
}

# Show response metrics and performance data
show_response_metrics() {
  local duration="$1"
  
  print_section "Performance Metrics" "CHART_UP" "BRIGHT_GREEN"
  
  print_kv "Duration" "${duration}s" "STOPWATCH" 2 15
  print_kv "Provider" "$(get_provider_display_name "$API_TEST_TARGET")" "TARGET" 2 15
  print_kv "Model" "$MODEL" "ROBOT" 2 15
  print_kv "Stream Mode" "$([ "$STREAM_FLAG" -eq 1 ] && echo "Enabled" || echo "Disabled")" "ZAP" 2 15
  
  # Calculate rough performance rating
  local rating=""
  if command -v bc >/dev/null 2>&1; then
    local duration_float
    duration_float=$(echo "$duration" | bc 2>/dev/null || echo "$duration")
    
    if (( $(echo "$duration_float < 2" | bc -l 2>/dev/null || echo 0) )); then
      rating="$(c BRIGHT_GREEN)Excellent$(c RESET)"
    elif (( $(echo "$duration_float < 5" | bc -l 2>/dev/null || echo 0) )); then
      rating="$(c GREEN)Good$(c RESET)"
    elif (( $(echo "$duration_float < 10" | bc -l 2>/dev/null || echo 0) )); then
      rating="$(c YELLOW)Fair$(c RESET)"
    else
      rating="$(c RED)Slow$(c RESET)"
    fi
  else
    # Integer comparison fallback
    local duration_int=${duration%.*}
    if [ "$duration_int" -lt 2 ]; then
      rating="$(c BRIGHT_GREEN)Excellent$(c RESET)"
    elif [ "$duration_int" -lt 5 ]; then
      rating="$(c GREEN)Good$(c RESET)"
    elif [ "$duration_int" -lt 10 ]; then
      rating="$(c YELLOW)Fair$(c RESET)"
    else
      rating="$(c RED)Slow$(c RESET)"
    fi
  fi
  
  print_kv "Performance" "$rating" "FIRE" 2 15
}

# Enhanced file selection with better UX
select_files_interactive() {
  local script_dir="$(dirname "$0")"
  local files_dir=""
  
  # Find files directory
  if [ -d "$script_dir/files" ]; then
    files_dir="$script_dir/files"
  elif [ -d "$script_dir/../files" ]; then
    files_dir="$script_dir/../files"
  else
    print_status "error" "No files directory found"
    printf "$(c BRIGHT_YELLOW)$(e IDEA)Create one of these directories:$(c RESET)\n"
    printf "  • $script_dir/files\n"
    printf "  • $script_dir/../files\n"
    exit 1
  fi
  
  print_section "File Selection" "FILE" "BRIGHT_MAGENTA"
  
  # Build file list
  local files_list
  files_list=$(mktemp)
  find "$files_dir" -maxdepth 1 -type f -name '*.txt' | sort > "$files_list"
  
  local file_count
  file_count=$(wc -l < "$files_list")
  
  if [ "$file_count" -eq 0 ]; then
    print_status "warning" "No .txt files found in $files_dir"
    INCLUDE_FILE_FLAG=0
    FILE_SELECTED_COUNT=0
    rm -f "$files_list"
    return
  fi
  
  printf "$(c BRIGHT_WHITE)$(c BOLD)Available files in %s:$(c RESET)\n\n" "$(basename "$files_dir")"
  
  # Show file options with metadata
  print_table_header "Option" "Filename" "Size" "Modified"
  
  printf "$(c BRIGHT_CYAN)1$(c RESET)      $(c DIM)No files$(c RESET)\n"
  
  local option=2
  while IFS= read -r file_path; do
    [ -z "$file_path" ] && continue
    
    local filename size modified
    filename=$(basename "$file_path")
    size=$(get_file_size "$file_path")
    
    if command -v stat >/dev/null 2>&1; then
      if stat -c%Y "$file_path" >/dev/null 2>&1; then
        modified=$(date -d "@$(stat -c%Y "$file_path")" '+%Y-%m-%d' 2>/dev/null || echo "unknown")
      else
        modified=$(date -r "$file_path" '+%Y-%m-%d' 2>/dev/null || echo "unknown")
      fi
    else
      modified="unknown"
    fi
    
    printf "$(c BRIGHT_CYAN)%-7d$(c RESET) %-20s %-8s %s\n" "$option" "$filename" "$size" "$modified"
    ((option++))
  done < "$files_list"
  
  printf "$(c BRIGHT_CYAN)%-7d$(c RESET) $(c BRIGHT_GREEN)All files$(c RESET)\n" "$option"
  
  # Get user selection
  local max_option="$option"
  while :; do
    printf "\n"
    printf "%s" "$(c BRIGHT_WHITE)$(e THINKING)Select option [1-$max_option]: $(c RESET)"
    read -r selection || true
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "$max_option" ]; then
      break
    fi
    print_status "warning" "Please enter a valid option (1-$max_option)"
  done
  
  # Process selection
  if [ "$selection" -eq 1 ]; then
    # No files
    INCLUDE_FILE_FLAG=0
    FILE_SELECTED_COUNT=0
    SELECTED_FILES_FILE=""
  elif [ "$selection" -eq "$max_option" ]; then
    # All files
    INCLUDE_FILE_FLAG=1
    FILE_SELECTED_COUNT="$file_count"
    SELECTED_FILES_FILE=$(mktemp)
    cp "$files_list" "$SELECTED_FILES_FILE"
    print_status "success" "Selected all $file_count files"
  else
    # Single file
    local file_index=$((selection - 1))
    local selected_file
    selected_file=$(sed -n "${file_index}p" "$files_list")
    
    INCLUDE_FILE_FLAG=1
    FILE_SELECTED_COUNT=1
    SELECTED_FILES_FILE=$(mktemp)
    echo "$selected_file" > "$SELECTED_FILES_FILE"
    
    print_status "success" "Selected file: $(basename "$selected_file")"
  fi
  
  rm -f "$files_list"
}

# Enhanced help with better formatting and examples
print_help() {
  print_header "Enhanced LLM API Testing Tool" "Modern • Intuitive • Comprehensive"
  
  cat << 'EOF'
┌─ DESCRIPTION ──────────────────────────────────────────────────────────────┐
│ A modern, feature-rich tool for testing LLM API connectivity with:         │
│  • Beautiful, colorized output with emoji indicators                       │
│  • Real-time streaming support with progress tracking                      │
│  • Interactive provider selection and file attachment                      │
│  • Comprehensive error handling and troubleshooting                        │
│  • Performance metrics and response analysis                               │
└────────────────────────────────────────────────────────────────────────────┘

EOF
  
  printf "$(c BRIGHT_WHITE)$(c BOLD)USAGE$(c RESET)\n"
  printf "  $(c BRIGHT_GREEN)%s$(c RESET) $(c YELLOW)\"<prompt>\"$(c RESET) $(c CYAN)[options]$(c RESET)\n\n" "$0"
  
  printf "$(c BRIGHT_WHITE)$(c BOLD)OPTIONS$(c RESET)\n"
  printf "  $(c BRIGHT_CYAN)-h, --help$(c RESET)               Show this help and exit\n"
  printf "  $(c BRIGHT_CYAN)--conn <provider>$(c RESET)        Select provider: $(c YELLOW)openwebui$(c RESET)|$(c YELLOW)bag$(c RESET)|$(c YELLOW)aws$(c RESET)|$(c YELLOW)openai$(c RESET)\n"
  printf "  $(c BRIGHT_CYAN)--stream$(c RESET)                 Enable streaming mode (real-time tokens)\n"
  printf "  $(c BRIGHT_CYAN)--raw$(c RESET)                    Show raw JSON response\n"
  printf "  $(c BRIGHT_CYAN)--file <1|2>$(c RESET)            Attach files (1=Yes, 2=No, default=2)\n"
  printf "  $(c BRIGHT_CYAN)--debug <0|1|2>$(c RESET)         Debug level (0=quiet, 1=verbose, 2=trace)\n"
  printf "\n"
  
  printf "$(c BRIGHT_WHITE)$(c BOLD)PROVIDER SHORTCUTS$(c RESET)\n"
  printf "  $(c BRIGHT_CYAN)--openwebui$(c RESET)              Use OpenWebUI provider\n"
  printf "  $(c BRIGHT_CYAN)--bag$(c RESET)                    Use Bedrock Access Gateway\n"
  printf "  $(c BRIGHT_CYAN)--aws$(c RESET)                    Use AWS Bedrock Direct\n"
  printf "  $(c BRIGHT_CYAN)--openai$(c RESET)                 Use OpenAI Direct\n"
  printf "\n"
  
  printf "$(c BRIGHT_WHITE)$(c BOLD)ENVIRONMENT CONFIGURATION$(c RESET)\n"
  printf "$(c DIM)  Configuration is loaded from: api-testing/.env$(c RESET)\n\n"
  
  printf "  $(c BRIGHT_YELLOW)General Settings:$(c RESET)\n"
  printf "    $(c CYAN)API_TEST_TARGET$(c RESET)             Default provider\n"
  printf "    $(c CYAN)MAX_TOKENS$(c RESET)                  Token limit (default: 2500)\n"
  printf "    $(c CYAN)TEMPERATURE$(c RESET)                Response creativity (default: 0.2)\n"
  printf "    $(c CYAN)DEBUG$(c RESET)                       Debug level (0-2)\n\n"
  
  printf "  $(c BRIGHT_YELLOW)OpenWebUI:$(c RESET)\n"
  printf "    $(c CYAN)OPENWEBUI_BASE_URL$(c RESET)          Base URL for OpenWebUI\n"
  printf "    $(c CYAN)OPENWEBUI_API_KEY$(c RESET)           API authentication key\n"
  printf "    $(c CYAN)OPENWEBUI_MODEL$(c RESET)             Model identifier\n\n"
  
  printf "  $(c BRIGHT_YELLOW)Bedrock Access Gateway:$(c RESET)\n"
  printf "    $(c CYAN)BAG_BASE_URL$(c RESET)                Gateway base URL\n"
  printf "    $(c CYAN)BAG_API_KEY$(c RESET)                 Gateway API key\n"
  printf "    $(c CYAN)BAG_MODEL$(c RESET)                   Model to use\n\n"
  
  printf "  $(c BRIGHT_YELLOW)AWS Bedrock Direct:$(c RESET)\n"
  printf "    $(c CYAN)AWS_REGION$(c RESET)                  AWS region (e.g., us-east-1)\n"
  printf "    $(c CYAN)AWS_BEARER_TOKEN_BEDROCK$(c RESET)    Bearer token for authentication\n"
  printf "    $(c CYAN)BEDROCK_BASE_MODEL_ID$(c RESET)       Default Bedrock model ID\n\n"
  
  printf "  $(c BRIGHT_YELLOW)OpenAI Direct:$(c RESET)\n"
  printf "    $(c CYAN)OPENAI_DIRECT_BASE_URL$(c RESET)      OpenAI API base URL\n"
  printf "    $(c CYAN)OPENAI_DIRECT_API_KEY$(c RESET)       OpenAI API key\n"
  printf "    $(c CYAN)OPENAI_DIRECT_MODEL$(c RESET)         Model name (e.g., gpt-4)\n\n"
  
  printf "$(c BRIGHT_WHITE)$(c BOLD)EXAMPLES$(c RESET)\n"
  printf "$(c DIM)  # Interactive mode (recommended for first-time users)$(c RESET)\n"
  printf "  $(c GREEN)%s$(c RESET) $(c YELLOW)\"Hello, world!\"$(c RESET)\n\n" "$0"
  
  printf "$(c DIM)  # Quick test with specific provider and streaming$(c RESET)\n"
  printf "  $(c GREEN)%s$(c RESET) $(c YELLOW)\"Test message\"$(c RESET) $(c CYAN)--conn openwebui --stream$(c RESET)\n\n" "$0"
  
  printf "$(c DIM)  # Test with file attachment$(c RESET)\n"
  printf "  $(c GREEN)%s$(c RESET) $(c YELLOW)\"Summarize the attached document\"$(c RESET) $(c CYAN)--openai --file 1$(c RESET)\n\n" "$0"
  
  printf "$(c DIM)  # Raw JSON output for debugging$(c RESET)\n"
  printf "  $(c GREEN)%s$(c RESET) $(c YELLOW)\"Debug test\"$(c RESET) $(c CYAN)--bag --raw --debug 1$(c RESET)\n\n" "$0"
  
  printf "$(c DIM)  # Connectivity test (empty prompt)$(c RESET)\n"
  printf "  $(c GREEN)%s$(c RESET) $(c YELLOW)\"\"$(c RESET) $(c CYAN)--aws$(c RESET)\n\n" "$0"
  
  printf "$(c DIM)  # Environment variable override$(c RESET)\n"
  printf "  $(c GREEN)API_TEST_TARGET=openai %s$(c RESET) $(c YELLOW)\"Quick test\"$(c RESET)\n\n" "$0"
  
  printf "$(c BRIGHT_WHITE)$(c BOLD)FILE ATTACHMENTS$(c RESET)\n"
  printf "  Files should be placed in one of these directories:\n"
  printf "    $(c CYAN)• ./files/$(c RESET)     (relative to script location)\n"
  printf "    $(c CYAN)• ../files/$(c RESET)    (parent directory)\n\n"
  printf "  Supported formats: $(c YELLOW).txt$(c RESET) files only\n"
  printf "  Interactive selection shows file size and modification date\n\n"
  
  printf "$(c BRIGHT_WHITE)$(c BOLD)TROUBLESHOOTING$(c RESET)\n"
  printf "  $(c BRIGHT_YELLOW)Connection Issues:$(c RESET)\n"
  printf "    • Verify your network connectivity\n"
  printf "    • Check firewall and proxy settings\n"
  printf "    • Validate SSL certificates for HTTPS endpoints\n\n"
  
  printf "  $(c BRIGHT_YELLOW)Authentication Errors:$(c RESET)\n"
  printf "    • Confirm API keys are valid and not expired\n"
  printf "    • Check API key permissions and rate limits\n"
  printf "    • Verify correct base URLs for each provider\n\n"
  
  printf "  $(c BRIGHT_YELLOW)Model Issues:$(c RESET)\n"
  printf "    • Ensure model names are correctly specified\n"
  printf "    • Verify model availability in your region/account\n"
  printf "    • Check model-specific parameter requirements\n\n"
  
  printf "$(c DIM)For more help, run with --debug 1 for verbose output$(c RESET)\n"
}

# Enhanced debug logging
print_debug() {
  if [ "${DEBUG:-0}" != "0" ]; then
    local level="${1:-1}"
    shift
    local message="$*"
    
    if [ "${DEBUG:-0}" -ge "$level" ]; then
      local timestamp
      timestamp=$(date '+%H:%M:%S.%3N' 2>/dev/null || date '+%H:%M:%S')
      printf "$(c DIM)$(c CYAN)[%s] DEBUG: %s$(c RESET)\n" "$timestamp" "$message" >&2
    fi
  fi
}

# Main execution flow with enhanced error handling
main() {
  # Initialize defaults with better organization
  local -r SCRIPT_VERSION="2.0.0"
  
  # Core settings
  DEBUG=${DEBUG:-0}
  MAX_TOKENS="${MAX_TOKENS:-2500}"
  TEMPERATURE="${TEMPERATURE:-0.2}"
  MODEL="${MODEL:-us.anthropic.claude-3-5-haiku-20241022-v1:0}"
  INSECURE_FLAG=0
  INSECURE_RUNTIME=0
  if [ "${API_TEST_INSECURE:-0}" = "1" ] || [ "${INSECURE:-0}" = "1" ]; then
    INSECURE_FLAG=1
  fi
  
  # Runtime flags
  API_TEST_TARGET="${API_TEST_TARGET:-}"
  STREAM_FLAG=0
  RAW_FLAG=0
  INCLUDE_FILE_FLAG=0
  FILE_SELECTED_COUNT=0
  SELECTED_FILES_FILE=""
  USER_MESSAGE=""
  
  # Connection variables
  BASE_URL=""
  API_KEY=""
  URL=""
  
  print_debug 1 "Starting Enhanced LLM API Testing Tool v$SCRIPT_VERSION"
  print_debug 1 "Bash version: ${BASH_VERSION:-unknown}"
  print_debug 1 "Terminal capabilities: Colors=$USE_COLORS, Emojis=$USE_EMOJIS, Animations=$USE_ANIMATIONS"
  
  # Enable debug tracing if requested
  if [ "$DEBUG" = "2" ]; then
    print_debug 1 "Enabling bash trace mode"
    set -x
  fi
  
  # Parse command line arguments with enhanced validation
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help)
        print_help
        exit 0
        ;;
      --version)
        printf "Enhanced LLM API Testing Tool v%s\n" "$SCRIPT_VERSION"
        exit 0
        ;;
      --stream)
        STREAM_FLAG=1
        print_debug 2 "Streaming mode enabled"
        shift
        ;;
      --raw)
        RAW_FLAG=1
        print_debug 2 "Raw output mode enabled"
        shift
        ;;
      # --insecure (intentionally undocumented)
      --insecure)
        INSECURE_FLAG=1
        print_debug 1 "Insecure mode enabled (-k)"
        shift
        ;;
      --debug)
        if [ -n "${2:-}" ] && [[ "$2" =~ ^[0-2]$ ]]; then
          DEBUG="$2"
          print_debug 1 "Debug level set to $DEBUG"
          shift 2
        else
          print_status "error" "Invalid debug level. Use 0, 1, or 2"
          exit 1
        fi
        ;;
      --debug=*)
        local debug_val="${1#--debug=}"
        if [[ "$debug_val" =~ ^[0-2]$ ]]; then
          DEBUG="$debug_val"
          print_debug 1 "Debug level set to $DEBUG"
        else
          print_status "error" "Invalid debug level. Use 0, 1, or 2"
          exit 1
        fi
        shift
        ;;
      --file)
        local file_choice="${2:-2}"
        if [[ "$file_choice" =~ ^[12]$ ]]; then
          [ "$file_choice" = "1" ] && INCLUDE_FILE_FLAG=1 || INCLUDE_FILE_FLAG=0
          print_debug 2 "File attachment mode: $INCLUDE_FILE_FLAG"
          shift 2
        else
          print_status "error" "Invalid file option. Use 1 (yes) or 2 (no)"
          exit 1
        fi
        ;;
      --file=*)
        local file_choice="${1#--file=}"
        if [[ "$file_choice" =~ ^[12]$ ]]; then
          [ "$file_choice" = "1" ] && INCLUDE_FILE_FLAG=1 || INCLUDE_FILE_FLAG=0
          print_debug 2 "File attachment mode: $INCLUDE_FILE_FLAG"
        else
          print_status "error" "Invalid file option. Use 1 (yes) or 2 (no)"
          exit 1
        fi
        shift
        ;;
      --conn)
        if [ -n "${2:-}" ]; then
          API_TEST_TARGET="$2"
          print_debug 2 "Connection target set to: $API_TEST_TARGET"
          shift 2
        else
          print_status "error" "--conn requires a provider argument"
          exit 1
        fi
        ;;
      --conn=*)
        API_TEST_TARGET="${1#--conn=}"
        print_debug 2 "Connection target set to: $API_TEST_TARGET"
        shift
        ;;
      --openwebui)
        API_TEST_TARGET="openwebui"
        print_debug 2 "OpenWebUI provider selected"
        shift
        ;;
      --bag)
        API_TEST_TARGET="bag"
        print_debug 2 "Bedrock Access Gateway provider selected"
        shift
        ;;
      --aws)
        API_TEST_TARGET="aws"
        print_debug 2 "AWS Bedrock provider selected"
        shift
        ;;
      --openai)
        API_TEST_TARGET="openai"
        print_debug 2 "OpenAI provider selected"
        shift
        ;;
      --*)
        print_status "error" "Unknown option: $1"
        printf "$(c BRIGHT_CYAN)Try: %s --help$(c RESET)\n" "$0"
        exit 1
        ;;
      *)
        if [ -z "$USER_MESSAGE" ]; then
          USER_MESSAGE="$1"
        else
          USER_MESSAGE="$USER_MESSAGE $1"
        fi
        shift
        ;;
    esac
  done
  
  print_debug 1 "Command line parsing complete"
  
  # Show enhanced welcome
  if [ "$DEBUG" -eq 0 ]; then
    print_header "Enhanced LLM API Testing Tool" "v$SCRIPT_VERSION • Modern • Reliable"
  fi
  
  # Load and validate environment
  load_environment
  
  # Always use the file selection menu (interactive) to determine attachments
  # This removes the redundant yes/no prompt and lets option 1 = "No files"
  if [ -t 0 ]; then
    # Check if a files directory with .txt exists nearby, then present selection
    script_dir="$(dirname "$0")"
    candidate_dir=""
    if [ -d "$script_dir/files" ]; then
      candidate_dir="$script_dir/files"
    elif [ -d "$script_dir/../files" ]; then
      candidate_dir="$script_dir/../files"
    fi
    if [ -n "$candidate_dir" ] && find "$candidate_dir" -maxdepth 1 -type f -name '*.txt' | read -r _; then
      select_files_interactive
    else
      # No available files -> ensure no attachments
      INCLUDE_FILE_FLAG=0
      FILE_SELECTED_COUNT=0
      SELECTED_FILES_FILE=""
    fi
  fi
  
  # Get user message if not provided
  if [ -z "$USER_MESSAGE" ]; then
    if [ -t 0 ]; then
      printf "\n$(c BRIGHT_WHITE)$(e THINKING)Enter your prompt$(c RESET) $(c DIM)(or press Enter to leave empty/null for testing):$(c RESET)\n"
      printf "$(c BRIGHT_CYAN)❯ $(c RESET)"
      read -r USER_MESSAGE || true
    fi
    
    if [ -z "${USER_MESSAGE:-}" ]; then
      USER_MESSAGE="Hello! This is a connectivity test."
      print_status "info" "Using default connectivity test message"
    fi
  fi
  
  print_debug 1 "User message length: ${#USER_MESSAGE} characters"
  
  # Normalize numeric connection targets
  case "${API_TEST_TARGET:-}" in
    1) API_TEST_TARGET="openwebui" ;;
    2) API_TEST_TARGET="bag" ;;
    3) API_TEST_TARGET="aws" ;;
    4) API_TEST_TARGET="openai" ;;
  esac
  
  # Select connection if not specified
  if [ -z "$API_TEST_TARGET" ]; then
    select_connection
  fi
  
  print_debug 1 "Final connection target: $API_TEST_TARGET"
  
  # Setup and validate connection
  if ! setup_connection "$API_TEST_TARGET"; then
    print_status "error" "Connection setup failed"
    exit 1
  fi
  
  # Display configuration summary
  display_settings
  
  # Confirm before execution (in interactive mode)
  if [ -t 0 ] && [ "$DEBUG" -eq 0 ]; then
    printf "\n$(c BRIGHT_YELLOW)$(e QUESTION)Proceed with request? [Y/n]: $(c RESET)"
    read -r confirm || true
    case "${confirm:-y}" in
      [Nn]*) 
        print_status "info" "Request cancelled by user"
        exit 0
        ;;
    esac
  fi
  
  # Execute the request
  printf "\n"
  if execute_request "$USER_MESSAGE"; then
    print_status "success" "$(e SUCCESS)Test completed successfully!"
    
    # Cleanup temporary files
    if [ -n "${SELECTED_FILES_FILE:-}" ] && [ -f "$SELECTED_FILES_FILE" ]; then
      rm -f "$SELECTED_FILES_FILE"
      print_debug 2 "Cleaned up temporary files"
    fi
    
    printf "\n$(c BRIGHT_GREEN)$(c BOLD)$(e SPARKLES)All done! Your LLM API is working perfectly.$(c RESET)\n\n"
    exit 0
  else
    print_status "error" "$(e ERROR)Test failed - see error details above"
    
    # Cleanup on failure too
    if [ -n "${SELECTED_FILES_FILE:-}" ] && [ -f "$SELECTED_FILES_FILE" ]; then
      rm -f "$SELECTED_FILES_FILE"
    fi
    
    exit 1
  fi
}

# Trap for cleanup on script termination
cleanup() {
  local exit_code=$?
  print_debug 2 "Cleanup function called with exit code: $exit_code"
  
  # Clean up temporary files
  if [ -n "${SELECTED_FILES_FILE:-}" ] && [ -f "$SELECTED_FILES_FILE" ]; then
    rm -f "$SELECTED_FILES_FILE"
    print_debug 2 "Cleaned up temporary file: $SELECTED_FILES_FILE"
  fi
  
  # Reset terminal if needed
  if [ "$USE_COLORS" -eq 1 ]; then
    printf "$(c RESET)"
  fi
  
  exit $exit_code
}

# Set up signal handlers
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

# Run main function with all arguments
main "$@"
