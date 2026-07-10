require 'rails_helper'

RSpec.describe Idv::HowToVerifyPresenter do
  subject(:presenter) do
    Idv::HowToVerifyPresenter.new(
      selfie_check_required:,
      passport_cards_supported:,
    )
  end

  let(:selfie_check_required) { false }
  let(:passport_cards_supported) { false }

  describe '#verify_online_description' do
    context 'when passport cards are supported' do
      let(:passport_cards_supported) { true }

      it 'mentions the passport card' do
        expect(presenter.verify_online_description)
          .to eq(t('doc_auth.info.verify_online_description_passport_card'))
      end
    end

    context 'when passport cards are not supported' do
      it 'does not mention the passport card' do
        expect(presenter.verify_online_description)
          .to eq(t('doc_auth.info.verify_online_description_passport'))
      end
    end
  end

  describe '#post_office_description' do
    context 'when in person passports are enabled' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_passports_enabled).and_return(true)
      end

      it 'does not mention the passport card' do
        expect(presenter.post_office_description)
          .to eq(t('doc_auth.info.verify_at_post_office_description_passport_book'))
      end

      context 'when passport cards are supported' do
        let(:passport_cards_supported) { true }

        it 'still does not mention the passport card' do
          expect(presenter.post_office_description)
            .to_not include('card')
        end
      end
    end

    context 'when in person passports are disabled' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_passports_enabled).and_return(false)
      end

      it 'returns the passport not accepted copy' do
        expect(presenter.post_office_description)
          .to eq(t('doc_auth.info.verify_at_post_office_description_passport_html'))
      end
    end
  end

  describe '#verify_online_instruction' do
    context 'when a selfie is required' do
      let(:selfie_check_required) { true }

      it 'returns the selfie instruction' do
        expect(presenter.verify_online_instruction)
          .to eq(t('doc_auth.info.verify_online_instruction_selfie'))
      end
    end

    context 'when a selfie is not required' do
      it 'returns the standard instruction' do
        expect(presenter.verify_online_instruction)
          .to eq(t('doc_auth.info.verify_online_instruction'))
      end
    end
  end
end
