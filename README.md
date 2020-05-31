# Sidekiq Encrypted Args

Support for encrypting arguments for [Sidekiq]|(https://github.com/mperham/sidekiq).

## The Problem

Sidekiq stores the arguments for jobs as JSON in Redis. If your workers include sensitive information (API keys, passwords, personally identifiable information, etc.), then you can accidentally expose this information. The arguments are visible in the Sidekiq web interface and your security will only be as good as your Redis server security.

This can be an even bigger issue if you use scheduled jobs to enqueue jobs with sensitive data far into the future.

## The Solution

This gem adds some Sidekiq middleware to support encrypting specified arguments on your workers. Workers can specify `encrypted_args` in the `sidekiq_options` to turn on the encryption functionality. Jobs for these workers will have their arguments encrypted before being stored in Redis and decrypted before the `perform` method is called.

To use the gem, you will need to set an encryption key used to encrypt the arguments and add middleware to your Sidekiq client and server middleware stacks.

The full initialization code would look something like this:

```ruby
Sidekiq::EncryptedArgs.secret = "YourSecretKey"

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

The encryption key will default to the value in the `SIDEKIQ_ENCRYPTED_ARGS_SECRET` envrionment variable.

You can also call `Sidekiq::EncryptedArgs.configure!` to add the middleware to the stacks. The disadvantage of this, however, is that you lose control over where in the stack the middleware is added. In many cases this is fine, but if you have have other middleware that reads teh arguments, you may need to make sure the encryption middlewares appear in a specific spot in the stack. Until the middlewares have been run, the job arguments will be encrypted/decrypted.

## Worker Configuration

To declare that a worker is using encrypted arguments, you must set the `encrypted_args` sidekiq options.

```ruby
class SecretWorker
  include Sidekiq::Worker

  sidekiq_options encrypted_args: true

  def perform(arg_1, arg_2, arg_3)
  end
end
```

You can also specify encrypting just specific arguments with a hash or an array. Both of these will encrypt just the second argument to the `perform` method.

```ruby
  sidekiq_options encrypted_args: [false, true]
```

```ruby
  sidekiq_options encrypted_args: { 1 => true }
```

## Rolling Secrets

You can roll your secret key by using an array when setting `Sidekiq::EncryptedArgs.encryption_secret`. The left most key will be considered the current key and will be used for encryption. All of the keys will be tried in order for decrypting. This allows you to switch you secret keys without breaking jobs already enqueued in Redis.

If you are using the `SIDEKIQ_ENCRYPTED_ARGS_SECRET` envrionment variable to specify your secret, you can specify multiple keys by delimiting them with a space.

You can also safely add encryption to an existing worker. Any jobs that are already enqueued will still run even without having the arguments encrypted.
