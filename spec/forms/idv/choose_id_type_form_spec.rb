require 'rails_helper'

RSpec.describe Idv::ChooseIdTypeForm do
  let(:subject) { Idv::ChooseIdTypeForm.new }

  describe '#submit' do
    allowed_id_types =
      Idp::Constants::DocumentTypes::SUPPORTED_PASSPORT_TYPES +
      Idp::Constants::DocumentTypes::SUPPORTED_STATE_ID_TYPES
    allowed_id_types.each do |id_type|
      context "when the choose_id_type_preference is '#{id_type}'" do
        let(:params) { { choose_id_type_preference: id_type } }

        it 'returns a successful form response' do
          result = subject.submit(params)

          expect(result).to be_kind_of(FormResponse)
          expect(result.success?).to eq(true)
          expect(result.errors).to be_empty
        end
      end
    end

    context 'when the choose_id_type_preference is a passport card' do
      let(:params) do
        { choose_id_type_preference: Idp::Constants::DocumentTypes::PASSPORT_CARD }
      end

      context 'when passport cards are enabled' do
        let(:subject) { Idv::ChooseIdTypeForm.new(passport_cards_enabled: true) }

        it 'returns a successful form response' do
          result = subject.submit(params)

          expect(result.success?).to eq(true)
          expect(result.errors).to be_empty
        end
      end

      context 'when passport cards are not enabled' do
        it 'returns a failed form response' do
          result = subject.submit(params)

          expect(result.success?).to eq(false)
          expect(result.errors).not_to be_empty
        end
      end
    end

    context 'when the choose_id_type_preference is nil' do
      let(:params) { { choose_id_type_preference: nil } }

      it 'returns a failed form response when id type is nil' do
        result = subject.submit(params)

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
        expect(result.errors).not_to be_empty
      end
    end

    context 'when the choose_id_type_preference is not supported type' do
      let(:params) { { choose_id_type_preference: 'unknown-type' } }

      it 'returns a failed form response when id type is nil' do
        result = subject.submit(params)

        expect(result).to be_kind_of(FormResponse)
        expect(result.success?).to eq(false)
        expect(result.errors).not_to be_empty
      end
    end
  end
end
