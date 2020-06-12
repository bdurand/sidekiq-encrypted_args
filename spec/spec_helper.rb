require "bundler/setup"

require "sidekiq"
require "climate_control"

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

# Reset all middleware for nested context and then restore.
#
# @note Middleware args are not preserved
def with_empty_middleware
  # Save the middleware context
  server_middleware = Sidekiq.server_middleware.entries.map(&:klass)
  client_middleware = Sidekiq.client_middleware.entries.map(&:klass)
  Sidekiq.server_middleware.clear
  Sidekiq.client_middleware.clear

  yield

  # Clear anything added and restore all previously registered middleware
  Sidekiq.server_middleware.clear
  Sidekiq.client_middleware.clear
  server_middleware.each { |m| Sidekiq.server_middleware.add(m) }
  client_middleware.each { |m| Sidekiq.client_middleware.add(m) }
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
