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
              ],
              "svg": [
                "clock.svg"
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
              ],
              "svg": [
                "clock.svg"
              ],
              "gif": [
                "spinner.gif"
              ]
            }
          }
        },
        "integrity": {
          "vendor.js": "sha256-aztp/wpATyjXXpigZtP8ZP/9mUCHDMaL7OKFRbmnUIazQ9ehNmg4CD5Ljzym/TyA"
        }
      }
    STR
  end

  before do
    AssetSources.manifest = nil
    File.open(manifest_file.path, 'w') { |f| f.puts manifest_content }
    allow(AssetSources).to receive(:manifest_path).and_return(manifest_file.path)
    allow(I18n).to receive(:available_locales).and_return([:en, :es, :fr])
    allow(I18n).to receive(:locale).and_return(:en)
  end

  after do
    manifest_file.unlink
    AssetSources.manifest = nil
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

    it 'loads the manifest once' do
      expect(AssetSources).to receive(:load_manifest).once.and_call_original

      AssetSources.get_sources('application')
      AssetSources.get_sources('input')
    end

    context 'uncached manifest' do
      before do
        allow(AssetSources).to receive(:cache_manifest).and_return(false)
      end

      it 'loads the manifest' do
        expect(AssetSources).to receive(:load_manifest).twice.and_call_original

        AssetSources.get_sources('application')
        AssetSources.get_sources('input')
      end
    end
  end

  describe '.get_assets' do
    it 'returns unique, flattened assets' do
      expect(AssetSources.get_assets('application', 'application', 'input')).to eq [
        'clock.svg',
        'spinner.gif',
      ]
    end

    context 'unset manifest' do
      let(:manifest_content) { nil }

      it 'returns an empty array' do
        expect(AssetSources.get_assets('missing')).to eq([])
      end
    end

    it 'loads the manifest once' do
      expect(AssetSources).to receive(:load_manifest).once.and_call_original

      AssetSources.get_assets('application')
      AssetSources.get_assets('input')
    end

    context 'uncached manifest' do
      before do
        allow(AssetSources).to receive(:cache_manifest).and_return(false)
      end

      it 'loads the manifest' do
        expect(AssetSources).to receive(:load_manifest).twice.and_call_original

        AssetSources.get_assets('application')
        AssetSources.get_assets('input')
      end
    end
  end

  describe '.get_integrity' do
    let(:path) { 'vendor.js' }
    subject(:integrity) { AssetSources.get_integrity(path) }

    it 'returns the integrity hash' do
      expect(integrity).to start_with('sha256-')
    end

    context 'a path which does not exist in the manifest' do
      let(:path) { 'missing.js' }

      it 'returns nil' do
        expect(integrity).to be_nil
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
    end

    context 'invalid json' do
      let(:manifest_content) { '{' }

      it 'gracefully sets nil manifest' do
        AssetSources.load_manifest

        expect(AssetSources.manifest).to be_nil
      end
    end
  end
end
