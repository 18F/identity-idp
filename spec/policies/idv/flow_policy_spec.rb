require 'rails_helper'

RSpec.describe 'Idv::FlowPolicy' do
  include Rails.application.routes.url_helpers

  let(:user) { create(:user) }

  let(:idv_session) do
    Idv::Session.new(
      user_session: {},
      current_user: user,
      service_provider: nil,
    )
  end

  let(:user_phone_confirmation_session) { nil }
  let(:has_gpo_pending_profile) { nil }

  subject { Idv::FlowPolicy.new(idv_session: idv_session, user: user) }

  context '#step_allowed?' do
    it 'allows the welcome step' do
      expect(subject.step_allowed?(step: :welcome)).to be true
    end
  end

  context 'each step in the flow' do
    before do
      allow(Idv::PhoneConfirmationSession).to receive(:from_h).
        with(user_phone_confirmation_session).and_return(user_phone_confirmation_session)
      allow(user).to receive(:gpo_pending_profile?).and_return(has_gpo_pending_profile)
    end
    context 'empty session' do
      it 'returns welcome' do
        expect(subject.latest_step).to eq(:welcome)
        expect(subject.path_for_latest_step).to eq(idv_welcome_path)
      end
    end

    context 'preconditions for agreement are present' do
      it 'returns agreement' do
        idv_session.welcome_visited = true
        expect(subject.latest_step).to eq(:agreement)
        expect(subject.path_allowed?(path: idv_agreement_path)).to be
        expect(subject.path_allowed?(path: idv_hybrid_handoff_path)).not_to be
        expect(subject.path_for_latest_step).to eq(idv_agreement_path)
      end
    end

    context 'preconditions for hybrid_handoff are present' do
      it 'returns hybrid_handoff' do
        idv_session.welcome_visited = true
        idv_session.idv_consent_given = true
        expect(subject.latest_step).to eq(:hybrid_handoff)
        expect(subject.path_allowed?(path: idv_hybrid_handoff_path)).to be
        expect(subject.path_allowed?(path: idv_document_capture_path)).not_to be
        expect(subject.path_for_latest_step).to eq(idv_hybrid_handoff_path)
      end
    end

    context 'preconditions for document_capture are present' do
      it 'returns document_capture' do
        idv_session.welcome_visited = true
        idv_session.idv_consent_given = true
        idv_session.flow_path = 'standard'
        expect(subject.latest_step).to eq(:document_capture)
        expect(subject.path_allowed?(path: idv_document_capture_path)).to be
        expect(subject.path_allowed?(path: idv_ssn_path)).not_to be
        expect(subject.path_for_latest_step).to eq(idv_document_capture_path)
      end
    end

    context 'preconditions for link_sent are present' do
      it 'returns link_sent' do
        idv_session.welcome_visited = true
        idv_session.idv_consent_given = true
        idv_session.flow_path = 'hybrid'
        expect(subject.latest_step).to eq(:link_sent)
        expect(subject.path_allowed?(path: idv_link_sent_path)).to be
        expect(subject.path_allowed?(path: idv_ssn_path)).not_to be
        expect(subject.path_for_latest_step).to eq(idv_link_sent_path)
      end
    end

    context 'preconditions for ssn are present' do
      before do
        idv_session.welcome_visited = true
        idv_session.idv_consent_given = true
        idv_session.flow_path = 'standard'
        idv_session.pii_from_doc = { pii: 'value' }
      end

      it 'returns ssn for standard flow' do
        expect(subject.latest_step).to eq(:ssn)
        expect(subject.path_allowed?(path: idv_ssn_path)).to be
        expect(subject.path_allowed?(path: idv_verify_info_path)).not_to be
        expect(subject.path_for_latest_step).to eq(idv_ssn_path)
      end

      it 'returns ssn for hybrid flow' do
        idv_session.flow_path = 'hybrid'
        expect(subject.latest_step).to eq(:ssn)
        expect(subject.path_allowed?(path: idv_ssn_path)).to be
        expect(subject.path_allowed?(path: idv_verify_info_path)).not_to be
        expect(subject.path_for_latest_step).to eq(idv_ssn_path)
      end
    end

    context 'preconditions for verify_info are present' do
      it 'returns verify_info' do
        idv_session.welcome_visited = true
        idv_session.idv_consent_given = true
        idv_session.flow_path = 'standard'
        idv_session.pii_from_doc = { pii: 'value' }
        idv_session.ssn = '666666666'

        expect(subject.latest_step).to eq(:verify_info)
        expect(subject.path_allowed?(path: idv_verify_info_path)).to be
        expect(subject.path_allowed?(path: idv_phone_path)).not_to be
        expect(subject.path_for_latest_step).to eq(idv_verify_info_path)
      end
    end

    context 'preconditions for phone are present' do
      it 'returns phone' do
        idv_session.welcome_visited = true
        idv_session.idv_consent_given = true
        idv_session.flow_path = 'standard'
        idv_session.applicant = { pii: 'value' }
        idv_session.ssn = '666666666'
        idv_session.resolution_successful = true

        expect(subject.latest_step).to eq(:phone)
        expect(subject.path_allowed?(path: idv_phone_path)).to be
        expect(subject.path_allowed?(path: idv_otp_verification_path)).not_to be
        expect(subject.path_for_latest_step).to eq(idv_phone_path)
      end
    end

    context 'preconditions for phone_enter_otp are present' do
      let(:user_phone_confirmation_session) { { code: 'abcde' } }

      it 'returns phone_enter_otp' do
        idv_session.welcome_visited = true
        idv_session.idv_consent_given = true
        idv_session.flow_path = 'standard'
        idv_session.applicant = { pii: 'value' }
        idv_session.ssn = '666666666'
        idv_session.resolution_successful = true
        idv_session.user_phone_confirmation_session = user_phone_confirmation_session

        expect(subject.latest_step).to eq(:phone_enter_otp)
        expect(subject.path_allowed?(path: idv_otp_verification_path)).to be
        expect(subject.path_allowed?(path: idv_review_path)).not_to be
        expect(subject.path_for_latest_step).to eq(idv_otp_verification_path)
      end
    end

    context 'preconditions for review are present' do
      let(:user_phone_confirmation_session) { { code: 'abcde' } }

      context 'user has a gpo address_verification_mechanism' do
        it 'returns review with gpo verification pending' do
          idv_session.welcome_visited = true
          idv_session.idv_consent_given = true
          idv_session.flow_path = 'standard'
          idv_session.applicant = { pii: 'value' }
          idv_session.ssn = '666666666'
          idv_session.resolution_successful = true
          idv_session.user_phone_confirmation_session = user_phone_confirmation_session
          idv_session.address_verification_mechanism = 'gpo'

          expect(subject.latest_step).to eq(:review)
          expect(subject.path_allowed?(path: idv_review_path)).to be
          expect(subject.path_allowed?(path: idv_personal_key_path)).not_to be
          expect(subject.path_for_latest_step).to eq(idv_review_path)
        end
      end

      context 'user passed phone step' do
        it 'returns review' do
          idv_session.welcome_visited = true
          idv_session.idv_consent_given = true
          idv_session.flow_path = 'standard'
          idv_session.applicant = { pii: 'value' }
          idv_session.ssn = '666666666'
          idv_session.resolution_successful = true
          idv_session.user_phone_confirmation_session = user_phone_confirmation_session
          idv_session.vendor_phone_confirmation = true
          idv_session.user_phone_confirmation = true

          expect(subject.latest_step).to eq(:review)
          expect(subject.path_allowed?(path: idv_review_path)).to be
          expect(subject.path_allowed?(path: idv_personal_key_path)).not_to be
          expect(subject.path_for_latest_step).to eq(idv_review_path)
        end
      end
    end

    it 'returns nil for an invalid step' do
      expect(subject.latest_step(current_step: :invalid_step)).to be_nil
    end
  end
end
