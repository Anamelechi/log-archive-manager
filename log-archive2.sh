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
        echo -e "$body" | mail -s "$subject" "$EMAIL_RECIPIENT"
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
        return 1 # Indicate failure
    fi

    if [ -z "$days_to_keep_logs" ]; then
        echo "Warning: Number of days to keep logs is not set (Option 2). Using default of 7 days."
        days_to_keep_logs="7"
    fi

    if [ -z "$days_to_keep_backups" ]; then
        echo "Warning: Number of days to keep backup archives is not set (Option 3). Using default of 30 days."
        days_to_keep_backups="30"
    fi

    local archive_dir="$log_dir/$ARCHIVE_DIR_NAME"
    local error_capture_file
    error_capture_file=$(mktemp)
    # Ensure cleanup of the temp file on function exit or script termination
    trap 'rm -f "$error_capture_file"' RETURN EXIT

    if ! mkdir -p "$archive_dir"; then
        local err_msg="Error: Could not create archive directory '$archive_dir'."
        echo "$err_msg"
        # Attempt to read specifics if any standard utility wrote to stderr (though mkdir -p is usually quiet or just fails)
        # For mkdir, the error is usually implicit in its non-zero exit code.
        send_email "$EMAIL_SUBJECT_FAILURE" "Log archiving failed: $err_msg Creation failed on $(date)."
        return 1
    fi

    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local archive_file="$archive_dir/${ARCHIVE_FILE_PREFIX}_$timestamp.${ARCHIVE_FILE_EXTENSION}"

    echo "Searching for logs older than $days_to_keep_logs days in $log_dir..."
    > "$error_capture_file" # Clear/create error capture file

    mapfile -t files_found < <(find "$log_dir" -maxdepth 1 -type f -mtime +"$days_to_keep_logs" -print 2> "$error_capture_file")
    local find_check_status=$?
    local find_check_errors
    find_check_errors=$(<"$error_capture_file")

    if [ $find_check_status -ne 0 ]; then
        echo "Error: 'find' command failed while checking for logs to archive."
        echo "Error details: $find_check_errors"
        send_email "$EMAIL_SUBJECT_FAILURE" "Log archiving failed: 'find' command (pre-check) failed on $(date).\n\nError output:\n$find_check_errors"
        return 1
    fi

    if [ ${#files_found[@]} -eq 0 ]; then
        echo "No logs older than $days_to_keep_logs days found to archive in $log_dir."
        # No new logs to archive, but still proceed to clean up old backups
    else
        echo "Found ${#files_found[@]} log file(s) to archive. Archiving to $archive_file"
        > "$error_capture_file" # Clear error file for the archiving pipeline

        # Perform archiving: find | tar
        # The subshell `(...)` is used to correctly capture PIPESTATUS for the commands within the pipe.
        (find "$log_dir" -maxdepth 1 -type f -mtime +"$days_to_keep_logs" -print0 | \
         tar -czvf "$archive_file" --null -T - ) 2> "$error_capture_file"
        
        local pipe_statuses=("${PIPESTATUS[@]}") # Capture exit statuses of all commands in the pipe
        local find_archive_status=${pipe_statuses[0]}
        local tar_archive_status=${pipe_statuses[1]}
        local archive_errors
        archive_errors=$(<"$error_capture_file")

        if [ $find_archive_status -ne 0 ]; then
            echo "Error: 'find' command failed during archiving pipeline."
            echo "Error details: $archive_errors"
            send_email "$EMAIL_SUBJECT_FAILURE" "Log archiving failed: 'find' command in pipeline failed on $(date).\n\nError output:\n$archive_errors"
            return 1
        elif [ $tar_archive_status -ne 0 ]; then
            echo "Error: 'tar' command failed during archiving."
            echo "Error details: $archive_errors"
            send_email "$EMAIL_SUBJECT_FAILURE" "Log archiving failed: 'tar' command failed on $(date).\n\nError output:\n$archive_errors"
            return 1
        else
            # Archiving successful
            echo "Logs archived in $archive_file on $(date)" >> "$archive_dir/$LOG_ARCHIVE_LOG_FILE"
            echo "Archiving completed successfully: $archive_file"
            send_email "$EMAIL_SUBJECT_SUCCESS" "Logs archived successfully in $archive_file on $(date)."

            # Delete original logs that were archived
            echo "Deleting original logs older than $days_to_keep_logs days from $log_dir"
            > "$error_capture_file" # Clear error file for delete operation
            find "$log_dir" -maxdepth 1 -type f -mtime +"$days_to_keep_logs" -delete 2> "$error_capture_file"
            local delete_status=$?
            local delete_errors
            delete_errors=$(<"$error_capture_file")
            if [ $delete_status -ne 0 ]; then
                echo "Error: Deleting original logs failed."
                echo "Error details: $delete_errors"
                send_email "$EMAIL_SUBJECT_FAILURE" "Log archiving successful, BUT deleting original logs failed on $(date).\n\nError output:\n$delete_errors"
                # Continue to deleting old backups, as this is a partial failure
            fi
        fi
    fi # End of 'if files_found to archive'

    # Delete old backup archives (this runs regardless of whether new logs were archived in this run)
    echo "Deleting backup archives older than $days_to_keep_backups days from $archive_dir"
    > "$error_capture_file" # Clear error file
    find "$archive_dir" -maxdepth 1 -type f -name "*.${ARCHIVE_FILE_EXTENSION}" -mtime +"$days_to_keep_backups" -delete 2> "$error_capture_file"
    local delete_backup_status=$?
    local delete_backup_errors
    delete_backup_errors=$(<"$error_capture_file")

    if [ $delete_backup_status -ne 0 ]; then
        echo "Error: Deleting old backup archives failed."
        echo "Error details: $delete_backup_errors"
        send_email "$EMAIL_SUBJECT_FAILURE" "Log archiving maintenance: Deleting old backup archives failed on $(date).\n\nError output:\n$delete_backup_errors"
    else
        if [ -n "$delete_backup_errors" ]; then # find might succeed (status 0) but still print to stderr
             echo "Deletion of old backup archives older than $days_to_keep_backups days completed. Note: Some messages were generated during the process:"
             echo "$delete_backup_errors"
        else
             echo "Deletion of old backup archives older than $days_to_keep_backups days completed successfully."
        fi
    fi
    # rm -f "$error_capture_file" is handled by trap
    return 0 # Indicates the overall process attempted completion
}


# Function to set up cron job
setup_cron() {
    read -r -p "Do you want to add this script to cron for automated execution? (y/n) " choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        read -r -p "Enter the desired cron schedule (e.g., 0 2 * * 0 for weekly at 2 AM): " cron_schedule
        if [ -n "$cron_schedule" ]; then
            local script_path
            script_path=$(realpath "$0") # Get absolute path to the script
            # Check if log_dir is set for non-interactive mode; cron needs all settings.
            if [ -z "$log_dir" ] || [ -z "$days_to_keep_logs" ] || [ -z "$days_to_keep_backups" ]; then
                 echo "Warning: For cron automation, ensure Log Directory, Days to Keep Logs, and Days to Keep Backups are set."
                 echo "The script will rely on its current internal defaults (if any) or might fail if these are not configured."
                 echo "You may need to edit the script to hardcode these if running non-interactively without prior setup via menu."
            fi

            local cron_line="$cron_schedule $script_path auto_archive_cron_trigger" # Add a dummy argument
            (crontab -l 2>/dev/null | grep -v "$script_path auto_archive_cron_trigger"; echo "$cron_line") | crontab -
            echo "Cron job added: $cron_line"
            echo "IMPORTANT: For cron automation, this script uses its current settings (log directory, retention days)."
            echo "Ensure these are configured appropriately (options 1-3, 5) before relying on the cron job."
            echo "Alternatively, edit the script to set default values for these variables at the top."
            echo "The cron job will effectively call '$script_path auto_archive_cron_trigger'."
            echo "You should modify the script to handle this argument for non-interactive execution if needed."
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
# EMAIL_RECIPIENT is global

# --- Non-interactive trigger for cron ---
# If the script is called with "auto_archive_cron_trigger", run archive_logs_process and exit.
if [ "$1" == "auto_archive_cron_trigger" ]; then
    echo "Cron job execution started: Log Archiving Process"
    # Set defaults if variables are empty - crucial for cron
    log_dir="${log_dir:-/var/log}" # Default log directory for cron if not set
    days_to_keep_logs="${days_to_keep_logs:-7}"   # Default days to keep logs
    days_to_keep_backups="${days_to_keep_backups:-30}" # Default days to keep backups
    # EMAIL_RECIPIENT is already defaulted or can be set here too.

    if [ -z "$EMAIL_RECIPIENT" ]; then
        echo "Warning: EMAIL_RECIPIENT is not set for cron job. Notifications might not be sent."
    fi
    
    archive_logs_process
    exit $?
fi
# --- End Non-interactive trigger ---


auto_progress_next_option=0 # 0 = prompt user, 1-6 = process this option

while true; do
    current_operation_choice=""

    if [ "$auto_progress_next_option" -ne 0 ] && [ "$auto_progress_next_option" -le 6 ]; then # Max option 6
        current_operation_choice="$auto_progress_next_option"
    else
        echo ""
        echo "--- Log Archive Tool ---"
        echo "1. Specify Log Directory [Current: ${log_dir:-Not Set}]"
        echo "2. Specify Number of Days to Keep Logs [Current: ${days_to_keep_logs:-Not Set (Default 7 on run)}]"
        echo "3. Specify Number of Days to Keep Backup Archives [Current: ${days_to_keep_backups:-Not Set (Default 30 on run)}]"
        echo "4. Run Log Archiving Process"
        echo "5. Set Email Recipient [Current: ${EMAIL_RECIPIENT:-Not Set}]"
        echo "6. Setup Cron Job"
        echo "7. Exit"
        echo ""
        read -r -p "Choose an option (1-7): " current_operation_choice
    fi

    next_option_after_this=0 # Default: go back to manual selection (menu)

    case $current_operation_choice in
        1)
            log_dir_default="${log_dir:-/var/log}"
            log_dir=$(prompt_for_input "Enter the log directory" "$log_dir_default")
            if check_directory "$log_dir"; then
                echo "Log directory set to $log_dir"
                next_option_after_this=2 # Progress to option 2
            else
                log_dir="" # Clear if invalid
                next_option_after_this=0 # Stay on menu
            fi
            ;;
        2)
            days_to_keep_logs_default="${days_to_keep_logs:-7}"
            days_to_keep_logs=$(prompt_for_input "How many days of logs do you want to keep?" "$days_to_keep_logs_default")
            # Basic validation: check if it's a number (optional, find will fail otherwise)
            if ! [[ "$days_to_keep_logs" =~ ^[0-9]+$ ]]; then
                echo "Warning: '$days_to_keep_logs' is not a valid number. Using default of 7 if archiving is run."
                # days_to_keep_logs="7" # Or clear it, or let find handle the error
            fi
            echo "Logs older than $days_to_keep_logs days will be archived and deleted."
            next_option_after_this=3 # Progress to option 3
            ;;
        3)
            days_to_keep_backups_default="${days_to_keep_backups:-30}"
            days_to_keep_backups=$(prompt_for_input "How many days of backup archives do you want to keep?" "$days_to_keep_backups_default")
            if ! [[ "$days_to_keep_backups" =~ ^[0-9]+$ ]]; then
                echo "Warning: '$days_to_keep_backups' is not a valid number. Using default of 30 if archiving is run."
            fi
            echo "Backup archives older than $days_to_keep_backups days will be deleted."
            next_option_after_this=4 # Progress to option 4 (Run)
            ;;
        4)
            archive_logs_process
            next_option_after_this=0 # Back to menu
            ;;
        5)
            email_default="${EMAIL_RECIPIENT}"
            EMAIL_RECIPIENT=$(prompt_for_input "Enter the email address to send notifications to" "$email_default")
            if [ -n "$EMAIL_RECIPIENT" ]; then
                 echo "Email recipient set to $EMAIL_RECIPIENT"
            else
                 echo "Email recipient cleared. Notifications will be skipped."
            fi
            next_option_after_this=6 # Progress to option 6 (Cron setup)
            ;;
        6)
            setup_cron
            next_option_after_this=0 # Back to menu
            ;;
        7)
            echo "Exiting..."
            # Clean up trap if it was set by archive_logs_process and script exits from here.
            # The trap includes EXIT so it should fire anyway.
            trap - RETURN EXIT # Clear traps just in case
            exit 0
            ;;
        *)
            echo "Invalid option. Please choose a number between 1 and 7."
            next_option_after_this=0 # Back to menu
            ;;
    esac
    auto_progress_next_option="$next_option_after_this"
done