class ConfigValidator
  include Pii::Encodable

  def initialize(env = ENV)
    @env = env
    @candidate_keys = keys_without_figaro_prefix
  end

  def validate
    bad_keys = keys_with_bad_boolean_values + keys_with_bad_base64_encoding
    return unless bad_keys.any?
    raise warning(bad_keys).tr("\\\n", ' ')
  end

  private

  attr_reader :env, :candidate_keys

  def keys_without_figaro_prefix
    env.keys.delete_if { |key| key.starts_with?(Figaro::Application::FIGARO_ENV_PREFIX) }
  end

  def keys_with_bad_boolean_values
    candidate_keys.select { |key| %w(yes no).include?(env[key]) }
  end

  def keys_with_bad_base64_encoding
    candidate_keys.select { |key| bad_base64_encoding?(key) }
  end

  def bad_base64_encoding?(key)
    requires_base64_encoding?(key) && !valid_base64_encoding?(env[key])
  end

  def requires_base64_encoding?(key)
    %w(attribute_encryption_key email_encryption_key).include?(key)
  end

  def warning(bad_keys)
    <<~HEREDOC
      You have invalid values for #{bad_keys.uniq.to_sentence} in
      #{config_location}.#{bad_boolean_keys_instructions} #{bad_base64_keys_instructions}
    HEREDOC
  end

  def config_location
    return 'config/application.yml' if File.exist?(Rails.root.join('config/application.yml'))

    'your ENV configuration'
  end

  def bad_boolean_keys_instructions
    return if keys_with_bad_boolean_values.empty?
    " Please change #{bad_boolean_keys_text} to 'true' or 'false'."
  end

  def bad_base64_keys_instructions
    return if keys_with_bad_base64_encoding.empty?
    "Please change #{bad_base64_keys_text} to a valid base64 encoded value."
  end

  def bad_boolean_keys_text
    keys_with_bad_boolean_values.uniq.to_sentence
  end

  def bad_base64_keys_text
    keys_with_bad_base64_encoding.uniq.to_sentence
  end
end
