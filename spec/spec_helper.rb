require "bundler/setup"

require "sidekiq"

require_relative "../lib/sidekiq-encrypted_args"

RSpec.configure do |config|
  config.warnings = true
  config.order = :random

  config.around(:each) do |example|
    if example.metadata[:no_warn]
      save_stderr = $stderr
      begin
        $stderr = StringIO.new
        example.run
      ensure
        $stderr = save_stderr
      end
    else
      example.run
    end
  end
end

# Helper method to temporarily set environment variables.
def with_environment(env)
  save_vals = env.keys.collect { |k| [k, ENV[k.to_s]] }
  begin
    env.each { |k, v| ENV[k.to_s] = v }
    yield
  ensure
    save_vals.each { |k, v| ENV[k.to_s] = v }
  end
end

# Reset all middleware for nested context and then restore.
#
# @note Middleware args are not preserved
def with_empty_middleware
  # Save the middleware context
  server_middleware = sidekiq_config.server_middleware.entries.map(&:klass)
  client_middleware = sidekiq_config.client_middleware.entries.map(&:klass)
  sidekiq_config.server_middleware.clear
  sidekiq_config.client_middleware.clear

  yield

  # Clear anything added and restore all previously registered middleware
  sidekiq_config.server_middleware.clear
  sidekiq_config.client_middleware.clear
  server_middleware.each { |m| sidekiq_config.server_middleware.add(m) }
  client_middleware.each { |m| sidekiq_config.client_middleware.add(m) }
end

def sidekiq_config
  if Sidekiq.respond_to?(:default_configuration)
    Sidekiq.default_configuration
  else
    Sidekiq
  end
end

def as_sidekiq_server!
  allow(Sidekiq).to receive(:server?).and_return true
end

def as_sidekiq_client!
  allow(Sidekiq).to receive(:server?).and_return false
end

class EmptyMiddleware
  def call(*args)
    yield
  end
end

class RegularWorker
  include Sidekiq::Worker

  def perform(arg_1, arg_2, arg_3)
  end
end

class NotSecretWorker
  include Sidekiq::Worker

  sidekiq_options encrypted_args: false

  def perform(arg_1, arg_2, arg_3)
  end
end

class SecretWorker
  include Sidekiq::Worker

  sidekiq_options encrypted_args: true

  def perform(arg_1, arg_2, arg_3)
  end
end

module Super
  class SecretWorker
    include Sidekiq::Worker

    sidekiq_options encrypted_args: "arg_3"

    def perform(arg_1, arg_2, arg_3)
    end
  end
end

class ArrayIndexSecretWorker
  include Sidekiq::Worker

  sidekiq_options encrypted_args: [1]

  def perform(arg_1, arg_2, arg_3)
  end
end

class HashOptionSecretWorker
  include Sidekiq::Worker

  sidekiq_options encrypted_args: {1 => true}

  def perform(arg_1, arg_2, arg_3)
  end
end

class ArrayOptionSecretWorker
  include Sidekiq::Worker

  sidekiq_options encrypted_args: [false, true]

  def perform(arg_1, arg_2, arg_3)
  end
end

class NamedArrayOptionSecretWorker
  include Sidekiq::Worker

  sidekiq_options "encrypted_args" => ["arg_2"]

  def perform(arg_1, arg_2, arg_3)
  end
end

class NamedHashOptionSecretWorker
  include Sidekiq::Worker

  sidekiq_options encrypted_args: {arg_2: true, arg_1: false}

  def perform(arg_1, arg_2, arg_3)
  end
end

class ComplexRubyType
  def initialize(attributes)
    @attributes = attributes
  end

  def to_json
    @attributes.to_json
  end
end
