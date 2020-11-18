if Rails.env.development? && AppConfig.env.rack_mini_profiler == 'on'
  require 'rack-mini-profiler'

  Rack::MiniProfilerRails.initialize!(Rails.application)
end
