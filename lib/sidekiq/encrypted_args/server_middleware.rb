# frozen_string_literal: true

module Sidekiq
  module EncryptedArgs
    class ServerMiddleware

      # Sidekiq server middleware for encrypting arguments on jobs for workers
      # with `encrypted_args` set in the `sidekiq_options`.
      def call(worker, job, queue)
        encrypted_args = EncryptedArgs.send(:encrypted_args_option, worker.class.sidekiq_options)
        if encrypted_args
          new_args = []
          job["args"].each_with_index do |value, position|
            value = EncryptedArgs.decrypt(value) if encrypted_args[position]
            new_args << value
          end
          job["args"] = new_args
        end

        yield
      end

    end
  end
end
