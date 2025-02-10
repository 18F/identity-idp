require 'spec_helper'
require 'i18n_flat_yml_backend'
require 'tmpdir'

RSpec.describe I18nFlatYmlBackend do
  describe '.unflatten' do
    it 'splits keys by periods to create nested hashes' do
      flat = YAML.load <<~STR
        foo.bar.baz: foo bar baz
        foo.arr:
        - first
        - second
      STR

      expect(I18nFlatYmlBackend.unflatten(flat)).to eq(
        'foo' => {
          'bar' => {
            'baz' => 'foo bar baz',
          },
          'arr' => ['first', 'second'],
        },
      )
    end
  end

  describe '.locale' do
    it 'grabs the locale off of the filename' do
      expect(I18nFlatYmlBackend.locale('foo/bar/en.yml')).to eq('en')
      expect(I18nFlatYmlBackend.locale('foo/bar/fr-FR.yml')).to eq('fr-FR')
    end
  end

  describe '#load_yml' do
    subject(:backend) { I18nFlatYmlBackend.new }

    around do |ex|
      Dir.mktmpdir('/locales') do |dir|
        @tmpdir = dir
        ex.run
      end
    end

    before do
      write_file File.join(@tmpdir, 'flat/en.yml'), <<~STR
        flat.key.translation: 'flat key translation'
      STR

      write_file File.join(@tmpdir, 'nested/en.yml'), <<~STR
        en:
          nested:
            key:
              translation: 'nested key translation'
      STR
    end

    it 'handles both flattened and nested translations' do
      backend.load_translations(
        File.join(@tmpdir, 'flat/en.yml'),
        File.join(@tmpdir, 'nested/en.yml'),
      )

      expect(backend.translate(:en, 'flat.key.translation')).to eq('flat key translation')
      expect(backend.translate(:en, 'nested.key.translation')).to eq('nested key translation')
    end

    def write_file(path, content)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'w') { |f| f.write(content) }
    end
  end
end
