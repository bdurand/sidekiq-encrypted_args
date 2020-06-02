# frozen_string_literal: true

module Sidekiq
  module EncryptedArgs
    # Sidekiq client middleware for encrypting arguments on jobs for workers
    # with `encrypted_args` set in the `sidekiq_options`.
    class ClientMiddleware
      # @param [String, Class] worker_class class name or class of worker
      def call(worker_class, job, queue, redis_pool = nil)
        worker_class = constantize(worker_class) if worker_class.is_a?(String)
        encrypted_args = EncryptedArgs.send(:encrypted_args_option, worker_class)
        if encrypted_args
          new_args = []
          job["args"].each_with_index do |value, position|
            value = EncryptedArgs.encrypt(value) if encrypted_args[position]
            new_args << value
          end
          job["args"] = new_args
        end

        yield
      end

      private

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
    end
  end
end
