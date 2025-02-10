# frozen_string_literal: true

if Rails.env.development? && IdentityConfig.store.rack_mini_profiler
  require 'rack-mini-profiler'

  Rack::MiniProfilerRails.initialize!(Rails.application)
end
