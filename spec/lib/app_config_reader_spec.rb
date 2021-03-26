require 'rails_helper'

RSpec.describe AppConfigReader do
  DEFAULT_YAML = <<~HEREDOC
    development:
      config1: 'test'
      config2: 'override me'
    test:
      config1: 'test but different'
  HEREDOC
  OVERRIDE_YAML = <<~HEREDOC
    development:
      config2: 'overriden value'
  HEREDOC

  around(:each) do |ex|
    Dir.mktmpdir do |root|
      set_tmp_dir_fixtures(root)
      reader.root_path = root
      ex.run
    end
  end

  subject(:reader) { AppConfigReader.new }

  it 'merges the default and override configurations' do
    configuration = reader.read_configuration

    expect(configuration['development']['config1']).to eq('test')
    expect(configuration['development']['config2']).to eq('overriden value')
    expect(configuration['test']['config1']).to eq('test but different')
  end

  def set_tmp_dir_fixtures(root)
    FileUtils.mkdir_p(File.join(root, 'config'))
    File.write(File.join(root, 'config', 'application.yml.default'), DEFAULT_YAML)
    File.write(File.join(root, 'config', 'application.yml'), OVERRIDE_YAML)
  end
end
