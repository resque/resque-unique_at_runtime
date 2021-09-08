# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

group :test do
  unless ENV['TRAVIS']
    gem 'byebug', '~> 11', platform: :mri, require: false
    gem 'pry', '~> 0', platform: :mri, require: false
    gem 'pry-byebug', '~> 3', platform: :mri, require: false
  end
  gem 'rubocop', '~> 1.18.2'
  gem 'rubocop-rspec', '~> 1.44.1'
  gem 'simplecov', '~> 0', require: false
end

# Specify your gem's dependencies in unique_at_runtime.gemspec
gemspec
