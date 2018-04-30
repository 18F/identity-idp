Idv::Proofer.configure do |config|
  config.mock_fallback = true
  config.raise_on_missing_proofers = true
end

Idv::Proofer.load_vendors!
