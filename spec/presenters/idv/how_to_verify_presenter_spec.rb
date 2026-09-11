require 'rails_helper'

RSpec.describe Idv::HowToVerifyPresenter do
  subject(:presenter) do
    Idv::HowToVerifyPresenter.new(
      selfie_check_required:,
      passport_cards_supported:,
      mdl_enabled:,
      clear1_enabled:,
    )
  end

  let(:selfie_check_required) { false }
  let(:passport_cards_supported) { false }
  let(:mdl_enabled) { false }
  let(:clear1_enabled) { false }

  describe '#clear1_enabled?' do
    it 'is false by default' do
      expect(presenter.clear1_enabled?).to eq(false)
    end

    context 'when clear1 is enabled' do
      let(:clear1_enabled) { true }

      it 'is true' do
        expect(presenter.clear1_enabled?).to eq(true)
      end
    end
  end

  describe 'clear1 copy' do
    it 'returns the designed heading, description, link text and button text' do
      expect(presenter.verify_with_existing_account_text)
        .to eq(t('doc_auth.headings.verify_with_existing_account'))
      expect(presenter.clear1_description).to eq(t('doc_auth.info.verify_with_clear1'))
      expect(presenter.clear1_link_text).to eq(t('doc_auth.info.verify_with_clear1_link_text'))
      expect(presenter.clear1_submit).to eq(t('forms.buttons.verify_with_clear1'))
    end
  end

  describe '#verify_online_description' do
    context 'when passport cards are supported' do
      let(:passport_cards_supported) { true }

      it 'mentions the passport card' do
        expect(presenter.verify_online_description)
          .to eq(t('doc_auth.info.verify_online_description_passport_card'))
      end

      context 'when passport cards are supported and mdl enabled' do
        let(:mdl_enabled) { true }

        it 'mentions the passport card and mdl' do
          expect(presenter.verify_online_description)
            .to eq(t('doc_auth.info.verify_online_description_mdl_and_passport_card'))
        end
      end
    end

    context 'when passport cards are not supported' do
      it 'does not mention the passport card' do
        expect(presenter.verify_online_description)
          .to eq(t('doc_auth.info.verify_online_description'))
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
          .to eq(t('doc_auth.info.verify_online_description'))
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
