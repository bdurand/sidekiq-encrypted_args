# frozen_string_literal: true

require_relative "../spec_helper"

describe Sidekiq::EncryptedArgs::ClientMiddleware do
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
    expect(job["args"]).to eq args
  end

  it "should not encrypt arguments if the encrypted_args option is false" do
    called = false
    middleware.call(NotSecretWorker, job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["args"]).to eq args
  end

  it "should encrypt all arguments if the encrypted_args option is true" do
    called = false
    middleware.call(SecretWorker, job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["args"].collect { |val| SecretKeys::Encryptor.encrypted?(val) }).to eq [true, true, true]
  end

  it "should only encrypt arguments whose position index is set to true when the encrypted_args option is a hash" do
    called = false
    middleware.call(HashOptionSecretWorker, job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["args"].collect { |val| SecretKeys::Encryptor.encrypted?(val) }).to eq [false, true, false]
  end

  it "should only encrypt arguments whose position index is set to true when the encrypted_args option is an array" do
    called = false
    middleware.call(ArrayOptionSecretWorker, job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["args"].collect { |val| SecretKeys::Encryptor.encrypted?(val) }).to eq [false, true, false]
  end
end
