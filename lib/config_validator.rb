class ConfigValidator
  ENV_PREFIX = Figaro::Application::FIGARO_ENV_PREFIX
  NON_EMPTY_KEYS = %w[
    phone_proofing_vendor
    profile_proofing_vendor
  ].freeze

  def validate(env = ENV)
    validate_boolean_keys(env)
    validate_non_empty_keys(env)
  end

  private

  def boolean_warning(bad_keys)
    "You have invalid values (yes/no) for #{bad_keys.uniq.to_sentence} " \
    "in config/application.yml or your environment. " \
    "Please change them to true or false."
  end

  def candidate_keys(env)
    @candidate_keys ||= env.keys.keep_if { |key| candidate_key?(env, key) }
  end

  def candidate_key?(env, key)
    # A key is associated with a configuration setting if there are two
    # settings in the environment: one with and without the Figaro prefix.
    # We're only interested in the configuration settings and not other
    # environment variables.

    env.include?(key) and env.include?(ENV_PREFIX + key)
  end

  def empty_keys_warning(empty_keys)
    'These configs are required and were empty: ' + empty_keys.join(', ')
  end

  def keys_with_bad_boolean_values(env, keys)
    # Configuration settings for boolean values need to be "true/false"
    # and not "yes/no".

    keys.keep_if { |key| %w[yes no].include?(env[key].strip.downcase) }
  end

  def validate_boolean_keys(env)
    bad_keys = keys_with_bad_boolean_values(env, candidate_keys(env))
    return unless bad_keys.any?
    raise boolean_warning(bad_keys).tr("\n", ' ')
  end

  def validate_non_empty_keys(env)
    empty_keys = NON_EMPTY_KEYS - env.keys
    return if empty_keys.empty?
    raise empty_keys_warning(empty_keys)
  end
end
