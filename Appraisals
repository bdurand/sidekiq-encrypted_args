# frozen_string_literal: true

# The code is a little more tightly integrated with ActiveRecord so check
# all minor releases. Only need to sanity check major releases of Sidekiq.

SIDEKIQ_MAJOR_RELEASES = ["6", "5", "4"].freeze

SIDEKIQ_MAJOR_RELEASES.each do |version|
  appraise "sidekiq-#{version}" do
    gem "sidekiq", "~> #{version}.0"
  end
end
