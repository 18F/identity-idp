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
  let(:expected_pii) { Idp::Constants::MOCK_IDV_APPLICANT }

  describe '#address_lines' do
    let(:current_user) { create(:user, :with_pending_gpo_profile) }

    shared_examples 'retrieves and formats the address correctly' do
      context 'when the address has no address2' do
        let(:pii) do
          expected_pii.merge(
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
          expected_pii.merge(
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

    def add_to_idv_session_applicant(pii:)
      pii_hash = Pii::StateId.members.index_with(nil).merge(pii)

      idv_session.applicant = pii_hash
    end

    def add_to_gpo_pending_profile(pii:)
      pii_cacher = Pii::Cacher.new(current_user, user_session)
      gpo_profile_id = current_user.gpo_verification_pending_profile.id

      pii_cacher.save_decrypted_pii(pii, gpo_profile_id)
    end

    context 'with the pii on the applicant in the idv session' do
      before { add_to_idv_session_applicant(pii:) }

      include_examples 'retrieves and formats the address correctly'
    end

    context 'with pii on the applicant and different pii in the GPO pending profile' do
      let(:pii) { expected_pii }
      let(:wrong_pii) { Pii::StateId.members.index_with('wrong') }

      before do
        add_to_idv_session_applicant(pii:)
        add_to_gpo_pending_profile(pii: wrong_pii)
      end

      include_examples 'retrieves and formats the address correctly'
    end

    context 'with the pii in the gpo pending profile' do
      before { add_to_gpo_pending_profile(pii:) }

      include_examples 'retrieves and formats the address correctly'
    end
  end

  describe '#button_destination' do
    context 'when there is no SP' do
      it 'is a redirect to the marketing page' do
        expect(presenter.button_destination).to eq(marketing_site_redirect_path)
      end
    end

    context 'when there is an SP' do
      let(:service_provider) { double('service provider') }

      it 'is a return to SP button' do
        expect(presenter.button_destination).to eq(
          return_to_sp_cancel_path(step: :verify_address, location: :come_back_later),
        )
      end
    end
  end
end
