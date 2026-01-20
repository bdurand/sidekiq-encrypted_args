# frozen_string_literal: true

module Sidekiq
  module EncryptedArgs
    # The current version of the sidekiq-encrypted_args gem.
    VERSION = File.read(File.join(__dir__, "..", "..", "..", "VERSION")).chomp.freeze
  end
end
