# frozen_string_literal: true

require_relative "../spec_helper"

describe Sidekiq::EncryptedArgs::ServerMiddleware do
  let(:args) { ["foo", "bar", "baz"] }
  let(:job) { {"args" => args} }
  let(:queue) { "default" }
  let(:middleware) { Sidekiq::EncryptedArgs::ServerMiddleware.new }

  before(:each) do
    Sidekiq::EncryptedArgs.secret = "key"
  end

  it "should not decrypt arguments on a regular worker" do
    called = false
    middleware.call(RegularWorker.new, job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["args"]).to eq args
  end

  it "should not decrypt arguments if the encrypted_args option is false" do
    called = false
    middleware.call(NotSecretWorker.new, job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["args"]).to eq args
  end

  it "should decrypt all arguments if the encrypted_args option is true" do
    called = false
    job["args"] = args.collect { |arg| Sidekiq::EncryptedArgs.encrypt(arg) }
    middleware.call(SecretWorker.new, job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["args"]).to eq args
  end

  it "should only decrypt arguments whose position index is set to true when the encrypted_args option is a hash" do
    called = false
    job["args"] = [args[0], Sidekiq::EncryptedArgs.encrypt(args[1]), args[2]]
    middleware.call(HashOptionSecretWorker.new, job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["args"]).to eq args
  end

  it "should only decrypt arguments whose position index is set to true when the encrypted_args option is an array" do
    called = false
    job["args"] = [args[0], Sidekiq::EncryptedArgs.encrypt(args[1]), args[2]]
    middleware.call(ArrayOptionSecretWorker.new, job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["args"]).to eq args
  end

  it "should try multiple keys to decrypt arguments to support rolling keys" do
    called = false
    Sidekiq::EncryptedArgs.secret = "old"
    job["args"] = args.collect { |arg| Sidekiq::EncryptedArgs.encrypt(arg) }
    Sidekiq::EncryptedArgs.secret = ["new", "old"]
    middleware.call(SecretWorker.new, job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["args"]).to eq args
  end

  it "should pass through keys that should be encrypted but were not encrypted" do
    called = false
    middleware.call(SecretWorker.new, job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["args"]).to eq args
  end
end
