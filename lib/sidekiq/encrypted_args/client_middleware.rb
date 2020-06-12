# frozen_string_literal: true

module Sidekiq
  module EncryptedArgs
    # Sidekiq client middleware for encrypting arguments on jobs for workers
    # with `encrypted_args` set in the `sidekiq_options`.
    class ClientMiddleware
      # Encrypt specified arguments before they're sent off to the queue
      def call(worker_class, job, queue, redis_pool = nil)
        if job.include?("encrypted_args")
          encrypted_args = EncryptedArgs.encrypted_args_option(worker_class, job)
          encrypt_job_arguments!(job, encrypted_args)
        end

        yield
      end

      private

      # Encrypt the arguments on job
      #
      # Additionally, set `job["encrypted_args"` to the canonicalized version (i.e. `Array<Integer>`)
      #
      # @param [Hash]
      # @param [Array<Integer>] encrypted_args array of indexes in job to encrypt
      # @return [void]
      def encrypt_job_arguments!(job, encrypted_args)
        if encrypted_args
          job_args = job["args"]
          job_args.each_with_index do |value, position|
            if encrypted_args.include?(position)
              job_args[position] = EncryptedArgs.encrypt(value)
            end
          end
          job["encrypted_args"] = encrypted_args
        else
          job.delete("encrypted_args")
        end
      end
    end
  end
end
