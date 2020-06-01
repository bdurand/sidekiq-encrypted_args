# frozen_string_literal: true

module Sidekiq
  module EncryptedArgs
    VERSION = File.read(File.join(__dir__, "..", "..", "..", "VERSION")).chomp.freeze
  end
end
