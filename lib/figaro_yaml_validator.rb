class FigaroYamlValidator
  FILE_PATH = File.join(Rails.root, 'config', 'application.yml')
  FIGARO_YAML = File.exist?(FILE_PATH) ? YAML.load(IO.read(FILE_PATH)) : {}

  def validate(yaml_data = FIGARO_YAML)
    bad_keys = []
    check_for_bad_values(yaml_data, bad_keys)
    return unless bad_keys.any?
    raise warning(bad_keys).tr("\\\n", ' ')
  end

  private

  def check_for_bad_values(yaml_data, bad_keys)
    yaml_data.map do |key, value|
      if value.is_a?(Hash)
        check_for_bad_values(value, bad_keys)
      elsif %w(yes no).include?(value)
        bad_keys << key
      end
    end
  end

  def warning(bad_keys)
    <<~HEREDOC
      You have invalid values for #{bad_keys.uniq.to_sentence} in
      config/application.yml. Please change them to true or false
    HEREDOC
  end
end
