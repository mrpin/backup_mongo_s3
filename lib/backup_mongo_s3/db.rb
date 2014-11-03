module BackupMongoS3
  class Db

    def initialize(options)
      @options            = options
      @connection_options = connection(options)
    end

    private
    def connection(options)
      host                    = (options[:host].nil? || options[:host] == '') ? 'localhost' : options[:host]
      port                    = options[:port].nil? ? 27017 : options[:port]
      username                = options[:username]
      password                = options[:password]
      authentication_database = options[:authentication_database]

      auth_options = ''

      unless username.nil? || username == '' || password.nil? || password == ''
        auth_options = "-u '#{username}' -p '#{password}'"
        auth_options << " --authenticationDatabase '#{authentication_database}'" unless authentication_database.nil? || authentication_database == ''
      end

      "--host '#{host}' --port '#{port}' #{auth_options}"
    end

    public
    def dump(db_name, backup_path)
      command = 'mongodump'
      command << " #{@connection_options}"
      command << ' --dumpDbUsersAndRoles' if @options[:dump_db_users_and_roles] == true || @options[:dump_db_users_and_roles] == 1
      command << " --db '#{db_name}' --out '#{backup_path}'"
      command << ' > /dev/null'

      system(command)
      raise "Error mongodump '#{db_name}'" unless $?.exitstatus.zero?
    end

    public
    def restore(db_name, backup_path)
      command = 'mongorestore'
      command << " #{@connection_options}"
      command << ' --restoreDbUsersAndRoles' if @options[:restore_db_users_and_roles] == true || @options[:restore_db_users_and_roles] == 1
      command << ' --drop' if @options[:drop_collection] == true || @options[:drop_collection] == 1
      command << " --db '#{db_name}' '#{backup_path}'"
      command << ' > /dev/null'

      system(command)
      raise "Error mongorestore '#{db_name}'" unless $?.exitstatus.zero?
    end


  end
end