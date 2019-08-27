file = Rails.root.join('config', 'service_providers.yml').read
content = ERB.new(file).result
SP_CONFIG = YAML.safe_load(content).fetch(Rails.env, {})
