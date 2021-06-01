# if IdentityConfig.store.rack_mini_profiler
  # Rack::MiniProfilerRails.initialize!(Rails.application)
# end
Rack::MiniProfiler.config.storage = Rack::MiniProfiler::MemoryStore
