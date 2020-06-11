# frozen_string_literal: true

module Sidekiq
  module EncryptedArgs
    # Sidekiq client middleware for encrypting arguments on jobs for workers
    # with `encrypted_args` set in the `sidekiq_options`.
    class ClientMiddleware
      # @param [String, Class] worker_class class name or class of worker
      def call(worker_class, job, queue, redis_pool = nil)
        if worker_class.is_a?(String)
          begin
            worker_class = constantize(worker_class)
          rescue NameError
            worker_class = nil
          end
        end

        sidekiq_options = (worker_class ? worker_class.sidekiq_options : job)
        encrypted_args = EncryptedArgs.send(:encrypted_args_option, sidekiq_options, worker_class, job["args"])
        encrypt_job_arguments!(job, encrypted_args)

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
