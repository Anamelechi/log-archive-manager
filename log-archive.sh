#!/bin/bash

# Script to archive and manage logs interactively

# --- Configuration ---
ARCHIVE_DIR_NAME="archive"
ARCHIVE_FILE_PREFIX="logs_archive"
ARCHIVE_FILE_EXTENSION="tar.gz"
LOG_ARCHIVE_LOG_FILE="archive_log.txt"
EMAIL_RECIPIENT="philznjoku@gmail.com" # Set this in the script or via option
EMAIL_SUBJECT_SUCCESS="Log Archiving Successful"
EMAIL_SUBJECT_FAILURE="Log Archiving Failed"

# --- Functions ---

# Function to prompt for user input with a default option
prompt_for_input() {
    read -r -p "$1 [$2]: " input
    echo "${input:-$2}"
}

# Function to check if a directory exists
check_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo "Error: Directory '$dir' not found."
        return 1
    fi
    return 0
}

# Function to send an email notification
send_email() {
    local subject="$1"
    local body="$2"
    if [ -n "$EMAIL_RECIPIENT" ]; then
        echo "$body" | mail -s "$subject" "$EMAIL_RECIPIENT"
        if [ $? -eq 0 ]; then
            echo "Email notification sent to $EMAIL_RECIPIENT"
        else
            echo "Error: Failed to send email notification. Make sure 'mail' command is installed and configured."
        fi
    else
        echo "Email recipient not set. Skipping email notification."
    fi
}

# Function to archive logs
archive_logs_process() {
    if [ -z "$log_dir" ]; then
        echo "Error: Log directory is not set. Please set it first (Option 1)."
        return
    fi

    if [ -z "$days_to_keep_logs" ]; then
        echo "Warning: Number of days to keep logs is not set (Option 2). Using default of 7 days."
        days_to_keep_logs="7"
    fi

    if [ -z "$days_to_keep_backups" ]; then
        echo "Warning: Number of days to keep backup archives is not set (Option 3). Using default of 30 days."
        days_to_keep_backups="30"
    fi

    archive_dir="$log_dir/$ARCHIVE_DIR_NAME"
    mkdir -p "$archive_dir"

    timestamp=$(date +"%Y%m%d_%H%M%S")
    archive_file="$archive_dir/${ARCHIVE_FILE_PREFIX}_$timestamp.${ARCHIVE_FILE_EXTENSION}"

    echo "Archiving logs older than $days_to_keep_logs days from $log_dir to $archive_file"

    find "$log_dir" -maxdepth 1 -type f -mtime +"$days_to_keep_logs" -print0 |
    tar -czvf "$archive_file" --null -T -

    local archive_status=$?

    if [ $archive_status -eq 0 ]; then
        echo "Logs archived in $archive_file on $(date)" >> "$archive_dir/$LOG_ARCHIVE_LOG_FILE"
        echo "Archiving completed successfully: $archive_file"
        send_email "$EMAIL_SUBJECT_SUCCESS" "Logs archived successfully in $archive_file on $(date)."

        echo "Deleting logs older than $days_to_keep_logs days from $log_dir"
        find "$log_dir" -maxdepth 1 -type f -mtime +"$days_to_keep_logs" -delete

        echo "Deleting backup archives older than $days_to_keep_backups days from $archive_dir"
        find "$archive_dir" -maxdepth 1 -type f -name "*.${ARCHIVE_FILE_EXTENSION}" -mtime +"$days_to_keep_backups" -delete
        echo "Backup archives older than $days_to_keep_backups days have been deleted."
    else
        echo "Error: Log archiving failed."
        send_email "$EMAIL_SUBJECT_FAILURE" "Log archiving failed on $(date)."
    fi
}

# Function to set up cron job
setup_cron() {
    read -r -p "Do you want to add this script to cron for automated execution? (y/n) " choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        read -r -p "Enter the desired cron schedule (e.g., 0 2 * * 0 for weekly at 2 AM): " cron_schedule
        if [ -n "$cron_schedule" ]; then
            script_path=$(realpath "$0")
            cron_line="$cron_schedule $script_path"
            (crontab -l 2>/dev/null; echo "$cron_line") | crontab -
            echo "Cron job added: $cron_line"
            echo "Make sure to set the log directory and retention policies within the script or via the menu before relying on the cron job."
        else
            echo "Invalid cron schedule provided. Cron job not added."
        fi
    else
        echo "Cron job setup skipped."
    fi
}

# --- Main Interactive Loop ---
log_dir=""
days_to_keep_logs=""
days_to_keep_backups=""

while true; do
    echo ""
    echo "--- Log Archive Tool ---"
    echo "1. Specify Log Directory [Current: ${log_dir:-Not Set}]"
    echo "2. Specify Number of Days to Keep Logs [Current: ${days_to_keep_logs:-Not Set}]"
    echo "3. Specify Number of Days to Keep Backup Archives [Current: ${days_to_keep_backups:-Not Set}]"
    echo "4. Run Log Archiving Process"
    echo "5. Set Email Recipient [Current: ${EMAIL_RECIPIENT:-Not Set}]"
    echo "6. Setup Cron Job"
    echo "7. Exit"
    echo ""

    read -r -p "Choose an option: " choice

    case $choice in
        1)
            log_dir=$(prompt_for_input "Enter the log directory" "/var/log")
            if check_directory "$log_dir"; then
                echo "Log directory set to $log_dir"
            else
                log_dir=""
            fi
            ;;
        2)
            days_to_keep_logs=$(prompt_for_input "How many days of logs do you want to keep?" "7")
            echo "Logs older than $days_to_keep_logs days will be archived and deleted."
            ;;
        3)
            days_to_keep_backups=$(prompt_for_input "How many days of backup archives do you want to keep?" "30")
            echo "Backup archives older than $days_to_keep_backups days will be deleted."
            ;;
        4)
            archive_logs_process
            ;;
        5)
            EMAIL_RECIPIENT=$(prompt_for_input "Enter the email address to send notifications to" "")
            echo "Email recipient set to $EMAIL_RECIPIENT"
            ;;
        6)
            setup_cron
            ;;
        7)
            echo "Exiting..."
            break
            ;;
        *)
            echo "Invalid option. Please choose a number between 1 and 7."
            ;;
    esac
done