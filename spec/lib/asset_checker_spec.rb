require 'asset_checker'

RSpec.describe AssetChecker do
  subject(:asset_checker) do
    AssetChecker.new(files, assets_file: assets_file, translations_file: translations_file)
  end

  let(:assets_file) { Tempfile.new }
  let(:translations_file) { Tempfile.new }

  before do
    File.open(assets_file.path, 'w') do |f|
      f.puts <<-STR
        <% keys = [
          #{asset_strings.map(&:inspect).join("\n")}
        ] %>
      STR
    end

    File.open(translations_file.path, 'w') do |f|
      f.puts YAML.dump(translation_strings)
    end
  end

  after do
    assets_file.unlink
    translations_file.unlink
  end

  describe '#check_files' do
    let(:translation_strings) { %w[first_translation second_translation] }
    let(:asset_strings) { %w[first_asset.png second_asset.gif] }

    context 'with matching assets' do
      let(:files) { [tempfile.path] }
      let(:tempfile) { Tempfile.new }

      before do
        File.open(tempfile.path, 'w') do |f|
          f.puts(build_js_with_strings('first_asset.png', 'first_translation'))
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
          f.puts(build_js_with_strings('wont_find.svg', 'not-found'))
        end
      end

      after { tempfile.unlink }

      it 'identifies issues' do
        allow(asset_checker).to receive(:load_included_strings).and_return(asset_strings,
                                                                           translation_strings)
        expect(asset_checker).to receive(:warn).with(tempfile.path)
        expect(asset_checker).to receive(:warn).with('Missing translation, not-found')
        expect(asset_checker).to receive(:warn).twice.with('Missing asset, wont_find.svg')
        expect(asset_checker.check_files).to eq(true)
      end
    end
  end

  def build_js_with_strings(asset, translation)
    "
    import React from 'react';
    import AcuantCapture from './acuant-capture';
    import DocumentTips from './document-tips';
    import Image from './image';
    import useI18n from '../hooks/use-i18n';

    function DocumentCapture() {
      const { t } = useI18n();

      const sample = (
        <Image
          assetPath=\"#{asset}\"
          alt=\"Sample front of state issued ID\"
          width={450}
          height={338}
        />
      );

      return (
        <>
          <h2>{t('#{translation}')}</h2>
          <DocumentTips sample={sample} />
          <AcuantCapture />
          <Image assetPath=\"#{asset}\" alt=\"\" />
        </>
      );
    }

    export default DocumentCapture;
    "
  end
end
