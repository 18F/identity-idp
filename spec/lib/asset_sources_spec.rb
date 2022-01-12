require 'rails_helper'
require 'asset_sources'
require 'tempfile'

RSpec.describe AssetSources do
  include ActionView::Helpers::TranslationHelper

  let(:manifest_file) { Tempfile.new }
  let(:manifest_content) do
    <<~STR
      {
        "entrypoints": {
          "application": {
            "assets": {
              "js": [
                "vendor.js",
                "application.en.js",
                "application.fr.js",
                "application.es.js",
                "application.js"
              ]
            }
          },
          "input": {
            "assets": {
              "js": [
                "vendor.js",
                "input.en.js",
                "input.fr.js",
                "input.es.js",
                "input.js"
              ]
            }
          }
        }
      }
    STR
  end

  before do
    File.open(manifest_file.path, 'w') { |f| f.puts manifest_content }
    allow(AssetSources).to receive(:manifest_path).and_return(manifest_file.path)
    allow(I18n).to receive(:available_locales).and_return([:en, :es, :fr])
    allow(I18n).to receive(:locale).and_return(:en)
  end

  after do
    manifest_file.unlink
  end

  describe '.get_sources' do
    it 'returns unique localized assets for existing sources, in order, localized scripts first' do
      expect(AssetSources.get_sources('application', 'application', 'missing', 'input')).to eq [
        'application.en.js',
        'input.en.js',
        'vendor.js',
        'application.js',
        'input.js',
      ]
    end

    context 'unset manifest' do
      let(:manifest_content) { nil }

      it 'returns an empty array' do
        expect(AssetSources.get_sources('missing')).to eq([])
      end
    end

    it 'loads the manifest' do
      expect(AssetSources).to receive(:load_manifest).twice.and_call_original

      AssetSources.get_sources('application')
      AssetSources.get_sources('input')
    end

    context 'cached manifest' do
      before do
        allow(AssetSources).to receive(:cache_manifest).and_return(true)
      end

      it 'loads the manifest once' do
        expect(AssetSources).to receive(:load_manifest).once.and_call_original

        AssetSources.get_sources('application')
        AssetSources.get_sources('input')
      end
    end
  end

  describe '.load_manifest' do
    it 'sets the manifest' do
      AssetSources.load_manifest

      expect(AssetSources.manifest).to be_kind_of(Hash).and eq(JSON.parse(manifest_content))
    end

    context 'missing file' do
      let(:manifest_content) { nil }

      before do
        manifest_file.unlink
      end

      it 'gracefully sets nil manifest' do
        AssetSources.load_manifest

        expect(AssetSources.manifest).to be_nil
      end

      context 'production environment' do
        before do
          allow(Rails.env).to receive(:production?).and_return(true)
        end

        it 'raises an exception' do
          expect { AssetSources.load_manifest }.to raise_exception(Errno::ENOENT)
        end
      end
    end

    context 'invalid json' do
      let(:manifest_content) { '{' }

      it 'gracefully sets nil manifest' do
        AssetSources.load_manifest

        expect(AssetSources.manifest).to be_nil
      end

      context 'production environment' do
        before do
          allow(Rails.env).to receive(:production?).and_return(true)
        end

        it 'raises an exception' do
          expect { AssetSources.load_manifest }.to raise_exception(JSON::ParserError)
        end
      end
    end
  end
end
