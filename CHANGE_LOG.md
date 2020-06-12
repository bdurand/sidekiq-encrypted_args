# Change Log

## 1.1.0

* Use `to_json` if it is defined when serializing encrypted args to JSON.

* Add client middleware to the server default configuration. This ensures that arguments will be encrypted if a worker enqueues a job with encrypted arguments.

* Client middleware now reads sidekiq options from the job hash instead of from the worker class so that the list of encrypted arguments is always in sync on the job payload.

* Don't blow up if class name that is not defined is passed to client middleware.

* Added additional option to specify encrypted args with array of argument indexes.

* Deprecated setting encrypted args as hash or array of booleans.

## 1.0.2

* Remove overly noisy log warning when running without the secret set

## 1.0.1

* Now works with scheduled jobs
  * Scheduled jobs dispatch by class name instead of `Class`, requiring a constant lookup

## 1.0.0

* Initial release
