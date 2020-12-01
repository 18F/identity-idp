require 'spec_helper'
require 'yaml_normalizer'

RSpec.describe 'config/country_dialing_codes.yml' do
  subject(:config_path) { 'config/country_dialing_codes.yml' }

  it 'is formatted as normalized YAML' do
    pending 'removing the comment in the file'

    normalized_yaml = YAML.dump(YamlNormalizer.handle_hash(YAML.load_file(config_path)))

    expect(File.read(config_path)).to(eq(normalized_yaml), 'run `make normalize_yaml` to fix')
  end
end
