if Rails.env.development? && Figaro.env.rack_mini_profiler == 'on'
  require 'rack-mini-profiler'

  Rack::MiniProfilerRails.initialize!(Rails.application)
end
