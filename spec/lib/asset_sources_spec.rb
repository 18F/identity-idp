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
    File.open(manifest_file.path, 'w') { |f| f.puts manifest_content }
    allow(I18n).to receive(:locale).and_return(:en)
  end

  after do
    manifest_file.unlink
  end

  subject(:asset_sources) do
    AssetSources.new(
      manifest_path: manifest_file.path, cache_manifest: cache_manifest,
      i18n_locales: [:en, :es, :fr]
    )
  end
  let(:cache_manifest) { true }

  describe '#get_sources' do
    it 'returns unique localized assets for existing sources, in order, localized scripts first' do
      expect(asset_sources.get_sources('application', 'application', 'missing', 'input')).to eq [
        'application.en.js',
        'input.en.js',
        'vendor.js',
        'application.js',
        'input.js',
      ]
    end

    it 'returns identity for any missing, url-like names' do
      expect(asset_sources.get_sources('application', 'https://example.com/main.js')).to eq [
        'application.en.js',
        'vendor.js',
        'application.js',
        'https://example.com/main.js',
      ]
    end

    context 'unset manifest' do
      let(:manifest_content) { nil }

      it 'returns an empty array' do
        expect(asset_sources.get_sources('missing')).to eq([])
      end
    end

    it 'loads the manifest once' do
      expect(asset_sources).to_not receive(:load_manifest)

      asset_sources.get_sources('application')
      asset_sources.get_sources('input')
    end

    context 'uncached manifest' do
      let(:cache_manifest) { false }

      it 'loads the manifest' do
        expect(asset_sources).to receive(:load_manifest).twice.and_call_original

        asset_sources.get_sources('application')
        asset_sources.get_sources('input')
      end
    end
  end

  describe '#get_assets' do
    it 'returns unique, flattened assets' do
      expect(asset_sources.get_assets('application', 'application', 'input')).to eq [
        'clock.svg',
        'spinner.gif',
      ]
    end

    context 'unset manifest' do
      let(:manifest_content) { nil }

      it 'returns an empty array' do
        expect(asset_sources.get_assets('missing')).to eq([])
      end
    end

    it 'loads the manifest once' do
      expect(asset_sources).to_not receive(:load_manifest)

      asset_sources.get_assets('application')
      asset_sources.get_assets('input')
    end

    context 'uncached manifest' do
      let(:cache_manifest) { false }

      it 'loads the manifest' do
        expect(asset_sources).to receive(:load_manifest).twice.and_call_original

        asset_sources.get_assets('application')
        asset_sources.get_assets('input')
      end
    end
  end

  describe '#get_integrity' do
    let(:path) { 'vendor.js' }
    subject(:integrity) { asset_sources.get_integrity(path) }

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

  describe '#load_manifest' do
    it 'sets the manifest' do
      asset_sources.load_manifest

      expect(asset_sources.manifest).to be_kind_of(Hash).and eq(JSON.parse(manifest_content))
    end

    context 'missing file' do
      let(:manifest_content) { nil }

      before do
        manifest_file.unlink
      end

      it 'gracefully sets nil manifest' do
        asset_sources.load_manifest

        expect(asset_sources.manifest).to be_nil
      end
    end

    context 'invalid json' do
      let(:manifest_content) { '{' }

      it 'gracefully sets nil manifest' do
        asset_sources.load_manifest

        expect(asset_sources.manifest).to be_nil
      end
    end
  end
end
