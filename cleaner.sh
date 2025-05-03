#!/bin/bash

# cleaner.sh - Clean up junk files and empty directories
#
# This script helps clean up various types of junk files, temporary files,
# and empty directories. It includes safety features like dry-run mode and
# file age filtering.
#
# Types of files removed:
# - Empty files (0 bytes)
# - System files (.DS_Store, Thumbs.db, etc.)
# - Temporary files (*.tmp, *.bak, *~)
# - Google Drive web files (*.gdoc, *.gsheet, etc.)
# - Windows shortcuts (*.url, *.lnk)
# - XML files in video directories
# - Empty directories
#
# Usage examples:
#   ./cleaner.sh /path/to/clean          # Normal cleanup
#   ./cleaner.sh -d /path/to/clean       # Dry run
#   ./cleaner.sh -a 30 /path/to/clean    # Clean files older than 30 days

# Default values
DRY_RUN=false
MIN_AGE=0
FORCE=false
# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR"

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS] /path/to/clean"
    echo
    echo "A utility to clean up junk files and empty directories safely."
    echo
    echo "Options:"
    echo "  -d, --dry-run       Show what would be deleted without actually deleting"
    echo "  -f, --force         Skip confirmation prompt (useful for cron jobs)"
    echo "  -a, --age DAYS      Only delete files older than DAYS days"
    echo "  -l, --log-dir DIR   Directory to store log files (default: script's directory)"
    echo "  -h, --help          Show this help message"
    echo
    echo "Examples:"
    echo "  $0 /path/to/clean                              # Normal cleanup (with prompt)"
    echo "  $0 --dry-run /path/to/clean                   # Preview what would be deleted"
    echo "  $0 --force /path/to/clean                     # Clean without prompting (for cron)"
    echo "  $0 --force --age 30 /path/to/clean           # Delete files older than 30 days"
    echo "  $0 --log-dir /var/log/cleanup /path/to/clean  # Specify log directory"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -a|--age)
            MIN_AGE="$2"
            shift 2
            ;;

        -f|--force)
            FORCE=true
            shift
            ;;
        -l|--log-dir)
            LOG_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            TARGET="$1"
            shift
            ;;
    esac
 done

# Check if target path is provided
if [ -z "$TARGET" ]; then
    echo "❌ Error: Target path is required"
    show_help
fi

# Check if target exists and is accessible
if [ ! -d "$TARGET" ] || [ ! -r "$TARGET" ]; then
    echo "❌ Error: Target directory does not exist or is not readable: $TARGET" >&2
    exit 1
fi

# Check write permissions
if [ ! -w "$TARGET" ]; then
    echo "❌ Error: No write permission in target directory: $TARGET" >&2
    exit 1
fi

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

LOG_FILE="$LOG_DIR/clean_empty_and_junk-$(date +%Y%m%d-%H%M%S).log"

# Calculate initial size
INITIAL_SIZE=$(du -sh "$TARGET" 2>/dev/null | cut -f1)

# Display initial information
echo "🔍 Target directory: $TARGET"
echo "📦 Initial size: $INITIAL_SIZE"
echo "📝 Log file: $LOG_FILE"

# Show warning and prompt for confirmation unless in dry-run or force mode
if [ "$DRY_RUN" = false ] && [ "$FORCE" = false ]; then
    echo -e "⚠️  WARNING: This will permanently delete files in: $TARGET"
    echo "   Use --dry-run first if you want to preview the changes"
    echo "   Use --force to skip this prompt (e.g., for cron jobs)"
    read -p "   Do you want to proceed with deletion? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 1
    fi
fi

echo "🔍 Starting cleanup in directory: $TARGET" | tee "$LOG_FILE"

# Step 1: Remove zero-byte files
echo -e "\n📄 Removing empty (0 byte) files:" | tee -a "$LOG_FILE"
find "$TARGET" -type f -size 0 -print0 2>/dev/null | while IFS= read -r -d '' file; do
    dir=$(dirname "$file")
    echo -ne "\r\033[K🔄 Processing: ${dir#$TARGET/}"
    if [ "$DRY_RUN" = true ]; then
        echo "$file" | tee -a "$LOG_FILE"
    else
        if [ -f "$file" ]; then  # Check if file still exists
            rm "$file" && echo "$file" | tee -a "$LOG_FILE"
        fi
    fi
done
echo -ne "\r\033[K"  # Clear the progress line

# Step 2: Remove system junk and temporary files
# Includes system files, backups, temporary files, shortcuts and Google Drive web files
echo -e "\n🗑 Removing system junk files:" | tee -a "$LOG_FILE"
find "$TARGET" \
    -path '*/.git' -prune -o \
    -path '*/node_modules' -prune -o \
    \( \
        -iname '.ds_store' -o \
        -iname 'thumbs.db' -o \
        -iname 'desktop.ini' -o \
        -iname '*.tmp' -o \
        -iname '*.bak' -o \
        -iname '*~' -o \
        -iname '.spotlight-v100' -o \
        -iname '.trashes' -o \
        -iname '*.gdoc' -o \
        -iname '*.gsheet' -o \
        -iname '*.gslides' -o \
        -iname '*.gsite' -o \
        -iname '*.url' -o \
        -iname '*.lnk' -o \
        -iname '*.drawio' \
    \) \
    -type f \
    -mtime +"$MIN_AGE" \
    -print0 2>/dev/null | while IFS= read -r -d '' file; do
        dir=$(dirname "$file")
        echo -ne "\r\033[K🔄 Processing: ${dir#$TARGET/}"
        if [ "$DRY_RUN" = true ]; then
            echo "$file" | tee -a "$LOG_FILE"
        else
            if [ -f "$file" ]; then
                rm "$file" && echo "$file" | tee -a "$LOG_FILE"
            fi
        fi
    done
echo -ne "\r\033[K"  # Clear the progress line

# Step 3: Clean XML files in video directories
# Only removes XML files from directories containing videos to preserve config files
echo -e "\n🎥 Removing XML files from video directories:" | tee -a "$LOG_FILE"
find "$TARGET" -type d | while read -r dir; do
    echo -ne "\r\033[K🔄 Checking: ${dir#$TARGET/}"
    if find "$dir" -maxdepth 1 \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.avi" \) | grep -q .; then
        if [ "$DRY_RUN" = true ]; then
            find "$dir" -maxdepth 1 -iname "*.xml" -print | tee -a "$LOG_FILE"
        else
            find "$dir" -maxdepth 1 -iname "*.xml" -mtime +"$MIN_AGE" -print0 2>/dev/null | while IFS= read -r -d '' file; do
                if [ -f "$file" ]; then
                    rm "$file" && echo "$file" | tee -a "$LOG_FILE"
                fi
            done
        fi
    fi
done
echo -ne "\r\033[K"  # Clear the progress line

# Step 4: Final cleanup - remove empty directories
echo -e "\n📂 Removing empty directories:" | tee -a "$LOG_FILE"
find "$TARGET" -type d | while read -r dir; do
    echo -ne "\r\033[K🔄 Checking: ${dir#$TARGET/}"
    if [ -d "$dir" ]; then  # Verify directory still exists
        if [ "$DRY_RUN" = true ]; then
            if [ -z "$(ls -A "$dir")" ]; then
                echo "$dir" | tee -a "$LOG_FILE"
            fi
        else
            if [ -z "$(ls -A "$dir")" ]; then
                rmdir "$dir" && echo "$dir" | tee -a "$LOG_FILE"
            fi
        fi
    fi
done
echo -ne "\r\033[K"  # Clear the progress line

# Calculate final size and space saved
if [ "$DRY_RUN" = false ]; then
    FINAL_SIZE=$(du -sh "$TARGET" 2>/dev/null | cut -f1)
    echo -e "\n📊 Cleanup Results:"
    echo "   📆 Initial size: $INITIAL_SIZE"
    echo "   📋 Final size: $FINAL_SIZE"
fi

# Finish
if [ "$DRY_RUN" = true ]; then
    echo -e "\n🔎 Dry run completed. No files were deleted."
else
    echo -e "\n✨ Cleanup completed! Log saved to $LOG_FILE"
fi
