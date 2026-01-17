# frozen_string_literal: true

require "json"
require "secret_keys"
require "sidekiq"

module Sidekiq
  # Provides middleware for encrypting sensitive arguments in Sidekiq jobs.
  #
  # This module allows you to specify which job arguments should be encrypted
  # in Redis to protect sensitive information like API keys, passwords, or
  # personally identifiable information.
  module EncryptedArgs
    @encryptors = nil

    # Error thrown when the secret is invalid
    class InvalidSecretError < StandardError
    end

    class << self
      # Set the secret key used for encrypting arguments. If this is not set,
      # the value will be loaded from the `SIDEKIQ_ENCRYPTED_ARGS_SECRET` environment
      # variable. If that value is not set, arguments will not be encrypted.
      #
      # You can set multiple secrets by passing an array if you need to roll your secrets.
      # The left most value in the array will be used as the encryption secret, but
      # all the values will be tried when decrypting. That way if you have scheduled
      # jobs that were encrypted with a different secret, you can still make it available
      # when decrypting the arguments when the job gets run. If you are using the
      # environment variable, separate the keys with spaces.
      #
      # @example Setting a single secret
      #   Sidekiq::EncryptedArgs.secret = "your_secret_key"
      #
      # @example Rolling secrets (multiple keys for backward compatibility)
      #   Sidekiq::EncryptedArgs.secret = ["new_secret", "old_secret", "older_secret"]
      #
      # @param [String, Array<String>] value One or more secrets to use for encrypting arguments.
      # @return [void]
      def secret=(value)
        @encryptors = make_encryptors(value).freeze
      end

      # Add the client and server middleware to the default Sidekiq
      # middleware chains. If you need to ensure the order of where the middleware is
      # added, you can forgo this method and add it yourself.
      #
      # This method prepends client middleware and appends server middleware.
      #
      # @example Basic configuration
      #   Sidekiq::EncryptedArgs.configure!(secret: "your_secret_key")
      #
      # @example Configuration using environment variable
      #   ENV['SIDEKIQ_ENCRYPTED_ARGS_SECRET'] = "your_secret_key"
      #   Sidekiq::EncryptedArgs.configure!
      #
      # @param [String] secret optionally set the secret here. See {.secret=}
      def configure!(secret: nil)
        self.secret = secret unless secret.nil?
        encryptors # Calling encryptors will validate that a secret is set.

        Sidekiq.configure_client do |config|
          config.client_middleware do |chain|
            chain.prepend Sidekiq::EncryptedArgs::ClientMiddleware
          end
        end

        Sidekiq.configure_server do |config|
          config.server_middleware do |chain|
            chain.add Sidekiq::EncryptedArgs::ServerMiddleware
          end
          config.client_middleware do |chain|
            chain.prepend Sidekiq::EncryptedArgs::ClientMiddleware
          end
        end
      end

      # Encrypt a value.
      #
      # @example Encrypting a simple value
      #   EncryptedArgs.encrypt("secret_value") #=> "encrypted_string"
      #
      # @example Encrypting complex data
      #   EncryptedArgs.encrypt({api_key: "secret", user_id: 123}) #=> "encrypted_string"
      #
      # @param [#to_json, Object] data Data to encrypt. You can pass any JSON compatible data types or structures.
      #
      # @return [String]
      def encrypt(data)
        return nil if data.nil?

        json = (data.respond_to?(:to_json) ? data.to_json : JSON.generate(data))
        encrypted = encrypt_string(json)
        if encrypted == json
          data
        else
          encrypted
        end
      end

      # Decrypt data
      #
      # @example Decrypting an encrypted value
      #   EncryptedArgs.decrypt("encrypted_string") #=> "original_value"
      #
      # @example Handling unencrypted data
      #   EncryptedArgs.decrypt("unencrypted_string") #=> "unencrypted_string"
      #
      # @param [String] encrypted_data Data that was previously encrypted. If the value passed in is
      # an unencrypted string, then the string itself will be returned.
      #
      # @return [Object]
      def decrypt(encrypted_data)
        return encrypted_data unless SecretKeys::Encryptor.encrypted?(encrypted_data)
        json = decrypt_string(encrypted_data)
        JSON.parse(json)
      end

      # Check if a value is encrypted.
      #
      # @return [Boolean]
      def encrypted?(value)
        SecretKeys::Encryptor.encrypted?(value)
      end

      # Private helper method to get the encrypted args option from an options hash. The value of this option
      # can be `true` or an array indicating if each positional argument should be encrypted, or a hash
      # with keys for the argument position and true as the value.
      #
      # @param [String, Class] worker_class The worker class or class name
      # @param [Hash] job The Sidekiq job hash containing arguments and metadata
      # @return [Array<Integer>, nil] Array of argument positions to encrypt, or nil if encryption is not configured
      # @api private
      def encrypted_args_option(worker_class, job)
        option = job["encrypted_args"]
        return nil if option.nil?
        return [] if option == false

        indexes = []
        if option == true
          job["args"].size.times { |i| indexes << i }
        elsif option.is_a?(Hash)
          raise ArgumentError.new("Hash-based argument encryption is no longer supported.")
        else
          array_type = nil
          Array(option).each_with_index do |val, position|
            current_type = nil
            if val.is_a?(Integer)
              indexes << val
              current_type = :integer
            elsif val.is_a?(Symbol) || val.is_a?(String)
              worker_class = constantize(worker_class) if worker_class.is_a?(String)
              position = perform_method_parameter_index(worker_class, val)
              indexes << position if position
              current_type = :symbol
            else
              raise ArgumentError.new("Encrypted args must be specified as integers or symbols.")
            end

            if array_type && current_type != array_type
              raise ArgumentError.new("Encrypted args cannot mix integers and symbols.")
            else
              array_type ||= current_type
            end
          end
        end
        indexes
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
        encryptors.each do |encryptor|
          return encryptor.decrypt(value)
        rescue OpenSSL::Cipher::CipherError
          # Not the right key, try the next one
        end

        # None of the keys worked
        raise InvalidSecretError.new("Cannot decrypt. Invalid secret provided.")
      end

      def encryptors
        if @encryptors.nil?
          secret = ENV.fetch("SIDEKIQ_ENCRYPTED_ARGS_SECRET", "").strip
          if secret.empty?
            raise InvalidSecretError.new("Secret not set. Call Sidekiq::EncryptedArgs.secret= or set the SIDEKIQ_ENCRYPTED_ARGS_SECRET environment variable.")
          end

          @encryptors = make_encryptors(secret.split).freeze
        end
        @encryptors
      end

      # Create encryptors from secrets.
      #
      # @param [String, Array<String>] secrets One or more secrets to create encryptors from
      # @return [Array<SecretKeys::Encryptor>, nil] Array of encryptors or nil if no secrets provided
      def make_encryptors(secrets)
        return nil if secrets.nil?

        Array(secrets).map { |val| SecretKeys::Encryptor.from_password(val, SALT) }
      end

      # Convert a string class name into the actual class constant.
      #
      # @param [String] class_name Name of a class (e.g., "MyModule::MyClass")
      # @return [Class] The class constant that was referenced by name
      def constantize(class_name)
        names = class_name.split("::")
        # Clear leading :: for root namespace since we're already calling from object
        names.shift if names.empty? || names.first.empty?
        # Map reduce to the constant. Use inherit=false to not accidentally search
        # parent modules
        names.inject(Object) { |constant, name| constant.const_get(name, false) }
      end

      # Get the index of a parameter in the worker's perform method.
      #
      # @param [Class] worker_class The worker class to inspect
      # @param [String, Symbol] parameter The parameter name to find
      # @return [Integer, nil] The zero-based index of the parameter, or nil if not found
      def perform_method_parameter_index(worker_class, parameter)
        if worker_class
          parameter = parameter.to_sym
          worker_class.instance_method(:perform).parameters.find_index { |_, name| name == parameter }
        end
      end
    end
  end
end

require_relative "encrypted_args/client_middleware"
require_relative "encrypted_args/server_middleware"
require_relative "encrypted_args/version"
