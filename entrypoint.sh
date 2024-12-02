#!/bin/bash

# Function to validate environment variables
validate_env() {
    if [ -z "$1" ]; then
        echo "Error: Required environment variable $2 is not set."
        exit 1
    fi
}

# Validate essential environment variables
validate_env "$SOURCE_ENDPOINT" "SOURCE_ENDPOINT"
validate_env "$SOURCE_ACCESS_KEY" "SOURCE_ACCESS_KEY"
validate_env "$SOURCE_SECRET_KEY" "SOURCE_SECRET_KEY"
validate_env "$SOURCE_BUCKET" "SOURCE_BUCKET"

validate_env "$DEST_ENDPOINT" "DEST_ENDPOINT"
validate_env "$DEST_ACCESS_KEY" "DEST_ACCESS_KEY"
validate_env "$DEST_SECRET_KEY" "DEST_SECRET_KEY"
validate_env "$DEST_BUCKET" "DEST_BUCKET"

# Configure aliases for source and destination
mc alias set source "$SOURCE_ENDPOINT" "$SOURCE_ACCESS_KEY" "$SOURCE_SECRET_KEY"
mc alias set dest "$DEST_ENDPOINT" "$DEST_ACCESS_KEY" "$DEST_SECRET_KEY"

# Use TIMESTAMP_FILE environment variable, or default to /app/last_sync_time
TIMESTAMP_FILE=${TIMESTAMP_FILE:-"/app/last_sync_time"}
SYNC_INTERVAL=${SYNC_INTERVAL:-60}

# Validate connectivity to source and destination buckets
echo "Validating connectivity to source bucket..."
mc ls source/"$SOURCE_BUCKET" > /dev/null || { echo "Error: Unable to access source bucket."; exit 1; }

echo "Validating connectivity to destination bucket..."
mc ls dest/"$DEST_BUCKET" > /dev/null || { echo "Error: Unable to access destination bucket."; exit 1; }

# Start loop for continuous synchronization
while true; do
    if [ -f "$TIMESTAMP_FILE" ]; then
        # Read the last sync timestamp
        LAST_SYNC_TIME=$(cat "$TIMESTAMP_FILE")

        # Convert ISO 8601 timestamp to relative time
        NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        SECONDS_DIFF=$(( $(date -d "$NOW" +%s) - $(date -d "$LAST_SYNC_TIME" +%s) ))

        if [ "$SECONDS_DIFF" -le 0 ]; then
            echo "Error: Invalid timestamp difference. Skipping sync."
            SECONDS_DIFF=0
        fi

        RELATIVE_TIME="${SECONDS_DIFF}s"
        echo "Starting synchronization for files newer than $RELATIVE_TIME..."

        mc mirror --newer-than "$RELATIVE_TIME" source/"$SOURCE_BUCKET" dest/"$DEST_BUCKET"
    else
        echo "No timestamp found. Starting synchronization from scratch (all files)."
        mc mirror source/"$SOURCE_BUCKET" dest/"$DEST_BUCKET"
    fi

    # Update the timestamp file with the current UTC time
    date -u +"%Y-%m-%dT%H:%M:%SZ" > "$TIMESTAMP_FILE"

    echo "Synchronization completed. Waiting for the next round in $SYNC_INTERVAL seconds..."

    # Wait for the specified interval before the next synchronization
    sleep "$SYNC_INTERVAL"
done