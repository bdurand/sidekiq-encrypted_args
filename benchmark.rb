# frozen_string_literal: true

require "bundler/setup"

require "benchmark"
require "sidekiq"
require_relative "lib/sidekiq/encrypted_args"

class WorkerWithoutEncryption
  include Sidekiq::Job

  def perform(arg_1, arg_2, arg_3)
  end
end

class WorkerWithEncryption
  include Sidekiq::Job

  sidekiq_options encrypted_args: [true, true, true]

  def perform(arg_1, arg_2, arg_3)
  end
end

middleware = ->(worker_class) {
  job = {"args" => ["foo", "bar", "baz"]}
  Sidekiq::EncryptedArgs::ClientMiddleware.new.call(worker_class, job, "default") do
    worker = worker_class.new
    Sidekiq::EncryptedArgs::ServerMiddleware.new.call(worker, job, "default") do
      worker.perform(*job["args"])
    end
  end
}

Benchmark.bm do |benchmark|
  benchmark.report("No Encryption:  ") { 10000.times { middleware.call(WorkerWithoutEncryption) } }
  benchmark.report("With Encryption:") { 10000.times { middleware.call(WorkerWithEncryption) } }
end
