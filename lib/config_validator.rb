class ConfigValidator
  def validate(env)
    validate_boolean_keys(env)
  end

  private

  def boolean_warning(bad_keys)
    "You have invalid values (yes/no) for #{bad_keys.uniq.to_sentence} " \
    "in config/application.yml or your environment. " \
    "Please change them to true or false."
  end

  def keys_with_bad_boolean_values(env, keys)
    # Configuration settings for boolean values need to be "true/false"
    # and not "yes/no".

    keys.keep_if { |key| %w[yes no].include?(env[key].to_s.strip.downcase) }
  end

  def validate_boolean_keys(env)
    bad_keys = keys_with_bad_boolean_values(env, env.keys)
    return unless bad_keys.any?
    raise boolean_warning(bad_keys).tr("\n", ' ')
  end
end
