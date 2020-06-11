# frozen_string_literal: true

module Sidekiq
  module EncryptedArgs
    class ServerMiddleware
      # Sidekiq server middleware for encrypting arguments on jobs for workers
      # with `encrypted_args` set in the `sidekiq_options`.
      def call(worker, job, queue)
        encrypted_args = EncryptedArgs.send(:encrypted_args_option, worker.class.sidekiq_options, worker.class, job["args"])
        if encrypted_args
          job_args = job["args"]
          encrypted_args.each do |position|
            value = job_args[position]
            job_args[position] = EncryptedArgs.decrypt(value)
          end
        end

        yield
      end
    end
  end
end
