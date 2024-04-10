require 'rails_helper'

RSpec.describe Idv::ByMail::LetterEnqueuedPresenter do
  include Rails.application.routes.url_helpers

  subject(:presenter) do
    described_class.new(
      idv_session,
      user_session: {},
      url_options: {},
      current_user: nil,
    )
  end

  let(:idv_session) do
    Idv::Session.new(
      user_session: {},
      current_user: nil,
      service_provider: service_provider,
    )
  end

  let(:service_provider) { nil }
  let(:pii) { nil }

  before do
    idv_session.pii_from_doc = pii
  end

  describe '#address_lines' do
    context 'when address2 is not present' do
      let(:pii) do
        {
          address1: '123 Some St',
          city: 'Anytown',
          state: 'OK',
          zipcode: '99999',
        }
      end

      it 'shows a 2 line address' do
        expect(presenter.address_lines).to eq(
          [
            '123 Some St',
            'Anytown, OK 99999',
          ],
        )
      end
    end

    context 'when address2 is present' do
      let(:pii) do
        {
          address1: '456 Cross St',
          address2: 'Apt 3G',
          city: 'Thatville',
          state: 'UT',
          zipcode: '88888',
        }
      end

      it 'shows a 3 line address' do
        expect(presenter.address_lines).to eq(
          [
            '456 Cross St',
            'Apt 3G',
            'Thatville, UT 88888',
          ],
        )
      end
    end
  end

  describe '#button_text' do
    context 'when there is no SP' do
      it 'is a plain Continue button' do
        expect(presenter.button_text).to eq(t('idv.buttons.continue_plain'))
      end
    end

    context 'when there is an SP' do
      let(:service_provider) { double('service provider') }

      it 'is an Exit button' do
        expect(presenter.button_text).to eq(t('idv.cancel.actions.exit', app_name: APP_NAME))
      end
    end
  end

  describe '#button_destination' do
    context 'when there is no SP' do
      it 'is the account page' do
        expect(presenter.button_destination).to eq(account_path)
      end
    end

    context 'when there is an SP' do
      let(:service_provider) { double('service provider') }

      it 'is a return to SP button' do
        expect(presenter.button_destination).to eq(
          return_to_sp_cancel_path(step: :get_a_letter, location: :come_back_later),
        )
      end
    end
  end
end
