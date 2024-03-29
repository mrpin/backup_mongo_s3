Gem::Specification.new do |spec|
  spec.name          = 'backup_mongo_s3'
  spec.version       = '0.0.5'
  spec.authors       = ['Yakupov Dima']
  spec.email         = ['yakupov.dima@mail.ru']
  spec.summary       = "Some summary"
  spec.description   = "Command-line application for MongoDB backup(mongodump/mongorestore) to Amazon S3"
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency 'bundler', '~> 1.6'

  spec.add_runtime_dependency 'aws-sdk', '~> 1.57'
end
