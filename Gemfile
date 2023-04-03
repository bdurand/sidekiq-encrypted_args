source "https://rubygems.org"

group :runtime do
  gemspec
end

group :development, :test do
  gem "rake"
  gem "rspec", "~> 3.9"
  gem "appraisal"

  # Lock standard to a particular version, esp. cause it's still 0.x.x according to Semver
  gem "standard", "~> 1.0"
end

group :doc do
  gem "yard"
end
