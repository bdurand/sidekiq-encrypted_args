Gem::Specification.new do |spec|
  spec.name = "sidekiq-encrypted_args"
  spec.version = File.read(File.join(__dir__, "VERSION")).strip
  spec.authors = ["Brian Durand"]
  spec.email = ["bbdurand@gmail.com"]

  spec.summary = "Support for encrypting arguments that contain sensitive information in sidekiq jobs."
  spec.homepage = "https://github.com/bdurand/sidekiq-encrypted_args"
  spec.license = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  ignore_files = %w[
    .
    Appraisals
    Gemfile
    Gemfile.lock
    Rakefile
    gemfiles/
    spec/
  ]
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject { |f| ignore_files.any? { |path| f.start_with?(path) } }
  end

  spec.require_paths = ["lib"]
  spec.bindir = "bin"
  spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }

  spec.required_ruby_version = ">= 2.4"

  spec.add_dependency "sidekiq", ">= 4.0"
  spec.add_dependency "secret_keys"

  spec.add_development_dependency "bundler", "~>2.0"
end
