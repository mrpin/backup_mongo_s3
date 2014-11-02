# BackupMongoS3

Command-line application for MongoDB backup(mongodump/mongorestore) to Amazon S3

## Installation

Add this line to your application's Gemfile:

    gem 'backup_mongo_s3'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install backup_mongo_s3

## Help:

Usage: backup_mongo_s3 [options]
        --backup_all                 Backup databases specified in config.yml and upload to S3 bucket
        --backup DB_NAME             Backup database and upload to S3 bucket
    -r, --restore DB_NAME            Restore database from BACKUP_DATE backup
    -d, --date BACKUP_DATE           Restore date YYYYMMDD
    -l, --list_backups [DB_NAME]     Show list of available backups
        --write_cron                 Add/update backup_all job
        --clear_cron                 Clear backup_all job
    -c, --config PATH                Path to config *.yml. Default: ./config.yml
        --create_config [PATH]       Create template config.yml in current/PATH directory
    -h, --help                       Show help
