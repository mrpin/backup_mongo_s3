module BackupMongoS3
  class Storage

    def initialize(options)
      @s3     = AWS::S3.new({access_key_id: options[:access_key_id], secret_access_key: options[:secret_access_key]})
      @bucket = get_bucket(options[:bucket])
    end

    private
    def get_bucket(bucket_name)
      bucket = @s3.buckets[bucket_name]

      unless bucket.exists?
        raise "Bucket #{bucket_name} doesn't not exists. Please create it"
      end

      bucket
    end

    public
    def upload(storage_path, file_name)
      key = File.join(storage_path, Time.now.utc.strftime('%Y%m%d') + '.backup')

      checksum = get_signature(file_name)

      begin

        file = File.open(file_name, 'rb')

        obj = @bucket.objects[key]

        obj.write(:content_length => file.size, metadata: {checksum: checksum}) do |buffer, bytes|
          buffer.write(file.read(bytes))
        end

        file.close

      rescue Exception => err
        raise "Error upload file <#{file_name}> to s3 <#{key}>: #{err.message}"
      end

    end

    public
    def download(storage_path, storage_file_name, file_name)
      key = File.join(storage_path, storage_file_name + '.backup')

      begin

        file = File.open(file_name, 'wb')

        obj = @bucket.objects[key]

        response = obj.read do |chunk|
          file.write(chunk)
        end

        file.close

        checksum = get_signature(file_name)

        if checksum != response[:meta]['checksum']
          raise 'Backup signature is not valid'
        end

      rescue Exception => err
        raise "Error download file <#{key}> from s3 to <#{file_name}>: #{err.message}"
      end

    end

    public
    def get_backups_list(prefix = '', limit = 100)
      result =[]

      @bucket.objects.with_prefix(prefix).each(:limit => limit) do |object|
        if File.extname(object.key) == '.backup'
          result << object
        end
      end

      result
    end

    public
    def delete_old_backups(prefix, history_days)

      old_backups = []

      backups_time_limit = Time.now.utc.midnight - history_days.days

      backups = get_backups_list(prefix)

      backups.each do |backup|
        if backup.last_modified.utc < backups_time_limit
          old_backups << backup
        end
      end

      @bucket.delete(old_backups) unless old_backups.empty?

    end

    private
    def get_signature(file_name)
      Digest::MD5.hexdigest(File.size(file_name).to_s)
    end

  end
end