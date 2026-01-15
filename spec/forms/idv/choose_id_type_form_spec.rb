require 'rails_helper'

RSpec.describe Idv::ChooseIdTypeForm do
  let(:subject) { Idv::ChooseIdTypeForm.new }

  describe '#submit' do
    Idp::Constants::DocumentTypes::SUPPORTED_ID_TYPES.each do |id_type|
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

    context 'when the choose_id_type_preference is mdl' do
      let(:params) { { choose_id_type_preference: Idp::Constants::DocumentTypes::MDL } }

      context 'when mdl_verification_enabled is true' do
        before do
          allow(IdentityConfig.store).to receive(:mdl_verification_enabled).and_return(true)
        end

        it 'returns a successful form response' do
          result = subject.submit(params)

          expect(result).to be_kind_of(FormResponse)
          expect(result.success?).to eq(true)
          expect(result.errors).to be_empty
        end
      end

      context 'when mdl_verification_enabled is false' do
        before do
          allow(IdentityConfig.store).to receive(:mdl_verification_enabled).and_return(false)
        end

        it 'returns a failed form response' do
          result = subject.submit(params)

          expect(result).to be_kind_of(FormResponse)
          expect(result.success?).to eq(false)
          expect(result.errors).not_to be_empty
        end
      end
    end
  end
end
