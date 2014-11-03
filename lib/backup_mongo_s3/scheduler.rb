module BackupMongoS3
  class Scheduler

    def initialize(options = {})
      @options = options

      if [@options[:write], @options[:clear]].compact.length > 1
        raise 'cron: Can only write or clear. Choose one.'
      end

      unless @options[:time] =~ /\A[*\-,0-9]+ [*\-,0-9]+ [*\-,0-9]+ [*\-,0-9]+ [*\-,0-6]+\z/
        raise 'config.yml: cron_time is not valid'
      end
    end

    def execute
      write_crontab(updated_crontab)
    end

    private

    def read_crontab
      return @read_crontab if @read_crontab

      command = 'crontab -l'

      command_results = %x[#{command} 2> /dev/null]

      @read_crontab = $?.exitstatus.zero? ? prepare(command_results) : ''
    end

    def prepare(contents)
      # Some cron implementations require all non-comment lines to be newline-
      # terminated. (issue #95) Strip all newlines and replace with the default
      # platform record seperator ($/)
      contents.gsub!(/\s+$/, $/)
    end

    def write_crontab(contents)
      command = 'crontab -'

      IO.popen(command, 'r+') do |crontab|
        crontab.write(contents)
        crontab.close_write
      end

      success = $?.exitstatus.zero?

      if success
        action = @options[:update] ? 'updated' : 'cleared'
        puts "[done] crontab file #{action}"
        exit(0)
      else
        raise "Couldn't write crontab"
      end
    end

    def updated_crontab
      # Check for unopened or unclosed identifier blocks
      if read_crontab =~ Regexp.new("^#{comment_open}\s*$") && (read_crontab =~ Regexp.new("^#{comment_close}\s*$")).nil?
        raise "Unclosed indentifier; Your crontab file contains '#{comment_open}', but no '#{comment_close}'"
      elsif (read_crontab =~ Regexp.new("^#{comment_open}\s*$")).nil? && read_crontab =~ Regexp.new("^#{comment_close}\s*$")
        raise "Unopened indentifier; Your crontab file contains '#{comment_close}', but no '#{comment_open}'"
      end

      # If an existing identier block is found, replace it with the new cron entries
      if read_crontab =~ Regexp.new("^#{comment_open}\s*$") && read_crontab =~ Regexp.new("^#{comment_close}\s*$")
        # If the existing crontab file contains backslashes they get lost going through gsub.
        # .gsub('\\', '\\\\\\') preserves them. Go figure.
        read_crontab.gsub(Regexp.new("^#{comment_open}\s*$.+^#{comment_close}\s*$", Regexp::MULTILINE), crontab_task.chomp.gsub('\\', '\\\\\\'))
      else # Otherwise, append the new cron entries after any existing ones
        [read_crontab, crontab_task].join("\n\n")
      end.gsub(/\n{3,}/, "\n\n") # More than two newlines becomes just two.
    end

    def crontab_task
      return '' if @options[:clear]
      [comment_open, crontab_job, comment_close].compact.join("\n") + "\n"
    end

    def crontab_job
      "#{@options[:time]} /bin/bash -l -c '#{BackupMongoS3.name} --backup_all --config #{@options[:config]}'"
    end

    def comment_base
      "#{BackupMongoS3.name} task"
    end

    def comment_open
      "# Begin #{comment_base}"
    end

    def comment_close
      "# End #{comment_base}"
    end
  end
end