# frozen_string_literal: true

require_relative "spec_helper"

describe Sidekiq::EncryptedArgs do
  it "should encrypt and decrypt data" do
    Sidekiq::EncryptedArgs.secret = "key"
    encrypted = Sidekiq::EncryptedArgs.encrypt("foobar")
    decrypted = Sidekiq::EncryptedArgs.decrypt(encrypted)
    expect(encrypted).to_not eq "foobar"
    expect(decrypted).to eq "foobar"
  end

  it "should encrypt and decrypt data structures" do
    Sidekiq::EncryptedArgs.secret = "key"
    data = {"foo" => [1, 2, 3]}
    encrypted = Sidekiq::EncryptedArgs.encrypt(data)
    decrypted = Sidekiq::EncryptedArgs.decrypt(encrypted)
    expect(encrypted).to be_a String
    expect(decrypted).to eq data
  end

  it "should be able to set mulitiple keys to try for decrypting so a key can be gracefully rolled" do
    Sidekiq::EncryptedArgs.secret = "key_1"
    encrypted_1 = Sidekiq::EncryptedArgs.encrypt("foobar")

    Sidekiq::EncryptedArgs.secret = %w[key_2 key_1 key_3]
    encrypted_2 = Sidekiq::EncryptedArgs.encrypt("foobar")

    expect(encrypted_2).to_not eq encrypted_1
    expect(Sidekiq::EncryptedArgs.decrypt(encrypted_1)).to eq "foobar"
    expect(Sidekiq::EncryptedArgs.decrypt(encrypted_2)).to eq "foobar"
  end

  it "should read the secret key from the environment if it has not been explicitly set" do
    # Remove the secret initialization
    if Sidekiq::EncryptedArgs.instance_variable_defined?(:@encryption_secrets)
      Sidekiq::EncryptedArgs.remove_instance_variable(:@encryption_secrets)
    end

    ClimateControl.modify(SIDEKIQ_ENCRYPTED_ARGS_SECRET: "env_key") do
      env_encrypted = Sidekiq::EncryptedArgs.encrypt("foobar")
      env_decrypted = Sidekiq::EncryptedArgs.decrypt(env_encrypted)
      expect(env_decrypted).to eq "foobar"

      Sidekiq::EncryptedArgs.secret = "key"
      explicit_encrypted = Sidekiq::EncryptedArgs.encrypt("foobar")
      explicit_decrypted = Sidekiq::EncryptedArgs.decrypt(explicit_encrypted)
      expect(explicit_decrypted).to eq "foobar"
      expect { Sidekiq::EncryptedArgs.decrypt(env_encrypted) }.to raise_error(Sidekiq::EncryptedArgs::InvalidSecretError)
    end
  end

  it "should not encrypt if the secret key is not set" do
    # Remove the secret initialization
    if Sidekiq::EncryptedArgs.instance_variable_defined?(:@encryption_secrets)
      Sidekiq::EncryptedArgs.remove_instance_variable(:@encryption_secrets)
    end

    ClimateControl.modify(SIDEKIQ_ENCRYPTED_ARGS_SECRET: "") do
      expect(Sidekiq::EncryptedArgs.encrypt("foobar")).to eq "foobar"
    end
  end

  it "should not encrypt nil" do
    expect(Sidekiq::EncryptedArgs.encrypt(nil)).to eq nil
  end

  it "should not try to decrypt unencrypted strings" do
    expect(Sidekiq::EncryptedArgs.decrypt("foobar")).to eq "foobar"
  end

  it "should not try to decrypt nil" do
    expect(Sidekiq::EncryptedArgs.decrypt(nil)).to eq nil
  end

  it "should not try to decrypt non-strings" do
    expect(Sidekiq::EncryptedArgs.decrypt(1)).to eq 1
  end

  it "should configure the Sidekiq client middleware" do
    allow(Sidekiq).to receive(:server?).and_return false
    Sidekiq::EncryptedArgs.configure!
    expect(Sidekiq.client_middleware.exists?(Sidekiq::EncryptedArgs::ClientMiddleware)).to eq true
  end

  it "should configure the Sidekiq server middleware" do
    allow(Sidekiq).to receive(:server?).and_return true
    Sidekiq::EncryptedArgs.configure!
    expect(Sidekiq.server_middleware.exists?(Sidekiq::EncryptedArgs::ServerMiddleware)).to eq true
  end
end
