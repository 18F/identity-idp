if Rails.env.development? && Identity::Hostdata.settings.rack_mini_profiler == 'on'
  require 'rack-mini-profiler'

  Rack::MiniProfilerRails.initialize!(Rails.application)
end
