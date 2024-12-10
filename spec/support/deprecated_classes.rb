class ActionView::Helpers::TagHelper::TagBuilder
  def self.deprecated_classes
    @deprecated_classes ||= begin
      YAML.safe_load(File.read(File.expand_path('../../../.erb_lint.yml', __FILE__))).
        dig('linters', 'DeprecatedClasses', 'rule_set').
        flat_map { |rule| rule['deprecated'] }.
        map { |regex_str| Regexp.new "^#{regex_str}$" }
    end
  end

  def modified_tag_option(key, value, *rest)
    original_result = original_tag_option(key, value, *rest)
    return original_result unless key.to_s == 'class'
    _attribute, classes = original_result.split('=')
    classes = classes.tr('"', '').split(/ +/)
    regex = self.class.deprecated_classes.find { |r| classes.any? { |c| r =~ c } }
    raise "CSS class '#{value}' matched regex for deprecated classes #{regex}" if regex
    original_result
  end

  alias_method :original_tag_option, :tag_option
  alias_method :tag_option, :modified_tag_option
end
