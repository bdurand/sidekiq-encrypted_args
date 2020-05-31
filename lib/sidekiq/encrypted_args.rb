# frozen_string_literal: true

require "json"
require "secret_keys"
require "sidekiq"

module Sidekiq
  module EncryptedArgs
    # Error thrown when the
    class InvalidSecretError < StandardError
    end

    class << self
      # Set the secret key used for encrypting arguments. If this is not set,
      # the value will be loaded from the `SIDEKIQ_ENCRYPTED_ARGS_SECRET` environment
      # variable. If that value is not set, arguments will not be encypted.
      #
      # @param [String] value One or more secrets to use for encypting arguments.
      #
      # @note You can set multiple secrets by passing an array if you need to roll your secrets.
      # The left most value in the array will be used as the encryption secret, but
      # all the values will be tried when decrypting. That way if you have scheduled
      # jobs that were encypted with a different secret, you can still make it available
      # when decrypting the arguments when the job gets run. If you are using the
      # envrionment variable, separate the keys with spaces.
      def secret=(value)
        @encryptors = make_encryptors(value)
      end

      # Calling this method will add the client and server middleware to the Sidekiq
      # middleware chains. If you need to ensure the order of where the middleware is
      # added, you can forgo this method and add it yourself.
      def configure!
        Sidekiq.configure_client do |config|
          config.client_middleware do |chain|
            chain.add Sidekiq::EncryptedArgs::ClientMiddleware
          end
        end

        Sidekiq.configure_server do |config|
          config.server_middleware do |chain|
            chain.add Sidekiq::EncryptedArgs::ServerMiddleware
          end
        end
      end

      # Encrypt a value.
      #
      # @param [Object] data Data to encrypt. You can pass any JSON compatible data types or structures.
      #
      # @return [String]
      def encrypt(data)
        return nil if data.nil?
        json = JSON.dump(data)
        encrypted = encrypt_string(json)
        if encrypted == json
          data
        else
          encrypted
        end
      end

      # Decrypt data
      #
      # @param [String] encrypted_data Data that was previously encrypted. If the value passed in is
      # an unencrypted string, then the string itself will be returned.
      #
      # @return [String]
      def decrypt(encrypted_data)
        return encrypted_data unless SecretKeys::Encryptor.encrypted?(encrypted_data)
        json = decrypt_string(encrypted_data)
        JSON.parse(json)
      end

      protected

      # Helper method to get the encrypted args option from an options hash. The value of this option
      # can be `true` or an array indicating if each positional argument should be encrypted, or a hash
      # with keys for the argument position and true as the value.
      def encrypted_args_option(sidekiq_options)
        option = sidekiq_options.fetch(:encrypted_args, sidekiq_options["encrypted_args"])
        return nil if option.nil?
        return Hash.new(true) if option == true
        return option if option.is_a?(Hash)
        if option.is_a?(Array)
          hash = {}
          option.each_with_index { |val, position| hash[position] = val }
          return hash
        end
        nil
      end

      private

      # Hard coded password salt used sent to the encryptor. Do no change.
      SALT = "3270e054"
      private_constant :SALT

      def encrypt_string(value)
        encryptor = encryptors.first
        return value if encryptor.nil?
        encryptor.encrypt(value)
      end

      def decrypt_string(value)
        return value if encryptors == [nil]
        encryptors.each do |encryptor|
          begin
            return encryptor.decrypt(value) if encryptor
          rescue OpenSSL::Cipher::CipherError
            # Not the right key, try the next one
          end
        end
        raise InvalidSecretError
      end

      def encryptors
        if !defined?(@encryptors) || @encryptors.empty?
          @encryptors = make_encryptors(ENV["SIDEKIQ_ENCRYPTED_ARGS_SECRET"].to_s.split)
        end
        @encryptors
      end

      def make_encryptors(secrets)
        Array(secrets).map { |val| val.nil? ? nil : SecretKeys::Encryptor.from_password(val, SALT) }
      end
    end
  end
end

require_relative "encrypted_args/client_middleware"
require_relative "encrypted_args/server_middleware"
