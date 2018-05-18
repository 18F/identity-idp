# rubocop:disable Metrics/LineLength
if FeatureManagement.enable_identity_verification?
  Idv::Proofer.configure do |config|
    config.mock_fallback = Figaro.env.proofer_mock_fallback == 'true'
    config.raise_on_missing_proofers = false if Figaro.env.proofer_raise_on_missing_proofers == 'false'
    config.vendors = JSON.parse(Figaro.env.proofer_vendors || '[]')
  end

  Idv::Proofer.init

  # Until Figaro is implemented in the aamva gem and equifax is removed,
  # ensure env variables are available
  [/^aamva_/, /^equifax_/].each do |pattern|
    ENV.keys.grep(pattern).each do |env_var_name|
      ENV[env_var_name.upcase] = ENV[env_var_name]
    end
  end
end
# rubocop:enable Metrics/LineLength
