# Sidekiq Encrypted Args

[![Continuous Integration](https://github.com/bdurand/sidekiq-encrypted_args/workflows/Continuous%20Integration/badge.svg?branch=master)](https://github.com/bdurand/sidekiq-encrypted_args/actions?query=workflow%3A%22Continuous+Integration%22)
[![Maintainability](https://api.codeclimate.com/v1/badges/70ab3782e4d5285eb173/maintainability)](https://codeclimate.com/github/bdurand/sidekiq-encrypted_args/maintainability)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)

Support for encrypting arguments for [Sidekiq](https://github.com/mperham/sidekiq).

## Problem

Sidekiq stores the arguments for jobs as JSON in Redis. If your workers include sensitive information (API keys, passwords, personally identifiable information, etc.), you run the risk of accidentally exposing this information. Job arguments are visible in the Sidekiq web interface and your security will only be as good as your Redis server security.

This can be an even bigger issue if you use scheduled jobs since sensitive data on those jobs will live in Redis until the job is run. Data written to Redis can also be persisted to disk and live on long after the data in Redis has been deleted.

## Solution

This gem adds Sidekiq middleware that allows you to specify job arguments for your workers that should be encrypted in Redis. You do this by adding `encrypted_args` to the `sidekiq_options` in the worker. Jobs for these workers will have their arguments encrypted in Redis and decrypted when passed to the `perform` method.

To use the gem, you will need to specify a secret that will be used to encrypt the arguments as well as add the middleware to your Sidekiq client and server middleware stacks. You can set that up by adding this to the end of your Sidekiq initialization:

```ruby
Sidekiq::EncryptedArgs.configure!(secret: "YourSecretKey")
```

If the secret is not set, the value of the `SIDEKIQ_ENCRYPTED_ARGS_SECRET` environment variable will be used as the secret. If this variable is not set, job arguments will not be encrypted.

The call to `Sidekiq::EncryptedArgs.configure!` will **prepend** the client encryption middleware and **append** server decryption middleware. By doing this, any other middleware you register will only receive the encrypted parameters (e.g. logging middleware will receive the encrypted parameters).

You can add the middleware manually if you need more control over where they appear in the stacks.

```ruby
Sidekiq::EncryptedArgs.secret = "YourSecretKey"

Sidekiq.configure_client do |config|
  config.client_middleware do |chain|
    chain.prepend Sidekiq::EncryptedArgs::ClientMiddleware
  end
end

Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::EncryptedArgs::ServerMiddleware
  end

  # register client middleware on the server so that starting jobs in a Sidekiq::Worker also get encrypted args
  # https://github.com/mperham/sidekiq/wiki/Middleware#client-middleware-registered-in-both-places
  config.client_middleware do |chain|
    chain.prepend Sidekiq::EncryptedArgs::ClientMiddleware
  end
end
```

## Worker Configuration

To declare that a worker is using encrypted arguments, you must set the `encrypted_args` sidekiq option.

Setting the option to `true` will encrypt all the arguments passed to the `perform` method.

```ruby
class SecretWorker
  include Sidekiq::Worker

  sidekiq_options encrypted_args: true

  def perform(arg_1, arg_2, arg_3)
  end
end
```

You can also choose to only encrypt specific arguments with an array of either argument names (symbols or strings) or indexes. This is useful to preserve visibility into non-sensitive arguments for troubleshooting or other reasons. Both of these examples encrypt just the second argument to the `perform` method.

```ruby
# Pass in a list of argument names that should be encrypted
sidekiq_options encrypted_args: [:arg_2]
# or
sidekiq_options encrypted_args: ["arg_2"]

def perform(arg_1, arg_2, arg_3)
end
```

```ruby
# Pass in an array of integers indicating which argument positions should be encrypted
sidekiq_options encrypted_args: [1]

def perform(arg_1, arg_2, arg_3)
end
```

You don't need to change anything else about your workers. All of the arguments passed to the `perform` method will already be unencrypted when the method is called.

## Rolling Secrets

If you need to roll your secret, you can simply provide an array when setting the secret.

```ruby
Sidekiq::EncryptedArgs.secret = ["CurrentSecret", "OldSecret", "EvenOlderSecret"]
```

The first (left most) key will be considered the current key, and is used for encrypting arguments. When decrypting, we iterate over the secrets list until we find the correct one. This allows you to switch you secret keys without breaking jobs already enqueued in Redis.

If you are using the `SIDEKIQ_ENCRYPTED_ARGS_SECRET` environment variable to specify your secret, you can delimit multiple keys with a spaces.

You can also safely add encryption to an existing worker. Any jobs that are already enqueued will still run even without having the arguments encrypted in Redis.

## Encryption

Encrypted arguments are stored using AES-256-GCM with a key derived from your secret using PBKDF2. For more info on the underlying encryption, refer to the [SecretKeys](https://github.com/bdurand/secret_keys) gem.
