require 'asset_checker'
require 'tempfile'

RSpec.describe AssetChecker do
  subject(:asset_checker) do
    AssetChecker.new(files, assets_file: assets_file)
  end

  describe '::ASSETS_FILE' do
    it 'exists' do
      expect(File.exist?(AssetChecker::ASSETS_FILE)).to eq(true)
    end
  end

  describe '#check_files' do
    let(:assets_file) { Tempfile.new }

    before do
      File.open(assets_file.path, 'w') do |f|
        f.puts <<-STR
          <% keys = [
            #{asset_strings.map(&:inspect).join("\n")}
          ] %>
        STR
      end
    end

    after do
      assets_file.unlink
    end

    let(:asset_strings) { %w[first_asset.png second_asset.gif] }

    context 'with matching assets' do
      let(:files) { [tempfile.path] }
      let(:tempfile) { Tempfile.new }

      before do
        File.open(tempfile.path, 'w') do |f|
          f.puts(build_js_with_strings('first_asset.png'))
        end
      end

      after { tempfile.unlink }

      it 'identifies no issues ' do
        expect(asset_checker.check_files).to eq(false)
      end
    end

    context 'with an asset mismatch' do
      let(:files) { [tempfile.path] }
      let(:tempfile) { Tempfile.new }

      before do
        File.open(tempfile.path, 'w') do |f|
          f.puts(build_js_with_strings('wont_find.svg'))
        end
      end

      after { tempfile.unlink }

      it 'identifies issues' do
        expect(asset_checker).to receive(:warn).with(tempfile.path)
        expect(asset_checker).to receive(:warn).once.with('Missing asset, wont_find.svg')
        expect(asset_checker.check_files).to eq(true)
      end
    end
  end

  def build_js_with_strings(asset)
    <<-STR
      import React from 'react';
      import useAsset from '../hooks/use-asset';

      function DocumentCapture() {
        const { getAssetPath } = useAsset();

        return (
          <img
            src={getAssetPath('#{asset}')}
            alt="Sample front of state issued ID"
            width={450}
            height={338}
          />
        );
      }

      export default DocumentCapture;
    STR
  end
end
