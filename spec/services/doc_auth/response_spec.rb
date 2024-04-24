require 'rails_helper'

RSpec.describe DocAuth::Response do
  let(:success) { true }
  let(:errors) { {} }
  let(:exception) { nil }
  let(:pii_from_doc) { {} }
  let(:attention_with_barcode) { false }

  subject(:response) do
    described_class.new(
      success: success,
      errors: errors,
      exception: exception,
      pii_from_doc: pii_from_doc,
      attention_with_barcode: attention_with_barcode,
    )
  end

  describe '#to_h' do
    context 'pii from doc present' do
      let(:pii_from_doc) { { sensitive: 'sensitive' } }

      it 'does not include pii from doc' do
        expect(response.to_h.to_s).not_to match('sensitive')
      end
    end
  end

  describe '#attention_with_barcode?' do
    it 'returns false' do
      expect(response.attention_with_barcode?).to eq(false)
    end
  end

  describe 'doc_type_supported?' do
    it 'returns true by default' do
      expect(response.doc_type_supported?).to eq(true)
    end
  end
end
