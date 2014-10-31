module BackupMongoS3
  class Db

    def initialize(options)
      @connection_options = connection(options)
    end

    private
    def connection(options)

      host     = (options[:host].nil? || options[:host].empty?) ? 'localhost' : options[:host]
      port     = options[:port].nil? ? 27017 : options[:port]
      username = options[:username]
      password = options[:password]

      auth_options = ''

      unless username.nil? || username.empty? || password.nil? || password.empty?
        auth_options = "-u '#{username}' -p '#{password}' --authenticationDatabase 'admin'"
      end

      "--host '#{host}' --port '#{port}' #{auth_options}"
    end

    public
    def dump(db_name, backup_path)
      command = "mongodump --dumpDbUsersAndRoles #{@connection_options} --db '#{db_name}' --out '#{backup_path}'"
      command << ' > /dev/null'

      system(command)
      raise "Error mongodump '#{db_name}'" unless $?.exitstatus.zero?
    end

    public
    def restore(db_name, backup_path)
      command = "mongorestore --restoreDbUsersAndRoles #{@connection_options} --db '#{db_name}' '#{backup_path}'"
      command << ' > /dev/null'

      system(command)
      raise "Error mongodump '#{db_name}'" unless $?.exitstatus.zero?
    end


  end
end