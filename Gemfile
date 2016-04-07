source 'https://rubygems.org'

gemspec

gem 'inflecto'

group :test do
  gem 'anima', '~> 0.2.0'
  gem 'rom-sql', '~> 0.7.0'
  gem 'rspec'
  gem 'byebug', platforms: :mri
  gem 'pg', platforms: [:mri, :rbx]
  gem 'pg_jruby', platforms: :jruby
  gem "codeclimate-test-reporter", require: nil
end

group :benchmarks do
  gem 'benchmark-ips'
end

group :tools do
  gem 'pry'
end
