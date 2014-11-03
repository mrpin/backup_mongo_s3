require 'optparse'
require 'aws-sdk'
require 'fileutils'
require 'digest/md5'
require 'tmpdir'

require_relative 'backup_mongo_s3/application'
require_relative 'backup_mongo_s3/db'
require_relative 'backup_mongo_s3/storage'
require_relative 'backup_mongo_s3/scheduler'

require_relative 'helpers/fixnum'
require_relative 'helpers/hash'
require_relative 'helpers/time'

module BackupMongoS3

  def self.name
    File.basename( __FILE__, '.rb')
  end

  def self.root_path
    @root_path if @root_path
    spec = Gem::Specification.find_by_name(self.name)
    @root_path = spec.gem_dir
  end
end

