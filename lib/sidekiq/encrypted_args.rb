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
      def configure!(secret: nil)
        self.secret = secret unless secret.nil?

        Sidekiq.configure_client do |config|
          config.client_middleware do |chain|
            chain.add Sidekiq::EncryptedArgs::ClientMiddleware
          end
        end

        Sidekiq.configure_server do |config|
          config.server_middleware do |chain|
            chain.add Sidekiq::EncryptedArgs::ServerMiddleware
          end
          config.client_middleware do |chain|
            chain.add Sidekiq::EncryptedArgs::ClientMiddleware
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
      # @param [String] encrypted_data Data that was previously encrypted. If the value passed in is
      # an unencrypted string, then the string itself will be returned.
      #
      # @return [String]
      def decrypt(encrypted_data)
        return encrypted_data unless SecretKeys::Encryptor.encrypted?(encrypted_data)
        json = decrypt_string(encrypted_data)
        JSON.parse(json)
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

      def deprecation_warning(message)
        warn("Sidekiq::EncryptedArgs: setting encrypted_args to #{message} is deprecated; support will be removed in version 1.2.")
      end

      # Helper method to get the encrypted args option from an options hash. The value of this option
      # can be `true` or an array indicating if each positional argument should be encrypted, or a hash
      # with keys for the argument position and true as the value.
      def encrypted_args_option(worker_class, job)
        option = job["encrypted_args"]
        return nil if option.nil?
        return [] if option == false

        indexes = []
        if option == true
          job["args"].size.times { |i| indexes << i }
        elsif option.is_a?(Hash)
          deprecation_warning("hash")
          indexes = replace_argument_positions(worker_class, option)
        else
          array_type = nil
          deprecation_message = nil
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
              deprecation_message = "boolean array"
              indexes << position if val
            end
            if array_type && current_type
              deprecation_message = "array of mixed types"
            else
              array_type ||= current_type
            end
          end
          deprecation_warning(deprecation_message) if deprecation_message
        end
        indexes
      end

      # @param [String] class_name name of a class
      # @return [Class] class that was referenced by name
      def constantize(class_name)
        names = class_name.split("::")
        # Clear leading :: for root namespace since we're already calling from object
        names.shift if names.empty? || names.first.empty?
        # Map reduce to the constant. Use inherit=false to not accidentally search
        # parent modules
        names.inject(Object) { |constant, name| constant.const_get(name, false) }
      end

      def replace_argument_positions(worker_class, encrypt_option_hash)
        encrypted_indexes = []
        encrypt_option_hash.each do |key, value|
          next unless value
          if key.is_a?(Symbol) || key.is_a?(String)
            position = perform_method_parameter_index(worker_class, key)
            encrypted_indexes << position if position
          elsif key.is_a?(Integer)
            encrypted_indexes << key
          end
        end
        encrypted_indexes
      end

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
