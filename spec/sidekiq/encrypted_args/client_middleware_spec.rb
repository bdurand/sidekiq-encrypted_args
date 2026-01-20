# frozen_string_literal: true

require "spec_helper"

RSpec.describe Sidekiq::EncryptedArgs::ClientMiddleware do
  let(:args) { ["foo", "bar", "baz"] }
  let(:job) { {"args" => args} }
  let(:queue) { "default" }
  let(:middleware) { Sidekiq::EncryptedArgs::ClientMiddleware.new }

  before(:each) do
    Sidekiq::EncryptedArgs.secret = "key"
  end

  it "should not encrypt arguments on a regular worker" do
    called = false
    middleware.call(RegularWorker, job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job).to_not include("encrypted_args")
    expect(job["args"]).to eq args
  end

  it "should not encrypt arguments if the encrypted_args option is false" do
    called = false
    job["encrypted_args"] = NotSecretWorker.sidekiq_options["encrypted_args"]
    middleware.call(NotSecretWorker, job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["encrypted_args"]).to match_array []
    expect(job["args"]).to eq args
  end

  it "should encrypt all arguments if the encrypted_args option is true" do
    called = false
    job["encrypted_args"] = SecretWorker.sidekiq_options["encrypted_args"]
    middleware.call(SecretWorker, job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["encrypted_args"]).to match_array [0, 1, 2]
    expect(job["args"].collect { |val| SecretKeys::Encryptor.encrypted?(val) }).to eq [true, true, true]
  end

  it "should support being called with a string class name" do
    called = false
    job["encrypted_args"] = SecretWorker.sidekiq_options["encrypted_args"]
    middleware.call("SecretWorker", job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["encrypted_args"]).to match_array [0, 1, 2]
    expect(job["args"].collect { |val| SecretKeys::Encryptor.encrypted?(val) }).to eq [true, true, true]
  end

  it "should support scoped class names" do
    called = false
    job["encrypted_args"] = Super::SecretWorker.sidekiq_options["encrypted_args"]
    middleware.call("Super::SecretWorker", job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["encrypted_args"]).to match_array [2]
    expect(job["args"].collect { |val| SecretKeys::Encryptor.encrypted?(val) }).to eq [false, false, true]
  end

  it "should support absolute class names" do
    called = false
    job["encrypted_args"] = Super::SecretWorker.sidekiq_options["encrypted_args"]
    middleware.call("::Super::SecretWorker", job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["encrypted_args"]).to match_array [2]
    expect(job["args"].collect { |val| SecretKeys::Encryptor.encrypted?(val) }).to eq [false, false, true]
  end

  it "should just pass through worker classes that it can't instantiate" do
    called = false
    middleware.call("UndefinedWorker", job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["encrypted_args"]).to eq nil
    expect(job["args"].collect { |val| SecretKeys::Encryptor.encrypted?(val) }).to eq [false, false, false]
  end

  it "should honor job encrypted args on worker classes that it can't instantiate" do
    called = false
    job["encrypted_args"] = [1]
    middleware.call("UndefinedWorker", job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["encrypted_args"]).to eq [1]
    expect(job["args"].collect { |val| SecretKeys::Encryptor.encrypted?(val) }).to eq [false, true, false]
  end

  it "should only encrypt arguments whose position index is set to true when the encrypted_args option is an array" do
    called = false
    job["encrypted_args"] = ArrayIndexSecretWorker.sidekiq_options["encrypted_args"]
    middleware.call(ArrayIndexSecretWorker, job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["encrypted_args"]).to match_array [1]
    expect(job["args"].collect { |val| SecretKeys::Encryptor.encrypted?(val) }).to eq [false, true, false]
  end

  it "should only encrypt arguments whose names are provided in the encrypted_args option array" do
    called = false
    job["encrypted_args"] = NamedArrayOptionSecretWorker.sidekiq_options["encrypted_args"]
    middleware.call(NamedArrayOptionSecretWorker, job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["encrypted_args"]).to match_array [1]
    expect(job["args"].collect { |val| SecretKeys::Encryptor.encrypted?(val) }).to eq [false, true, false]
  end

  it "should not encrypt arguments that are already encrypted" do
    called = false
    job["encrypted_args"] = ArrayIndexSecretWorker.sidekiq_options["encrypted_args"]
    encrypted_value = Sidekiq::EncryptedArgs.encrypt(job["args"][1])
    job["args"][1] = encrypted_value

    middleware.call(ArrayIndexSecretWorker, job, queue) do
      called = true
    end

    expect(called).to eq true
    expect(job["encrypted_args"]).to match_array [1]
    expect(job["args"][1]).to eq encrypted_value
  end
end
