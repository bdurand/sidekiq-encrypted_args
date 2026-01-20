# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2.0.0

### Changed

- A secret key is now required to be set. Previously the code would silently fail if no key was set. This change improves security by protecting against misconfiguration leaking data into Redis.
- Bumped minimum required Ruby version to 2.7 and Sidekiq to 6.3.

## 1.2.0

### Removed

- Removed deprecated method of setting encrypted args with a hash with numeric keys. This method stopped working with Sidekiq 7.1.
- Removed deprecated method of setting encrypted args with an array of booleans.
- Removed deprecated method of setting encrypted args with a mix of symbols and integers.

## 1.1.1

### Fixed

- Client middleware will no longer encrypt already encrypted arguments when a job is retried.

## 1.1.0

### Added

- Use `to_json` if it is defined when serializing encrypted args to JSON.
- Add client middleware to the server default configuration. This ensures that arguments will be encrypted if a worker enqueues a job with encrypted arguments.
- Client middleware now reads sidekiq options from the job hash instead of from the worker class so that the list of encrypted arguments is always in sync on the job payload.
- Added additional option to specify encrypted args with array of argument indexes.

### Changed

- Client middleware is now prepended while server middleware is appended.

### Fixed

- Don't raise error if undefined class name is passed to client middleware as a string.

### Deprecated

- Deprecated setting encrypted args as hash or array of booleans.

## 1.0.2

### Changed

- Remove overly noisy log warning when running without the secret set

## 1.0.1

### Fixed

- Added support for scheduled jobs

## 1.0.0

### Added

- Initial release
