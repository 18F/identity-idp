# frozen_string_literal: true

require 'i18n/tasks'
require 'yaml_normalizer'

RSpec.describe 'I18n' do
  let(:i18n) { I18n::Tasks::BaseTask.new }
  let(:missing_keys) { i18n.missing_keys }
  let(:unused_keys) { i18n.unused_keys }

  it 'does not have missing keys' do
    expect(missing_keys).to(
      be_empty,
      "Missing #{missing_keys.leaves.count} i18n keys, run `i18n-tasks missing' to show them"
    )
  end

  it 'does not have unused keys' do
    expect(unused_keys).to(
      be_empty,
      "#{unused_keys.leaves.count} unused i18n keys, run `i18n-tasks unused' to show them"
    )
  end

  root_dir = File.expand_path(File.join(File.dirname(__FILE__), '../'))

  Dir[File.join(root_dir, '/config/locales/**/*.yml')].each do |full_path|
    i18n_file = full_path.sub("#{root_dir}/", '')

    describe i18n_file do
      it 'has only lower_snake_case keys' do
        keys = hash_keys(YAML.load_file(full_path))

        bad_keys = keys.reject { |key| key =~ /^[a-z0-9_.]+$/ }

        expect(bad_keys).to be_empty
      end

      it 'has only has XML-safe identifiers (keys start with a letter)' do
        keys = hash_keys(YAML.load_file(full_path))

        bad_keys = keys.select { |key| key.split('.').any? { |part| part =~ /^[0-9]/ } }

        expect(bad_keys).to be_empty
      end

      it 'is formatted as normalized YAML (run scripts/normalize-yaml)' do
        normalized_yaml = YAML.dump(YamlNormalizer.chomp_each(YAML.load_file(full_path)))

        expect(File.read(full_path)).to eq(normalized_yaml)
      end
    end
  end

  def hash_keys(hash, parent_keys: [])
    keys = []

    hash.each do |key, value|
      if value.is_a?(Hash)
        keys += hash_keys(value, parent_keys: parent_keys + [key])
      else
        keys << [*parent_keys, key].join('.')
      end
    end

    keys
  end
end
