class ConfigValidator
  def validate(env = ENV)
    bad_keys = keys_with_bad_values(env, candidate_keys(env))
    return unless bad_keys.any?
    raise warning(bad_keys).tr("\\\n", ' ')
  end

  private

  def candidate_keys(env)
    env.keys.delete_if { |key| key.starts_with?(Figaro::Application::FIGARO_ENV_PREFIX) }
  end

  def keys_with_bad_values(env, keys)
    keys.keep_if { |key| %w(yes no).include?(env[key]) }
  end

  def warning(bad_keys)
    "You have invalid values for #{bad_keys.uniq.to_sentence} in " \
    "config/application.yml. Please change them to true or false."
  end
end
