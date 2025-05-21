# 🪵 Log Manager Script ⚙️

This script is an interactive command-line tool designed to help you manage your server logs by archiving older logs, setting retention policies, and optionally sending email notifications.

## ✨ Features

* **Interactive Menu:** Provides an easy-to-use menu to configure and run log management tasks. 🖱️
* **Specify Log Directory:** Allows you to define the directory containing the logs you want to manage. 📂
* **Set Log Retention:** Configure the number of days to keep the original log files before they are archived and deleted. 🗓️
* **Set Backup Retention:** Define how many days to keep the archived log files before they are deleted. 💾
* **Run Archiving Process:** Executes the log archiving, deletion of old logs, and deletion of old backups based on your settings. 🚀
* **Optional Email Notifications:** Sends you an email upon successful or failed log archiving. 📧
* **Cron Job Automation:** Helps you set up a cron job to automate the log management process on a schedule. ⏰

## 🛠️ Prerequisites

* A Linux-based operating system.
* Bash shell.
* Standard command-line utilities like `read`, `echo`, `mkdir`, `find`, `tar`, `date`, and `realpath`.
* (Optional) `mail` utility installed and configured for email notifications.

## 💾 Installation

1.  **Download the script:**
    ```bash
    wget https://github.com/Anamelechi/log-archive-manager.git
    ```
    or
    ```bash
    git clone https://github.com/Anamelechi/log-archive-manager.git
    cd log-archive-manager
    ```

2.  **Make the script executable:**
    ```bash
    chmod +x log-manager.sh
    ```

## ⚙️ Usage

1.  **Run the script:**
    ```bash
    sudo ./log-manager.sh
    ```

2.  **Follow the interactive menu:**
    * **1. Specify Log Directory:** Enter the path to the directory containing your logs (e.g., `/var/log`).
    * **2. Specify Number of Days to Keep Logs:** Enter the number of days you want to keep the original log files. Logs older than this will be archived and deleted.
    * **3. Specify Number of Days to Keep Backup Archives:** Enter the number of days you want to keep the archived log files. Archives older than this will be deleted.
    * **4. Run Log Archiving Process:** This will start the archiving, deletion, and backup cleanup process based on your configured settings.
    * **5. Set Email Recipient:** Enter the email address where you want to receive notifications about the log archiving process.
    * **6. Setup Cron Job:** Follow the prompts to set up automated execution of the script using cron.
    * **7. Exit:** Close the script.

## ⚙️ Configuration

You can also configure some settings directly within the script by editing the variables in the `--- Configuration ---` section:

* `ARCHIVE_DIR_NAME`: The name of the directory where archived logs will be stored (default: `archive`).
* `ARCHIVE_FILE_PREFIX`: The prefix for the archived log filenames (default: `logs_archive`).
* `ARCHIVE_FILE_EXTENSION`: The extension for the archived log files (default: `tar.gz`).
* `LOG_ARCHIVE_LOG_FILE`: The name of the log file that records archiving activities (default: `archive_log.txt`).
* `EMAIL_RECIPIENT`: The email address to send notifications to (you can also set this via the menu).
* `EMAIL_SUBJECT_SUCCESS`: The subject line for successful archive emails.
* `EMAIL_SUBJECT_FAILURE`: The subject line for failed archive emails.

## ⏰ Cron Job Automation

You can automate the log archiving process using cron. Here's how:

1.  Run `crontab -e` to edit your crontab file.
2.  Add a line similar to the following (adjust the schedule as needed):

    ```cron
    0 2 * * * /path/to/your/log-manager.sh
    ```

    This example runs the script daily at 2:00 AM. **Remember to replace `/path/to/your/log-manager.sh` with the actual path to the script.**

    You can use online cron schedule generators to find the right schedule for your needs.

## Output Example
![Output](/assets/log-archive-manager.png)

## 📧 Email Notifications

To enable email notifications, make sure you have the `mail` utility installed on your system. You can set the recipient email address via Option 5 in the menu or by directly modifying the `EMAIL_RECIPIENT` variable in the script.

![Output](/assets/log-archive-manager-email.png)

When sudo priviledges is not used to run the command it fails and you do not only get an error notification message you also get the exact error message in  the email.

![Output](/assets/error-message.png)

## 🤝 Contributing

Feel free to contribute to this project by suggesting improvements, reporting issues, or submitting pull requests.

## 📄 License

[MIT License](LICENSE)


This project is part of [roadmap.sh](https://https://roadmap.sh/projects/log-archive-tool) DevOps projects.