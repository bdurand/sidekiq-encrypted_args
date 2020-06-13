# frozen_string_literal: true

module Sidekiq
  module EncryptedArgs
    # Sidekiq server middleware for decrypting arguments on jobs that have encrypted args.
    class ServerMiddleware
      # Wrap the server process to decrypt incoming arguments
      def call(worker, job, queue)
        encrypted_args = job["encrypted_args"]
        if encrypted_args
          encrypted_args = backward_compatible_encrypted_args(encrypted_args, worker.class, job)
          job_args = job["args"]
          encrypted_args.each do |position|
            value = job_args[position]
            job_args[position] = EncryptedArgs.decrypt(value)
          end
        end

        yield
      end

      private

      # Ensure that the encrypted args is an array of integers. If not re-read it from the class
      # definition since gem version 1.0.2 and earlier did not update the encrypted_args on the job.
      def backward_compatible_encrypted_args(encrypted_args, worker_class, job)
        unless encrypted_args.is_a?(Array) && encrypted_args.all? { |position| position.is_a?(Integer) }
          encrypted_args = EncryptedArgs.encrypted_args_option(worker_class, job)
        end
        encrypted_args
      end
    end
  end
end
