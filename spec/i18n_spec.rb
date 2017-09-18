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

  it 'does not have keys with missing interpolation arguments' do
    missing_interpolation_argument_keys = []

    i18n.data[i18n.base_locale].select_keys do |key, _node|
      next if i18n.t(key).is_a?(Array) || i18n.t(key).nil?

      interpolation_arguments = i18n.locales.map do |locale|
        extract_interpolation_arguments i18n.t(key, locale)
      end.compact

      missing_interpolation_argument_keys.push(key) if interpolation_arguments.uniq.length > 1
    end

    expect(missing_interpolation_argument_keys).to be_empty
  end

  root_dir = File.expand_path(File.join(File.dirname(__FILE__), '../'))

  Dir[File.join(root_dir, '/config/locales/**/*.yml')].each do |full_path|
    i18n_file = full_path.sub("#{root_dir}/", '')

    describe i18n_file do
      it 'has only lower_snake_case keys' do
        keys = flatten_hash(YAML.load_file(full_path)).keys

        bad_keys = keys.reject { |key| key =~ /^[a-z0-9_.]+$/ }

        expect(bad_keys).to be_empty
      end

      it 'has only has XML-safe identifiers (keys start with a letter)' do
        keys = flatten_hash(YAML.load_file(full_path)).keys

        bad_keys = keys.select { |key| key.split('.').any? { |part| part =~ /^[0-9]/ } }

        expect(bad_keys).to be_empty
      end

      it 'has correctly-formatted interpolation values' do
        bad_keys = flatten_hash(YAML.load_file(full_path)).select do |_key, value|
          next unless value.is_a?(String)

          interpolation_names = value.scan(/%\{([^\}]+)\}/).flatten

          interpolation_names.any? { |name| name.downcase != name }
        end

        expect(bad_keys).to be_empty
      end

      it 'is formatted as normalized YAML (run scripts/normalize-yaml)' do
        normalized_yaml = YAML.dump(YamlNormalizer.handle_hash(YAML.load_file(full_path)))

        expect(File.read(full_path)).to eq(normalized_yaml)
      end
    end
  end

  def extract_interpolation_arguments(translation)
    return if translation == 'NOT TRANSLATED YET'

    translation.scan(I18n::INTERPOLATION_PATTERN).map(&:compact).map(&:first).to_set
  end

  def flatten_hash(hash, parent_keys: [], out_hash: {}, &block)
    hash.each do |key, value|
      if value.is_a?(Hash)
        flatten_hash(value, parent_keys: parent_keys + [key], out_hash: out_hash, &block)
      else
        flat_key = [*parent_keys, key].join('.')
        out_hash[flat_key] = value
      end
    end

    out_hash
  end
end
