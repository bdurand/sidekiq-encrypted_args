# frozen_string_literal: true

module Sidekiq
  module EncryptedArgs
    # Sidekiq client middleware for encrypting arguments on jobs for workers
    # with `encrypted_args` set in the `sidekiq_options`.
    class ClientMiddleware
      # @param [String, Class] worker_class class name or class of worker
      def call(worker_class, job, queue, redis_pool = nil)
        if job.include?("encrypted_args")
          encrypted_args = EncryptedArgs.send(:encrypted_args_option, worker_class, job)
          encrypt_job_arguments!(job, encrypted_args)
        end

        yield
      end

      private

      def encrypt_job_arguments!(job, encrypted_args)
        if encrypted_args
          job_args = job["args"]
          job_args.size.times do |position|
            if encrypted_args.include?(position)
              value = job_args[position]
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
