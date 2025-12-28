#!/bin/bash

# File Organizer Script
# Organizes files into categories based on their extensions

# Default values
SOURCE_DIR=""
DEST_DIR=""
DRY_RUN=false
VERBOSE=false
SKIP_DUPLICATES=true
MOVE_FILES=false
INITIAL_SIZE=""
FORCE=false
PROGRESS_STYLE="bar" # bar, simple, or detailed

# Color definitions
COLOR_RESET="\033[0m"
COLOR_RED="\033[0;31m"
COLOR_GREEN="\033[0;32m"
COLOR_YELLOW="\033[0;33m"
COLOR_BLUE="\033[0;34m"
COLOR_PURPLE="\033[0;35m"
COLOR_CYAN="\033[0;36m"
COLOR_GRAY="\033[0;90m"
COLOR_BOLD="\033[1m"

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR"

# Show help message
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] SOURCE_DIR [DEST_DIR]

Organizes files from SOURCE_DIR into categorized directories.
If DEST_DIR is provided, files will be moved there.
Otherwise, files will be organized in place within SOURCE_DIR.

Options:
  -h, --help            Show this help message
  -d, --dry-run         Show what would be done without making changes
  -v, --verbose         Show detailed progress
  -m, --move            Move files instead of organizing in place
  -f, --force           Skip confirmation prompt
  --progress STYLE     Progress display style (bar, simple, detailed)
  --no-skip-duplicates  Don't skip duplicate files
  --dest DIR           Specify destination directory
  --by-date            Organize files by date instead of project
  --by-type            Organize files by type only (flat structure)
  --exclude PATTERN    Exclude files matching pattern (can be used multiple times)
  --log-dir DIR        Directory to store log files (default: script's directory)
  --no-color           Disable colored output

Progress Styles:
  bar      [===>    ] 45% (default)
  simple   [45/100]
  detailed Shows current file and detailed info

Examples:
  $(basename "$0") ~/MessyFolder
  $(basename "$0") --dry-run --verbose ~/MessyFolder ~/Organized
  $(basename "$0") --by-date ~/Photos

Directory Structure:
  organized/
    ├── video/
    │   ├── raw/         # Original footage
    │   ├── edited/      # Edited videos
    │   └── renders/     # Final renders
    ├── images/
    │   ├── raw/        # Original photos
    │   ├── edited/     # Edited photos
    │   └── exports/    # Final exports
    └── ...

Project Detection:
  The script attempts to detect project names from the source path.
  Example: /path/to/ProjectX/raw/video.mp4 → organized/video/raw/ProjectX_video.mp4

File Types:
  Videos:     mp4, mov, avi, mkv, m4v
  Images:     jpg, jpeg, png, gif, bmp, raw, cr2, nef, arw
  Documents:  pdf, doc, docx, txt, xls, xlsx, ppt, pptx
  Projects:   prproj, psd, aep, ai
  Archives:   zip, rar, 7z, tar, gz
EOF
}

# Parse command line arguments
POSITIONAL_ARGS=()
EXCLUDE_PATTERNS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            PROGRESS_STYLE="detailed"
            shift
            ;;
        -m|--move)
            MOVE_FILES=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        --progress)
            PROGRESS_STYLE="$2"
            shift 2
            ;;
        --no-color)
            COLOR_RESET=""
            COLOR_RED=""
            COLOR_GREEN=""
            COLOR_YELLOW=""
            COLOR_BLUE=""
            COLOR_PURPLE=""
            COLOR_CYAN=""
            COLOR_GRAY=""
            COLOR_BOLD=""
            shift
            ;;
        --no-skip-duplicates)
            SKIP_DUPLICATES=false
            shift
            ;;
        --dest)
            DEST_DIR="$2"
            MOVE_FILES=true
            shift 2
            ;;
        --log-dir)
            LOG_DIR="$2"
            shift 2
            ;;
        --exclude)
            EXCLUDE_PATTERNS+=("$2")
            shift 2
            ;;
        --by-date)
            BY_DATE=true
            shift
            ;;
        --by-type)
            BY_TYPE=true
            shift
            ;;
        -*|--*)
            echo "${COLOR_RED}Unknown option $1${COLOR_RESET}"
            exit 1
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Restore positional arguments
set -- "${POSITIONAL_ARGS[@]}"

# Check required arguments
if [ $# -lt 1 ]; then
    echo "Error: SOURCE_DIR is required"
    show_help
    exit 1
fi

# Set directories
SOURCE_DIR="$1"

# If no destination specified, organize in place
if [ -z "$DEST_DIR" ]; then
    DEST_DIR="$SOURCE_DIR"
fi

# Calculate initial size
INITIAL_SIZE=$(du -sh "$SOURCE_DIR" 2>/dev/null | cut -f1)

# Setup logging
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR" || {
        echo "❌ Error: Cannot create log directory: $LOG_DIR" >&2
        exit 1
    }
fi

if [ ! -w "$LOG_DIR" ]; then
    echo "❌ Error: Log directory is not writable: $LOG_DIR" >&2
    exit 1
fi

LOG_FILE="$LOG_DIR/organizer-$(date +%Y%m%d-%H%M%S).log"

# Display initial information
echo "🔍 Source directory: $SOURCE_DIR"
echo "📁 Destination directory: $DEST_DIR"
echo "📦 Initial size: $INITIAL_SIZE"
echo "📝 Log file: $LOG_FILE"

# Show warning and prompt for confirmation unless in dry-run or force mode
if [ "$DRY_RUN" = false ] && [ "$FORCE" = false ]; then
    if [ "$MOVE_FILES" = true ]; then
        echo -e "⚠️  WARNING: This will move files from: $SOURCE_DIR to $DEST_DIR"
    else
        echo -e "⚠️  WARNING: This will organize files in place at: $SOURCE_DIR"
    fi
    echo "   Use --dry-run first if you want to preview the changes"
    echo "   Use --force to skip this prompt"
    read -p "   Do you want to proceed? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 1
    fi
fi

# Create log file
LOG_FILE="$DEST_DIR/organizer.log"

# Define directory structure
declare -A CATEGORIES=(
    ["video/raw"]="mp4 mov avi mkv m4v"
    ["video/edited"]="mp4 mov avi mkv m4v"
    ["video/renders"]="mp4 mov avi mkv m4v"
    ["images/raw"]="jpg jpeg png gif bmp heic raw cr2 nef arw"
    ["images/edited"]="jpg jpeg png gif bmp psd ai"
    ["images/exports"]="jpg jpeg png gif bmp pdf"
    ["documents/contracts"]="pdf doc docx txt"
    ["documents/spreadsheets"]="xls xlsx csv"
    ["documents/presentations"]="ppt pptx key"
    ["projects/premiere"]="prproj"
    ["projects/photoshop"]="psd psb"
    ["projects/after_effects"]="aep"
    ["archives/backups"]="zip rar 7z tar gz"
    ["archives/deliverables"]="zip rar 7z"
)

# Function to log messages
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="$timestamp - $1"

    if [ "$DRY_RUN" = true ]; then
        message="[DRY RUN] $message"
    fi

    if [ "$VERBOSE" = true ] || [ "$DRY_RUN" = true ]; then
        echo "$message" | tee -a "$LOG_FILE"
    else
        echo "$message" >> "$LOG_FILE"
    fi
}

# Function to create directory structure
create_directories() {
    mkdir -p "$DEST_DIR"
    for category in "${!CATEGORIES[@]}"; do
        mkdir -p "$DEST_DIR/$category"
    done
    mkdir -p "$DEST_DIR/misc"
    touch "$LOG_FILE"
}

# Function to get file category based on extension
get_category() {
    local file_ext="${1#.}"
    file_ext=$(echo "$file_ext" | tr '[:upper:]' '[:lower:]')

    for category in "${!CATEGORIES[@]}"; do
        if [[ " ${CATEGORIES[$category]} " =~ " $file_ext " ]]; then
            echo "$category"
            return
        fi
    done
    echo "misc"
}

# Function to generate file hash (for duplicate detection)
get_file_hash() {
    md5 -q "$1"
}

# Function to extract project name from path
get_project_name() {
    local filepath="$1"
    local dirpath=$(dirname "$filepath")
    local project_name="unknown"

    # Try to find a directory that looks like a project name
    while [ "$dirpath" != "/" ]; do
        base=$(basename "$dirpath")
        if [[ $base =~ ^(projeto|project|ESCALANDO|Kapsula|CompartilhadosComigo) ]]; then
            project_name=$base
            break
        fi
        dirpath=$(dirname "$dirpath")
    done

    echo "$project_name"
}

# Function to organize a single file
organize_file() {
    local file="$1"
    local filename=$(basename "$file")
    local extension="${filename##*.}"
    local category=$(get_category "$extension")

    # Skip excluded patterns
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$file" =~ $pattern ]]; then
            [ "$VERBOSE" = true ] && log_message "Skipping excluded file: $file"
            return
        fi
    done

    # Generate new filename based on organization method
    local new_filename
    if [ "$BY_DATE" = true ]; then
        local date_str=$(date -r "$file" "+%Y-%m-%d")
        new_filename="${date_str}_${filename}"
    elif [ "$BY_TYPE" = true ]; then
        new_filename="$filename"
    else
        local project_name=$(get_project_name "$file")
        new_filename="${project_name}_${filename}"
    fi

    local dest_path="$DEST_DIR/$category/$new_filename"

    # If in dry-run mode, just show what would be done
    if [ "$DRY_RUN" = true ]; then
        if [ "$MOVE_FILES" = true ]; then
            log_message "Would move: $file -> $dest_path"
        else
            log_message "Would organize: $file -> $dest_path"
        fi
        return
    fi

    # Create destination directory if it doesn't exist
    mkdir -p "$(dirname "$dest_path")"

    # Move or copy the file
    if [ "$MOVE_FILES" = true ]; then
        mv "$file" "$dest_path" && log_message "Moved: $file -> $dest_path"
    else
        cp "$file" "$dest_path" && log_message "Organized: $file -> $dest_path"
    fi

    # Check if file is already organized
    if [[ "$file" == "$DEST_DIR"* ]]; then
        return
    fi

    # Get file hash
    local file_hash=$(get_file_hash "$file")

    # Check for duplicates
    for existing in "$DEST_DIR"/**/*; do
        if [ -f "$existing" ]; then
            local existing_hash=$(get_file_hash "$existing")
            if [ "$file_hash" == "$existing_hash" ]; then
                log_message "Duplicate found: $file -> $existing"
                return
            fi
        fi
    done

    # Copy file to destination
    cp "$file" "$dest_path"
    log_message "Organized: $file -> $dest_path"
}

# Function to count total files
count_files() {
    local dir="$1"
    find "$dir" -type f | wc -l
}

# Function to show progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local rel_path=$3
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))

    case "$PROGRESS_STYLE" in
        "bar")
            printf "\r\033[K${COLOR_BLUE}[${COLOR_RESET}"
            printf "%${filled}s" "" | tr ' ' '='
            printf ">${COLOR_GRAY}"
            printf "%${empty}s" "" | tr ' ' ' '
            printf "${COLOR_BLUE}]${COLOR_RESET} ${COLOR_YELLOW}%3d%%${COLOR_RESET}" "$percentage"
            ;;
        "simple")
            printf "\r\033[K${COLOR_BLUE}[${COLOR_RESET}${COLOR_YELLOW}%d${COLOR_RESET}/${COLOR_CYAN}%d${COLOR_RESET}${COLOR_BLUE}]${COLOR_RESET}" "$current" "$total"
            ;;
        "detailed")
            printf "\r\033[K${COLOR_PURPLE}⏳ ${COLOR_RESET}${COLOR_BOLD}%d${COLOR_RESET}/${COLOR_BOLD}%d${COLOR_RESET} ${COLOR_BLUE}[%3d%%]${COLOR_RESET} ${COLOR_CYAN}%s${COLOR_RESET}" "$current" "$total" "$percentage" "$rel_path"
            ;;
    esac
}

# Function to process directory
process_directory() {
    local dir="$1"
    local total_files=$(count_files "$dir")
    local processed=0

    echo -e "\n${COLOR_CYAN}Found ${COLOR_YELLOW}$total_files${COLOR_CYAN} files to process${COLOR_RESET}"

    find "$dir" -type f -print0 | while IFS= read -r -d '' file; do
        processed=$((processed + 1))
        local rel_path=${file#$SOURCE_DIR/}
        
        # Show progress
        show_progress "$processed" "$total_files" "$rel_path"
        
        organize_file "$file"
    done
    echo -ne "\r\033[K"  # Clear the progress line
}

# Main function
main() {
    if [ ! -d "$SOURCE_DIR" ]; then
        echo -e "${COLOR_RED}❌ Error: Source directory '$SOURCE_DIR' does not exist${COLOR_RESET}"
        exit 1
    fi

    # Create directory structure
    create_directories

    # Print initial info in a box
    echo -e "\n${COLOR_BLUE}┌─────────────────────────────────────────┐${COLOR_RESET}"
    echo -e "${COLOR_BLUE}│${COLOR_RESET} ${COLOR_PURPLE}🎯 Source:${COLOR_RESET} ${SOURCE_DIR}${COLOR_BLUE} │${COLOR_RESET}"
    echo -e "${COLOR_BLUE}│${COLOR_RESET} ${COLOR_PURPLE}📁 Destination:${COLOR_RESET} ${DEST_DIR}${COLOR_BLUE} │${COLOR_RESET}"
    echo -e "${COLOR_BLUE}│${COLOR_RESET} ${COLOR_PURPLE}📦 Initial Size:${COLOR_RESET} ${COLOR_YELLOW}${INITIAL_SIZE}${COLOR_RESET}${COLOR_BLUE} │${COLOR_RESET}"
    echo -e "${COLOR_BLUE}└─────────────────────────────────────────┘${COLOR_RESET}"

    # Start organizing
    echo -e "\n${COLOR_GREEN}🚀 Starting organization...${COLOR_RESET}" | tee -a "$LOG_FILE"
    process_directory "$SOURCE_DIR"

    # Calculate final statistics
    if [ "$DRY_RUN" = false ]; then
        FINAL_SIZE=$(du -sh "$SOURCE_DIR" 2>/dev/null | cut -f1)
        echo -e "\n${COLOR_CYAN}📊 Organization Results:${COLOR_RESET}"
        echo -e "   ${COLOR_BLUE}┌─────────────────────┐${COLOR_RESET}"
        echo -e "   ${COLOR_BLUE}│${COLOR_RESET} 📥 Initial: ${COLOR_YELLOW}${INITIAL_SIZE}${COLOR_RESET}${COLOR_BLUE} │${COLOR_RESET}"
        echo -e "   ${COLOR_BLUE}│${COLOR_RESET} 📤 Final:   ${COLOR_GREEN}${FINAL_SIZE}${COLOR_RESET}${COLOR_BLUE} │${COLOR_RESET}"
        echo -e "   ${COLOR_BLUE}└─────────────────────┘${COLOR_RESET}"
    fi

    # Print completion message
    if [ "$DRY_RUN" = true ]; then
        echo -e "\n${COLOR_YELLOW}🔍 Dry run completed. No files were modified.${COLOR_RESET}"
    else
        echo -e "\n${COLOR_GREEN}✨ Organization completed successfully!${COLOR_RESET}"
    fi
    echo -e "${COLOR_CYAN}📝 Detailed log saved to: ${COLOR_RESET}${COLOR_BOLD}$LOG_FILE${COLOR_RESET}"
}

# Run main function
main
