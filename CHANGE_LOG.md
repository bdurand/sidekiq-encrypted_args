# Change log

## unreleased

* Use `to_json` if it is defined when serializing encrypted args to JSON. Fixes bug when non-JSON compatible types are passed as arguments

* Add client middleware to server on default configuration so arguments will remain encrypted if a server jobs enqueues a job with encrypted arguments.

* Read sidekiq options from job hash and write normalized value from the client middleware so the options on a job will always be in sync with how the job was serialized.

* Don't blow up if class name that is not defined is passed to client middleware.

## 1.0.2

* Remove overly noisy log warning when running without the secret set

## 1.0.1

* Now works with scheduled jobs
  * Scheduled jobs dispatch by class name instead of `Class`, requiring a constant lookup

## 1.0.0

* Initial release
