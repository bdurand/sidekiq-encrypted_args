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

class HashOptionSecretWorker
  include Sidekiq::Worker

  sidekiq_options encrypted_args: { 1 => true }

  def perform(arg_1, arg_2, arg_3)
  end

end

class ArrayOptionSecretWorker
  include Sidekiq::Worker

  sidekiq_options "encrypted_args" => [false, true]

  def perform(arg_1, arg_2, arg_3)
  end

end
