require 'rails_helper'

RSpec.describe Idv::AddressPresenter do
  let(:gpo_letter_requested) { nil }
  let(:address_update_request) { nil }
  subject(:presenter) { described_class.new(gpo_letter_requested:, address_update_request:) }

  context 'address update request is true' do
    let(:address_update_request) { true }

    it 'gives us the correct page heading' do
      expect(presenter.address_heading).to eq(t('doc_auth.headings.address_update'))
    end

    it 'gives us the correct update button' do
      expect(presenter.update_or_continue_button).to eq(t('forms.buttons.submit.update'))
    end
  end

  context 'address update request is false' do
    let(:address_update_request) { false }

    it 'gives us the correct page heading' do
      expect(presenter.address_heading).to eq(t('doc_auth.headings.address'))
    end

    it 'gives us the correct continue button' do
      expect(presenter.update_or_continue_button).to eq(t('forms.buttons.continue'))
    end
  end

  context 'gpo_letter_requested is true' do
    let(:gpo_letter_requested) { true }
    let(:address_update_request) { false }

    it 'gives us the correct page heading' do
      expect(presenter.address_heading).to eq(t('doc_auth.headings.mailing_address'))
    end

    it 'gives us the correct update button' do
      expect(presenter.update_or_continue_button).to eq(t('forms.buttons.continue'))
    end
  end

  context 'gpo_letter_requested and address_update_request are true' do
    let(:gpo_letter_requested) { true }
    let(:address_update_request) { true }

    it 'gives us the correct page heading' do
      expect(presenter.address_heading).to eq(t('doc_auth.headings.mailing_address'))
    end

    it 'gives us the correct update button' do
      expect(presenter.update_or_continue_button).to eq(t('forms.buttons.continue'))
    end
  end
end
