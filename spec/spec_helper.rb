require "bundler/setup"

require "sidekiq"
require "climate_control"

require_relative "../lib/sidekiq-encrypted_args"

RSpec.configure do |config|
  config.warnings = true
  config.order = :random
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

    sidekiq_options encrypted_args: [false, false, true]

    def perform(arg_1, arg_2, arg_3)
    end
  end
end

class ArrayOptionSecretWorker
  include Sidekiq::Worker

  sidekiq_options encrypted_args: [false, true]

  def perform(arg_1, arg_2, arg_3)
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
