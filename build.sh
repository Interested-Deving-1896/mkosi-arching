#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error.
# The return value of a pipeline is the status of the last command
# to exit with a non-zero status, or zero if all commands exit successfully.
set -euo pipefail

# --- Configuration ---
# Directory containing your primary mkosi.conf file
MKOSI_SOURCE_DIR="/opt/mkosi"
# Temporary directory where mkosi will run the build
MKOSI_TEMP_DIR="/tmp/mkosi-build-$(date +%Y%m%d-%H%M%S)-$$" # Use a unique temp dir
# Directory where mkosi outputs files by default (relative to the build dir)
MKOSI_DEFAULT_OUTPUT_SUBDIR="mkosi.output"
# The specific EFI file to copy
EFI_FILE_NAME="archlinux-rescue.efi" # Or whatever mkosi generates
# Directory where the final image files will be copied
BACKUP_DIR="/efi/EFI/Backup"
# ---------------------

echo "--- Pacman hook triggered: Starting mkosi build process from temporary directory ---"

# --- Ensure directories exist ---
if [ ! -d "$MKOSI_SOURCE_DIR" ]; then
    echo "Error: mkosi source configuration directory '$MKOSI_SOURCE_DIR' not found." >&2
    exit 1
fi
mkdir -p "$BACKUP_DIR"
mkdir -p "$MKOSI_TEMP_DIR" # Create the unique temporary build directory

# --- Copy mkosi configuration to temporary directory ---
echo "Copying mkosi configuration from $MKOSI_SOURCE_DIR to $MKOSI_TEMP_DIR..."
echo "cp -rv "$MKOSI_SOURCE_DIR/*" "$MKOSI_TEMP_DIR/""
cp -rv "$MKOSI_SOURCE_DIR"/* "$MKOSI_TEMP_DIR"/
echo "Copy complete."

# --- Build the mkosi image from the temporary directory ---
# mkosi build will exit with non-zero status on failure,
# which set -e will catch, stopping the script.
echo "Running mkosi build from temporary directory $MKOSI_TEMP_DIR..."
cd "$MKOSI_TEMP_DIR"
mkosi -f # Build without --output uses the default path relative to CWD
echo "mkosi build successful."

# --- Copy the specific EFI file to backup location ---
SOURCE_EFI_PATH="$MKOSI_TEMP_DIR/$MKOSI_DEFAULT_OUTPUT_SUBDIR/$EFI_FILE_NAME"
TARGET_EFI_PATH="$BACKUP_DIR/$EFI_FILE_NAME"

# Check if the specific file exists after build in the temporary output
if [ -f "$SOURCE_EFI_PATH" ]; then
    echo "Copying $EFI_FILE_NAME from $SOURCE_EFI_PATH to $BACKUP_DIR/..."
    # Ensure target directory exists (already done, but safe double-check)
    mkdir -p "$BACKUP_DIR"
    cp "$SOURCE_EFI_PATH" "$TARGET_EFI_PATH"
    echo "$EFI_FILE_NAME copied successfully."
else
    echo "Warning: Built file '$SOURCE_EFI_PATH' not found after mkosi build in temporary output." >&2
    # Decide if you want to exit here or continue to clean cache/cleanup temp dir
    # exit 1
fi

# --- Clean up mkosi cache specific to the temporary build ---
# This cleans the cache associated with the configuration in $MKOSI_TEMP_DIR
# This only runs if the mkosi build AND the copy command (if file exists) were successful due to set -e
echo "Cleaning mkosi cache for $MKOSI_TEMP_DIR..."
mkosi -C "$MKOSI_TEMP_DIR" clean
echo "Temporary mkosi cache cleaned."

# --- Clean up the temporary build directory ---
echo "Cleaning up temporary build directory $MKOSI_TEMP_DIR..."
# Use `|| true` so the script doesn't exit if rm fails for some reason during cleanup
rm -rf "$MKOSI_TEMP_DIR" || true
echo "Temporary build directory cleaned."


echo "Signing the EFI Application."
sbctl sign-all

echo "--- mkosi build process finished ---"

exit 0
