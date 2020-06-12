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

  it "should not decrypt arguments if the encrypted_args option is missing" do
    called = false
    middleware.call(RegularWorker.new, job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["args"]).to eq args
  end

  it "should not decrypt arguments if the encrypted_args option is empty" do
    called = false
    job["encrypted_args"] = []
    middleware.call(RegularWorker.new, job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["args"]).to eq args
  end

  it "should decrypt arguments at the positions specified in the encrypted_args option" do
    called = false
    job["args"] = args.collect { |arg| Sidekiq::EncryptedArgs.encrypt(arg) }
    job["encrypted_args"] = [1, 2]
    middleware.call(RegularWorker.new, job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["args"][0]).to_not eq args[0]
    expect(Sidekiq::EncryptedArgs.decrypt(job["args"][0])).to eq args[0]
    expect(job["args"][1]).to eq args[1]
    expect(job["args"][2]).to eq args[2]
  end

  it "should try multiple keys to decrypt arguments to support rolling keys" do
    called = false
    Sidekiq::EncryptedArgs.secret = "old"
    job["args"] = args.collect { |arg| Sidekiq::EncryptedArgs.encrypt(arg) }
    job["encrypted_args"] = [0, 1, 2]
    Sidekiq::EncryptedArgs.secret = ["new", "old"]
    middleware.call(SecretWorker.new, job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["args"]).to eq args
  end

  it "should pass through keys that should be encrypted but were not encrypted" do
    called = false
    job["encrypted_args"] = [1]
    middleware.call(SecretWorker.new, job, queue) do
      called = true
    end
    expect(called).to eq true
    expect(job["args"]).to eq args
  end

  context "when encrypted_args is set but not normalized to an array of argument positions", :no_warn do
    it "should not decrypt arguments if the encrypted_args option is false" do
      called = false
      job["encrypted_args"] = NotSecretWorker.sidekiq_options["encrypted_args"]
      middleware.call(NotSecretWorker.new, job, queue) do
        called = true
      end
      expect(called).to eq true
      expect(job["args"]).to eq args
    end

    it "should decrypt all arguments if the encrypted_args option is true" do
      called = false
      job["args"] = args.collect { |arg| Sidekiq::EncryptedArgs.encrypt(arg) }
      job["encrypted_args"] = SecretWorker.sidekiq_options["encrypted_args"]
      middleware.call(SecretWorker.new, job, queue) do
        called = true
      end
      expect(called).to eq true
      expect(job["args"]).to eq args
    end

    it "should only decrypt arguments whose position index is set to true when the encrypted_args option is a hash" do
      called = false
      job["args"] = [args[0], Sidekiq::EncryptedArgs.encrypt(args[1]), args[2]]
      job["encrypted_args"] = HashOptionSecretWorker.sidekiq_options["encrypted_args"]
      middleware.call(HashOptionSecretWorker.new, job, queue) do
        called = true
      end
      expect(called).to eq true
      expect(job["args"]).to eq args
    end

    it "should only decrypt arguments whose position index is set to true when the encrypted_args option is an array" do
      called = false
      job["args"] = [args[0], Sidekiq::EncryptedArgs.encrypt(args[1]), args[2]]
      job["encrypted_args"] = ArrayOptionSecretWorker.sidekiq_options["encrypted_args"]
      middleware.call(ArrayOptionSecretWorker.new, job, queue) do
        called = true
      end
      expect(called).to eq true
      expect(job["args"]).to eq args
    end

    it "should only decrypt arguments whose names are provided in the encrypted_args option array" do
      called = false
      job["args"] = [args[0], Sidekiq::EncryptedArgs.encrypt(args[1]), args[2]]
      job["encrypted_args"] = NamedArrayOptionSecretWorker.sidekiq_options["encrypted_args"]
      middleware.call(NamedArrayOptionSecretWorker.new, job, queue) do
        called = true
      end
      expect(called).to eq true
      expect(job["args"]).to eq args
    end

    it "should only decrypt arguments whose names are set to true in the encrypted_args option hash" do
      called = false
      job["args"] = [args[0], Sidekiq::EncryptedArgs.encrypt(args[1]), args[2]]
      job["encrypted_args"] = NamedHashOptionSecretWorker.sidekiq_options["encrypted_args"]
      middleware.call(NamedHashOptionSecretWorker.new, job, queue) do
        called = true
      end
      expect(called).to eq true
      expect(job["args"]).to eq args
    end
  end
end
