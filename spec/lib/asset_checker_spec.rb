require 'asset_checker'

def get_js_with_strings(asset = 'first_asset.png', translation = 'first_translation') # rubocop:disable Metrics/LineLength Lint/UselessAssignment
  "
  import React from 'react';
  import AcuantCapture from './acuant-capture';
  import DocumentTips from './document-tips';
  import Image from './image';
  import useI18n from '../hooks/use-i18n';

  function DocumentCapture() {
    const t = useI18n();

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
      </>
    );
  }

  export default DocumentCapture;
  "
end

RSpec.describe AssetChecker do
  describe '.check_files' do
    let(:translation_strings) { %w[first_translation second_translation] }
    let(:asset_strings) { %w[first_asset.png second_asset.gif] }

    context 'with matching assets' do
      let(:tempfile) { Tempfile.new }

      before do
        File.open(tempfile.path, 'w') do |f|
          f.puts(get_js_with_strings)
        end
      end

      after { tempfile.unlink }

      it 'identifies no issues ' do
        allow(AssetChecker).to receive(:load_included_strings).and_return(asset_strings,
                                                                          translation_strings)

        expect(AssetChecker.check_files([tempfile.path])).to eq(false)
      end
    end

    context 'with an asset mismatch' do
      let(:tempfile) { Tempfile.new }

      before do
        File.open(tempfile.path, 'w') do |f|
          f.puts(get_js_with_strings(asset = 'wont_find.svg', translation = 'not-found'))
        end
      end

      after { tempfile.unlink }

      it 'identifies issues' do
        allow(AssetChecker).to receive(:load_included_strings).and_return(asset_strings,
                                                                          translation_strings)
        expect(AssetChecker).to receive(:warn).with(tempfile.path)
        expect(AssetChecker).to receive(:warn).with('Missing translation, not-found')
        expect(AssetChecker).to receive(:warn).with('Missing asset, wont_find.svg')
        expect(AssetChecker.check_files([tempfile.path])).to eq(true)
      end
    end
  end
end
