require 'rails_helper'

RSpec.describe Idv::DocAuthFormResponse do
  let(:extra) { {} }
  subject(:response) { described_class.new(success: true, extra: extra) }

  describe '#pii_from_doc' do
    it 'defaults to empty hash' do
      expect(response.pii_from_doc).to eq({})
    end

    it 'is writable' do
      response.pii_from_doc = Idp::Constants::MOCK_IDV_APPLICANT

      expect(response.pii_from_doc).to eq(Idp::Constants::MOCK_IDV_APPLICANT)
    end
  end

  describe '#attention_with_barcode?' do
    it { expect(subject.attention_with_barcode?).to eq(false) }

    context 'with attention with barcode response extra' do
      let(:extra) { { attention_with_barcode: true } }

      it { expect(subject.attention_with_barcode?).to eq(true) }
    end
  end
end
