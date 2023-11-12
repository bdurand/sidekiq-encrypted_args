# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.1.1

### Added

- Sidekiq 7 compatibility.

## 1.1.0

### Added

- Added additional option to specify encrypted args with array of argument indexes.

### Fixed

- Use `to_json` if it is defined when serializing encrypted args to JSON.
- Add client middleware to the server default configuration. This ensures that arguments will be encrypted if a worker enqueues a job with encrypted arguments.
- Don't blow up if class name that is not defined is passed to client middleware.

### Changed

- Client middleware now reads sidekiq options from the job hash instead of from the worker class so that the list of encrypted arguments is always in sync on the job payload.
- Deprecated setting encrypted args as hash or array of booleans.
- Client middleware is prepended while server middleware is appended.

## 1.0.2

### Changed

- Remove overly noisy log warning when running without the secret set

## 1.0.1

### Fixed

- Now works with scheduled jobs
- Scheduled jobs dispatch by class name instead of `Class`, requiring a constant lookup

## 1.0.0

### Added

- Initial release
