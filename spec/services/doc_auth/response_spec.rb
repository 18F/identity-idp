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

  describe '#merge' do
    let(:other_success) { false }
    let(:other_errors) { {} }
    let(:other_exception) { nil }
    let(:other_pii_from_doc) { {} }
    let(:other_attention_with_barcode) { false }
    let(:other) do
      described_class.new(
        success: other_success,
        errors: other_errors,
        exception: other_exception,
        pii_from_doc: other_pii_from_doc,
        attention_with_barcode: other_attention_with_barcode,
      )
    end
    let!(:merged) { response.merge(other) }

    it 'does not mutate the original instance' do
      expect(response.success?).to eq(true)
    end

    it 'returns merged instance' do
      expect(merged).to be_kind_of(DocAuth::Response)
    end

    describe 'success' do
      context 'both failure' do
        let(:success) { false }
        let(:other_success) { false }

        it 'results in false' do
          expect(merged.success?).to eq(false)
        end
      end

      context 'both success' do
        let(:success) { true }
        let(:other_success) { true }

        it 'results in true' do
          expect(merged.success?).to eq(true)
        end
      end

      context 'one failure' do
        let(:success) { true }
        let(:other_success) { false }

        it 'results in false' do
          expect(merged.success?).to eq(false)
        end
      end
    end

    describe 'errors' do
      let(:errors) { { a: 'foo error' } }
      let(:other_errors) { { b: 'bar error' } }

      it 'merges errors' do
        expect(merged.errors).to eq(
          a: 'foo error',
          b: 'bar error',
        )
      end
    end

    describe 'exception' do
      context 'no exception' do
        it 'results in no exception' do
          expect(merged.exception).to be_nil
        end
      end

      context 'own exception' do
        let(:exception) { StandardError.new }

        it 'results in exception' do
          expect(merged.exception).to eq(exception)
        end
      end

      context 'other exception' do
        let(:other_exception) { StandardError.new }

        it 'results in exception' do
          expect(merged.exception).to eq(other_exception)
        end
      end
    end

    describe 'pii_from_doc' do
      let(:pii_from_doc) { { a: 'foo pii' } }
      let(:other_pii_from_doc) { { b: 'bar pii' } }

      it 'merges pii from doc' do
        expect(merged.pii_from_doc).to eq(
          a: 'foo pii',
          b: 'bar pii',
        )
      end
    end

    describe 'attention_with_barcode?' do
      it { expect(merged.attention_with_barcode?).to eq(false) }

      context 'with own attention with barcode' do
        let(:attention_with_barcode) { true }

        it { expect(merged.attention_with_barcode?).to eq(true) }
      end

      context 'with other attention with barcode' do
        let(:other_attention_with_barcode) { true }

        it { expect(merged.attention_with_barcode?).to eq(true) }
      end
    end
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
end
