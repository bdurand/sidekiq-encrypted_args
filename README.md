# Sidekiq Encrypted Args

![Continuous Integration](https://github.com/bdurand/sidekiq-encrypted_args/workflows/Continuous%20Integration/badge.svg?branch=master)
[![Maintainability](https://api.codeclimate.com/v1/badges/70ab3782e4d5285eb173/maintainability)](https://codeclimate.com/github/bdurand/sidekiq-encrypted_args/maintainability)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)

Support for encrypting arguments for [Sidekiq](https://github.com/mperham/sidekiq).

## The Problem

Sidekiq stores the arguments for jobs as JSON in Redis. If your workers include sensitive information (API keys, passwords, personally identifiable information, etc.), you run the risk of accidentally exposing this information. Job arguments are visible in the Sidekiq web interface and your security will only be as good as your Redis server security.

This can be an even bigger issue if you use scheduled jobs since sensitive data on those jobs will live in Redis until the job is run. Data written to Redis can also be persisted to disk and live on long after the data in Redis has been deleted.

## The Solution

This gem adds Sidekiq middleware that allows you to specify job arguments for your workers that should be encrypted in Redis. You do this by adding `encrypted_args` to the `sidekiq_options` in the worker. Jobs for these workers will have their arguments encrypted before being stored in Redis and decrypted before the `perform` method is called.

To use the gem, you will need to specify a secret that will be used to encrypt the arguments as well as add the middleware to your Sidekiq client and server middleware stacks. You can set that up by adding this to the end of your Sidekiq initialization:

```ruby
Sidekiq::EncryptedArgs.secret = "YourSecretKey"
Sidekiq::EncryptedArgs.configure!
```

If the secret is not set, the value of the `SIDEKIQ_ENCRYPTED_ARGS_SECRET` environment variable will be used as the secret. If this variable is not set, job arguments will not be encrypted.

The call to `Sidekiq::EncryptedArgs.configure!` will append the encryption middleware to the end of the client and server middleware chains. If you need more control over where the middleware appears in the stacks, you can add them manually instead:

```ruby
Sidekiq.configure_client do |config|
  config.client_middleware do |chain|
    chain.add Sidekiq::EncryptedArgs::ClientMiddleware
  end
end

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::EncryptedArgs::ServerMiddleware
  end
end
```

## Worker Configuration

To declare that a worker is using encrypted arguments, you must set the `encrypted_args` sidekiq option.

Setting the option to `true` will encrypt all the arguments to the `perform` method.

```ruby
class SecretWorker
  include Sidekiq::Worker

  sidekiq_options encrypted_args: true

  def perform(arg_1, arg_2, arg_3)
  end
end
```

You can also encrypt just specific arguments with a hash or an array. This can be useful to preserve visibility into non-sensitive arguments that might be useful for troubleshooting or other reasons. Both of these examples will encrypt just the second argument to the `perform` method.

```ruby
  sidekiq_options encrypted_args: [false, true]
```

```ruby
  sidekiq_options encrypted_args: { 1 => true }
```

You don't need to change anything else about your workers. All of the arguments passed to the `perform` method will already be unencrypted when the method is called.

## Rolling Secrets

If you need to roll your secret, you can simply provide an array when setting the secret.

```ruby
Sidekiq::EncryptedArgs.secret = ["CurrentSecret", "OldSecret"]
```

The left most key will be considered the current key and will be used for encrypting arguments. However, all of the keys will be tried when decrypting. This allows you to switch you secret keys without breaking jobs already enqueued in Redis.

If you are using the `SIDEKIQ_ENCRYPTED_ARGS_SECRET` envrionment variable to specify your secret, you can delimit multiple keys with a spaces.

You can also safely add encryption to an existing worker. Any jobs that are already enqueued will still run even without having the arguments encrypted in Redis.

## Encryption

Encrypted arguments are stored using AES-256-GCM with a key derived from your secret using PBKDF2.
