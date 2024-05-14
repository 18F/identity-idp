require 'rails_helper'

RSpec.describe Idv::ByMail::LetterEnqueuedPresenter do
  include Rails.application.routes.url_helpers

  subject(:presenter) do
    described_class.new(
      idv_session: idv_session,
      user_session: user_session,
      url_options: {},
      current_user: current_user,
    )
  end

  let(:idv_session) do
    Idv::Session.new(
      user_session: user_session,
      current_user: current_user,
      service_provider: service_provider,
    )
  end

  let(:current_user) { nil }
  let(:user_session) { {} }
  let(:service_provider) { nil }
  let(:pii) { Idp::Constants::MOCK_IDV_APPLICANT }

  describe '#address_lines' do
    let(:current_user) { create(:user, :with_pending_gpo_profile) }

    shared_examples 'retrieves and formats the address correctly' do
      context 'when the address has no address2' do
        let(:pii) do
          super().merge(
            {
              address1: '123 Some St',
              city: 'Anytown',
              state: 'OK',
              zipcode: '99999',
            },
          )
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

      context 'when the address has an address2' do
        let(:pii) do
          super().merge(
            {
              address1: '456 Cross St',
              address2: 'Apt 3G',
              city: 'Thatville',
              state: 'UT',
              zipcode: '88888',
            },
          )
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

    def add_to_idv_session(pii:)
      idv_session.pii_from_doc = pii
    end

    def add_to_user_session(pii:)
      user_session['idv/in_person'] = { pii_from_user: pii }
    end

    def add_to_gpo_pending_profile(pii:)
      pii_cacher = Pii::Cacher.new(current_user, user_session)
      gpo_profile_id = current_user.gpo_verification_pending_profile.id

      pii_cacher.save_decrypted_pii(pii, gpo_profile_id)
    end

    context 'with the pii in the idv session' do
      before { add_to_idv_session(pii:) }

      include_examples 'retrieves and formats the address correctly'
    end

    context 'with the pii in the user_session' do
      before { add_to_user_session(pii:) }

      include_examples 'retrieves and formats the address correctly'
    end

    context 'with the pii in the gpo pending profile' do
      before { add_to_gpo_pending_profile(pii:) }

      include_examples 'retrieves and formats the address correctly'
    end

    context 'with the pii in the idv session, the user session, and the gpo pending profile' do
      before do
        add_to_idv_session(pii:)
        add_to_user_session(pii: { address1: 'bogus user session pii' })
        add_to_gpo_pending_profile(pii: { address1: 'bogus gpo session pii' })
      end

      include_examples 'retrieves and formats the address correctly'
    end

    context 'with the pii in the user session and the gpo pending profile' do
      before do
        add_to_user_session(pii:)
        add_to_gpo_pending_profile(pii: { address1: 'bogus gpo session pii' })
      end

      include_examples 'retrieves and formats the address correctly'
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
