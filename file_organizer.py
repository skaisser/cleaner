import os
import shutil
import hashlib
from datetime import datetime
import logging
from pathlib import Path
import mimetypes

class FileOrganizer:
    def __init__(self, source_dir, dest_dir):
        self.source_dir = Path(source_dir)
        self.dest_dir = Path(dest_dir)
        self.setup_logging()
        self.duplicate_count = 0
        self.organized_count = 0
        
        # Define main category directories
        self.categories = {
            'images': ['.jpg', '.jpeg', '.png', '.gif', '.bmp'],
            'videos': ['.mp4', '.mov', '.avi', '.mkv'],
            'documents': ['.pdf', '.doc', '.docx', '.txt', '.xls', '.xlsx', '.xlt'],
            'contracts': ['.zip'],  # Assuming contract files are in zip format
            'web': ['.html', '.htm', '.css', '.js']
        }
        
        # Create category directories
        for category in self.categories:
            os.makedirs(self.dest_dir / category, exist_ok=True)

    def setup_logging(self):
        logging.basicConfig(
            filename=self.dest_dir / 'file_organizer.log',
            level=logging.INFO,
            format='%(asctime)s - %(message)s'
        )
        self.logger = logging

    def get_file_hash(self, filepath):
        """Calculate SHA-256 hash of file to identify duplicates"""
        hasher = hashlib.sha256()
        with open(filepath, 'rb') as f:
            buf = f.read(65536)  # Read in 64kb chunks
            while len(buf) > 0:
                hasher.update(buf)
                buf = f.read(65536)
        return hasher.hexdigest()

    def get_category(self, file_extension):
        """Determine category based on file extension"""
        for category, extensions in self.categories.items():
            if file_extension.lower() in extensions:
                return category
        return 'misc'  # For uncategorized files

    def organize_file(self, filepath):
        """Organize a single file into appropriate category directory"""
        try:
            file_path = Path(filepath)
            if not file_path.is_file():
                return

            # Get file category
            file_extension = file_path.suffix
            category = self.get_category(file_extension)
            
            # Create category directory if it doesn't exist
            category_dir = self.dest_dir / category
            os.makedirs(category_dir, exist_ok=True)

            # Generate new filename with timestamp
            timestamp = datetime.fromtimestamp(os.path.getctime(filepath))
            new_filename = f"{timestamp.strftime('%Y%m%d_%H%M%S')}_{file_path.name}"
            new_filepath = category_dir / new_filename

            # Check for duplicates using hash
            file_hash = self.get_file_hash(filepath)
            
            # If file already exists, append counter to filename
            counter = 1
            while new_filepath.exists():
                if self.get_file_hash(new_filepath) == file_hash:
                    self.logger.info(f"Duplicate file found: {filepath}")
                    self.duplicate_count += 1
                    return
                base = new_filepath.stem
                new_filepath = category_dir / f"{base}_{counter}{file_extension}"
                counter += 1

            # Copy file to new location
            shutil.copy2(filepath, new_filepath)
            self.organized_count += 1
            self.logger.info(f"Organized: {filepath} -> {new_filepath}")

        except Exception as e:
            self.logger.error(f"Error organizing {filepath}: {str(e)}")

    def organize_directory(self, directory=None):
        """Recursively organize all files in directory"""
        if directory is None:
            directory = self.source_dir

        try:
            for item in os.scandir(directory):
                if item.is_file():
                    self.organize_file(item.path)
                elif item.is_dir():
                    self.organize_directory(item.path)

        except Exception as e:
            self.logger.error(f"Error processing directory {directory}: {str(e)}")

    def get_statistics(self):
        """Return organization statistics"""
        return {
            'organized_files': self.organized_count,
            'duplicates_found': self.duplicate_count
        }

def main():
    # Get source and destination directories from user
    source_dir = input("Enter source directory path: ")
    dest_dir = input("Enter destination directory path: ")

    # Create and run organizer
    organizer = FileOrganizer(source_dir, dest_dir)
    
    print("Starting file organization...")
    organizer.organize_directory()
    
    # Print statistics
    stats = organizer.get_statistics()
    print(f"\nOrganization complete!")
    print(f"Files organized: {stats['organized_files']}")
    print(f"Duplicates found: {stats['duplicates_found']}")
    print(f"Check {dest_dir}/file_organizer.log for detailed information")

if __name__ == "__main__":
    main()
