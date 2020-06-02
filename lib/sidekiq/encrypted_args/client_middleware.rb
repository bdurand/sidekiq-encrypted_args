# frozen_string_literal: true

module Sidekiq
  module EncryptedArgs
    # Sidekiq client middleware for encrypting arguments on jobs for workers
    # with `encrypted_args` set in the `sidekiq_options`.
    class ClientMiddleware
      def call(worker_class, job, queue, redis_pool = nil)
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
    end
  end
end
