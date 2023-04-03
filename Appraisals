# frozen_string_literal: true

SIDEKIQ_MAJOR_RELEASES = ["7", "6", "5", "4"].freeze

SIDEKIQ_MAJOR_RELEASES.each do |version|
  appraise "sidekiq_#{version}" do
    gem "sidekiq", "~> #{version}.0"
  end
end
