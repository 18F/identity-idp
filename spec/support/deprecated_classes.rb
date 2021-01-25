RSpec.configure do |config|
  deprecated = YAML.safe_load(File.read(File.expand_path('../../../.erb-lint.yml', __FILE__))).
    dig('linters', 'DeprecatedClasses', 'rule_set').
    flat_map { |rule| rule['deprecated'] }

  pattern = Regexp.new "(^|\\b)(#{deprecated.join('|')})(\\b|$)"

  config.before(:each) do
    allow_any_instance_of(ActionView::Helpers::TagHelper::TagBuilder).
      to receive(:tag_options).
      with(hash_excluding(class: pattern), anything).
      and_call_original
  end
end
