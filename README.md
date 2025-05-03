# 🧹 Cleaner

A powerful and safe command-line utility to clean up junk files and empty directories. This tool helps you maintain a tidy filesystem by removing various types of unnecessary files while including safety features like dry-run mode and file age filtering.

## 🔍 Features

- Removes empty (0 byte) files
- Cleans system junk files (.DS_Store, Thumbs.db, etc.)
- Removes temporary files (*.tmp, *.bak, *~)
- Deletes Google Drive web files (*.gdoc, *.gsheet, etc.)
- Removes Windows shortcuts (*.url, *.lnk)
- Cleans XML files in video directories
- Removes empty directories
- Includes safety features:
  - Dry-run mode to preview changes
  - File age filtering
  - Interactive confirmation prompt
  - Detailed logging

## 📋 Requirements

- Unix-like environment (Linux, macOS)
- Bash shell
- Basic command-line utilities (`find`, `du`, etc.)

## 🚀 Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/cleaner.git
   ```

2. Make the script executable:
   ```bash
   chmod +x cleaner.sh
   ```

## 💻 Usage

Basic usage:
```bash
./cleaner.sh /path/to/clean
```

### Options

- `-d, --dry-run`: Show what would be deleted without actually deleting
- `-f, --force`: Skip confirmation prompt (useful for cron jobs)
- `-a, --age DAYS`: Only delete files older than DAYS days
- `-l, --log-dir DIR`: Directory to store log files (default: script's directory)
- `-h, --help`: Show help message

### Examples

Preview what would be deleted:
```bash
./cleaner.sh --dry-run /path/to/clean
```

Clean without prompting (for automated tasks):
```bash
./cleaner.sh --force /path/to/clean
```

Delete files older than 30 days:
```bash
./cleaner.sh --force --age 30 /path/to/clean
```

Specify custom log directory:
```bash
./cleaner.sh --log-dir /var/log/cleanup /path/to/clean
```

## 📝 Logs

The script creates detailed logs of all operations in the format:
```
clean_empty_and_junk-YYYYMMDD-HHMMSS.log
```

By default, logs are stored in the same directory as the script. Use `--log-dir` to specify a different location.

## ⚠️ Safety Features

1. **Dry Run Mode**: Use `--dry-run` to preview what would be deleted
2. **Interactive Confirmation**: Prompts for confirmation before deletion (unless using `--force`)
3. **Protected Directories**: Automatically skips `.git` and `node_modules` directories
4. **Permission Checks**: Verifies read/write permissions before starting
5. **File Age Filter**: Optional deletion of files only older than specified days

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
