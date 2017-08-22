class ConfigValidator
  ENV_PREFIX = Figaro::Application::FIGARO_ENV_PREFIX

  def validate(env = ENV)
    bad_keys = keys_with_bad_values(env, candidate_keys(env))
    return unless bad_keys.any?
    raise warning(bad_keys).tr("\n", ' ')
  end

  private

  def candidate_keys(env)
    env.keys.keep_if { |key| candidate_key?(env, key) }
  end

  def candidate_key?(env, key)
    # A key is associated with a configuration setting if there are two
    # settings in the environment: one with and without the Figaro prefix.
    # We're only interested in the configuration settings and not other
    # environment variables.

    env.include?(key) and env.include?(ENV_PREFIX + key)
  end

  def keys_with_bad_values(env, keys)
    # Configuration settings for boolean values need to be "true/false"
    # and not "yes/no".

    keys.keep_if { |key| %w[yes no].include?(env[key].strip.downcase) }
  end

  def warning(bad_keys)
    "You have invalid values (yes/no) for #{bad_keys.uniq.to_sentence} " \
    "in config/application.yml or your environment. " \
    "Please change them to true or false."
  end
end
