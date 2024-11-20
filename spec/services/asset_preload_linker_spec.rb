require 'rails_helper'

RSpec.describe AssetPreloadLinker do
  describe '.append' do
    let(:link) { nil }
    let(:as) { 'script' }
    let(:url) { '/script.js' }
    let(:crossorigin) { nil }
    let(:integrity) { nil }
    let(:headers) { { 'Link' => link } }
    subject(:result) do
      AssetPreloadLinker.append(**{ headers:, as:, url:, crossorigin:, integrity: }.compact)
    end

    context 'with absent link value' do
      let(:link) { nil }

      it 'returns a string with only the appended link' do
        expect(result).to eq('</script.js>;rel=preload;as=script')
      end
    end

    context 'with empty link value' do
      let(:link) { '' }

      it 'returns a string with only the appended link' do
        expect(result).to eq('</script.js>;rel=preload;as=script')
      end
    end

    context 'with non-empty link value' do
      let(:link) { '</a.js>;rel=preload;as=script' }

      it 'returns a comma-separated link value of the new and existing link' do
        expect(result).to eq('</a.js>;rel=preload;as=script,</script.js>;rel=preload;as=script')
      end

      context 'with existing link value as frozen string' do
        let(:link) { '</a.js>;rel=preload;as=script'.freeze }

        it 'returns a comma-separated link value of the new and existing link' do
          expect(result).to eq('</a.js>;rel=preload;as=script,</script.js>;rel=preload;as=script')
        end
      end
    end

    context 'with crossorigin option' do
      let(:crossorigin) { true }

      it 'includes crossorigin link param' do
        expect(result).to eq('</script.js>;rel=preload;as=script;crossorigin')
      end
    end

    context 'with integrity option' do
      let(:integrity) { 'abc123' }

      it 'includes integrity link param' do
        expect(result).to eq('</script.js>;rel=preload;as=script;integrity=abc123')
      end
    end
  end
end
