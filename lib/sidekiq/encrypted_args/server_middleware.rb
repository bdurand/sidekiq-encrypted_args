# frozen_string_literal: true

module Sidekiq
  module EncryptedArgs
    # Sidekiq server middleware for decrypting arguments on jobs that have encrypted args.
    #
    # This middleware is responsible for decrypting job arguments before they
    # are passed to the worker's perform method. It runs on the server side
    # when jobs are processed.
    #
    # @see ClientMiddleware
    class ServerMiddleware
      include Sidekiq::ServerMiddleware if defined?(Sidekiq::ServerMiddleware)

      # Wrap the server process to decrypt incoming arguments.
      #
      # @param [Object] worker The worker instance that will process the job
      # @param [Hash] job The Sidekiq job hash containing arguments and metadata
      # @param [String] queue The name of the queue
      # @return [void]
      # @yield Passes control to the worker's perform method
      def call(worker, job, queue)
        encrypted_args = job["encrypted_args"]

        if encrypted_args
          encrypted_args = EncryptedArgs.encrypted_args_option(worker.class, job)
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
