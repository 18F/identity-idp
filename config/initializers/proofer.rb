if FeatureManagement.enable_identity_verification?
  Idv::Proofer.configure do |config|
    config.mock_fallback = Figaro.env.proofer_mock_fallback == 'true'
    config.raise_on_missing_proofers = Figaro.env.proofer_raise_on_missing_proofers == 'false'
    config.vendors = JSON.parse(Figaro.env.proofer_vendors || '[]')
  end

  Idv::Proofer.init
end
