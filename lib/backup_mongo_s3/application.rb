module BackupMongoS3
  class Application

    def initialize(argv)
      @parser = OptionParser.new

      @params = parse_options(argv)
      @config = parse_config(@params[:config])

      @db      = Db.new(@config[:mongo])
      @storage = Storage.new(@config[:s3])
    end

    public

    def run

      case
        when @params[:backups_list] # BACKUPS_LIST
          show_backups_list(@params[:backups_list])

        when @params[:backup_all] # BACKUP_ALL
          dbs_str = @config[:backup][:dbs]

          if dbs_str.nil? || dbs_str.empty?
            raise 'config.yml::backup.dbs is empty'
          end

          dbs_name = dbs_str.split(',').each { |db_name| db_name.strip! }

          backup(dbs_name)

        when @params[:backup] # BACKUP
          backup([@params[:backup]])

        when @params[:restore] # RESTORE
          if @params[:backup_date].nil?
            raise 'param --date BACKUP_DATE is not specified'
          end

          restore(@params[:restore], @params[:backup_date])

        when @params[:cron_update] || @params[:cron_clear] # CRON
          cron_options =
              {
                  update: @params[:cron_update],
                  clear:  @params[:cron_clear],
                  config: @params[:config],
                  time:   @config[:backup][:cron_time],
              }

          Scheduler.new(cron_options).execute

        else
          puts "\n#{@parser}\n"
          exit
      end

    end

    private

    def show_backups_list(db_name)

      backups = @storage.get_backups_list("#{db_name}")

      if backups.empty?
        puts 'Backups not found'
      else

        puts sprintf('%-30s %-15s %-20s', 'name', 'size, MB', 'last_modified')

        backups.each do |backup|

          backup_name          = File.join(File.dirname(backup.key), File.basename(backup.key, '.backup'))
          backup_size          = backup.content_length / 1024 / 1024
          backup_last_modified = backup.last_modified

          puts sprintf('%-30s %-15s %-20s', backup_name, backup_size, backup_last_modified)
        end

      end
    end

    def backup(dbs_name)

      history_days_str = @config[:backup][:history_days]

      begin
        history_days = history_days_str.to_i
      rescue
        raise 'config.yml::backup.history_days is not integer'
      end

      dbs_name.each do |db_name|

        puts "backup db #{db_name.upcase}:"

        tmp_dir = get_temp_dir(@config[:temp_directory])

        begin

          dump_path = File.join(tmp_dir, db_name)

          puts "\t dump db..."
          @db.dump(db_name, tmp_dir)

          if Dir["#{dump_path}/*"].empty?
            puts "\t [skip] db is empty"

          else

            puts "\t compress..."
            system("zip -6 -r '#{dump_path}.zip' '#{dump_path}/' -j > /dev/null")
            raise 'Error zip' unless $?.exitstatus.zero?

            FileUtils.rm_rf(dump_path)

            zip_file_path = "#{dump_path}.zip"

            if File.exists?(zip_file_path)
              puts "\t upload backup to s3..."
              @storage.upload(db_name, zip_file_path)

              puts "\t delete old backups from s3..."
              @storage.delete_old_backups(db_name, history_days)

              File.delete(zip_file_path)
            end

          end

        ensure
          FileUtils.remove_entry_secure(tmp_dir)
        end

      end

      puts '[done] backup'
    end


    def restore(db_name, date)

      puts "restore db #{db_name.upcase}:"

      tmp_dir = get_temp_dir(@config[:temp_directory])

      begin

        dump_path = File.join(tmp_dir, db_name)

        zip_file_path = "#{dump_path}.zip"

        puts "\t download file from s3..."
        @storage.download(db_name, date, zip_file_path)

        if File.exists?(zip_file_path)
          puts "\t uncompress..."
          system("unzip '#{zip_file_path}' -d '#{dump_path}' > /dev/null")
          raise 'Error unzip' unless $?.exitstatus.zero?

          File.delete(zip_file_path)

          puts "\t restore db..."
          @db.restore(db_name, dump_path)
        end

      ensure
        FileUtils.remove_entry_secure(tmp_dir)
      end

      puts '[done] restore'
    end

    def create_config(path)

      path = '.' if path.nil? || path == ''

      file = File.join(path, 'config.yml')

      if File.exists?(file)
        raise "create_config: '#{file}' already exists"
      elsif File.exists?(file.downcase)
        raise "create_config: '#{file.downcase}' exists, which could conflict with '#{file}'"
      elsif !File.exists?(File.dirname(file))
        raise "create_config: directory '#{File.dirname(file)}' does not exist"
      else
        file_template = File.join(BackupMongoS3.root_path, 'lib/helpers/config.yml.template')

        FileUtils.cp file_template, file
      end

      puts "[done] file #{file} was created"
    end

    def parse_options(argv)
      params = {}

      @parser.on('--backup_all', 'Backup databases specified in config.yml and upload to S3 bucket') do
        params[:backup_all] = true
      end
      @parser.on('--backup DB_NAME', String, 'Backup database and upload to S3 bucket') do |db_name|
        params[:backup] = db_name
      end
      @parser.on('-r', '--restore DB_NAME', String, 'Restore database from BACKUP_DATE backup') do |db_name|
        params[:restore] = db_name
      end
      @parser.on('-d', '--date BACKUP_DATE', String, 'Restore date YYYYMMDD') do |backup_date|
        params[:backup_date] = backup_date
      end
      @parser.on('-l', '--list_backups [DB_NAME]', String, 'Show list of available backups') do |db_name|
        params[:backups_list] = db_name || ''
      end
      @parser.on('--write_cron', 'Add/update backup_all job') do
        params[:cron_update] = true
      end
      @parser.on('--clear_cron', 'Clear backup_all job') do
        params[:cron_clear] = true
      end
      @parser.on('-c', '--config PATH', String, 'Path to config *.yml. Default ./config.yml') do |path|
        params[:config] = path || ''
      end
      @parser.on('--create_config [PATH]', String, 'Create template config.yml in current/PATH directory') do |path|
        create_config(path)
        exit
      end
      @parser.on('-c', '--config PATH', String, 'Path to config *.yml. Default ./config.yml') do |path|
        params[:config] = path || ''
      end
      @parser.on('-h', '--help', 'Show help') do
        puts "\n#{@parser}\n"
        exit
      end

      begin
        @parser.parse!(argv)

      rescue OptionParser::ParseError => err
        puts "#{err.message}\n\n#{@parser}"
        exit
      end

      if [params[:backup_all], params[:backup], params[:restore], params[:backups_list], params[:cron_update], params[:cron_clear]].compact.length > 1
        raise 'Can only backup_all, backup, restore, backups_list, cron_update or cron_clear. Choose one.'
      end

      if params[:config].nil? || params[:config] == ''
        params[:config] = './config.yml'
      end

      params[:config] = File.absolute_path(params[:config])

      params
    end

    def parse_config(config_path)

      begin
        config = YAML.load(File.read(config_path))
      rescue Errno::ENOENT
        raise "Could not find config file '#{config_path}'"
      rescue ArgumentError => err
        raise "Could not parse config file '#{config_path}' - #{err}"
      end

      config.deep_symbolize_keys!

      raise 'config.yml. Section <backup> not found' if config[:backup].nil?
      raise 'config.yml. Section <mongo> not found' if config[:mongo].nil?
      raise 'config.yml. Section <s3> not found' if config[:s3].nil?

      config
    end

    def get_temp_dir(temp_dir)
      if temp_dir.nil? || temp_dir == ''
        temp_dir = Dir.tmpdir
      end

      Dir.mktmpdir(nil, temp_dir)
    end

  end
end