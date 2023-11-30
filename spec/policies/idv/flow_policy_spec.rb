require 'rails_helper'

RSpec.describe 'Idv::FlowPolicy' do
  include Rails.application.routes.url_helpers

  let(:user) { create(:user) }

  let(:user_session) { { 'idv/in_person' => {} } }

  let(:idv_session) do
    Idv::Session.new(
      user_session: user_session,
      current_user: user,
      service_provider: nil,
    )
  end

  let(:user_phone_confirmation_session) { nil }
  let(:has_gpo_pending_profile) { nil }

  subject { Idv::FlowPolicy.new(idv_session: idv_session, user: user) }

  context '#controller_allowed?' do
    it 'allows the welcome step' do
      expect(subject.controller_allowed?(controller: Idv::WelcomeController)).to be true
    end
  end

  context '#undo_future_steps_from_controller!' do
    context 'user is on verify_info step' do
      before do
        idv_session.welcome_visited = true
        idv_session.document_capture_session_uuid = SecureRandom.uuid

        idv_session.idv_consent_given = true
        idv_session.skip_hybrid_handoff = true

        idv_session.flow_path = 'standard'
        idv_session.phone_for_mobile_flow = '201-555-1212'

        idv_session.pii_from_doc = Idp::Constants::MOCK_IDV_APPLICANT
        idv_session.had_barcode_read_failure = true
        idv_session.had_barcode_attention_error = true

        idv_session.ssn = Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn]
        idv_session.threatmetrix_session_id = SecureRandom.uuid

        idv_session.address_edited = true
      end

      it 'clears future steps when user goes back and submits welcome' do
        subject.undo_future_steps_from_controller!(controller: Idv::WelcomeController)

        expect(idv_session.welcome_visited).not_to be_nil
        expect(idv_session.document_capture_session_uuid).not_to be_nil

        expect(idv_session.idv_consent_given).to be_nil
        expect(idv_session.skip_hybrid_handoff).to be_nil

        expect(idv_session.flow_path).to be_nil
        expect(idv_session.phone_for_mobile_flow).to be_nil

        expect(idv_session.pii_from_doc).to be_nil
        expect(idv_session.had_barcode_read_failure).to be_nil
        expect(idv_session.had_barcode_attention_error).to be_nil

        expect(idv_session.ssn).to be_nil
        expect(idv_session.threatmetrix_session_id).to be_nil

        expect(idv_session.address_edited).to be_nil
      end
    end

    context 'user is on enter password step' do
      before do
        idv_session.welcome_visited = true
        idv_session.document_capture_session_uuid = SecureRandom.uuid

        idv_session.idv_consent_given = true
        idv_session.skip_hybrid_handoff = true

        idv_session.flow_path = 'standard'
        idv_session.phone_for_mobile_flow = '201-555-1212'

        idv_session.pii_from_doc = nil
        idv_session.had_barcode_read_failure = true
        idv_session.had_barcode_attention_error = true

        idv_session.ssn = nil
        idv_session.threatmetrix_session_id = SecureRandom.uuid

        idv_session.address_edited = true

        idv_session.verify_info_step_document_capture_session_uuid = SecureRandom.uuid
        idv_session.threatmetrix_review_status = 'pass'
        idv_session.resolution_successful = true
        idv_session.applicant = Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN.dup

        idv_session.vendor_phone_confirmation = true
        idv_session.address_verification_mechanism = 'phone'
        idv_session.idv_phone_step_document_capture_session_uuid = SecureRandom.uuid
        idv_session.user_phone_confirmation_session = { phone: '201-555-1212' }
        idv_session.previous_phone_step_params = '201-555-1111'

        idv_session.user_phone_confirmation = true
      end

      it 'does clear steps after ssn when user submits ssn' do
        subject.undo_future_steps_from_controller!(controller: Idv::SsnController)

        expect(idv_session.address_edited).to be_nil

        expect(idv_session.verify_info_step_document_capture_session_uuid).to be_nil
        expect(idv_session.threatmetrix_review_status).to be_nil
        expect(idv_session.resolution_successful).to be_nil
        expect(idv_session.applicant).to be_nil

        expect(idv_session.vendor_phone_confirmation).to be_nil
        expect(idv_session.address_verification_mechanism).to be_nil
        expect(idv_session.idv_phone_step_document_capture_session_uuid).to be_nil
        expect(idv_session.user_phone_confirmation_session).to be_nil
        expect(idv_session.previous_phone_step_params).to be_nil

        expect(idv_session.user_phone_confirmation).to be_nil
      end

      it 'does not clear earlier steps when user goes back and submits ssn' do
        expect do
          subject.undo_future_steps_from_controller!(controller: Idv::SsnController)
        end.not_to change {
          idv_session.welcome_visited
          idv_session.document_capture_session_uuid
          idv_session.idv_consent_given
          idv_session.skip_hybrid_handoff

          idv_session.flow_path
          idv_session.phone_for_mobile_flow

          idv_session.had_barcode_read_failure
          idv_session.had_barcode_attention_error

          idv_session.threatmetrix_session_id
        }
      end
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
        expect(subject.info_for_latest_step.key).to eq(:welcome)
      end
    end

    context 'preconditions for agreement are present' do
      it 'returns agreement' do
        idv_session.welcome_visited = true
        expect(subject.info_for_latest_step.key).to eq(:agreement)
        expect(subject.controller_allowed?(controller: Idv::AgreementController)).to be
        expect(subject.controller_allowed?(controller: Idv::HybridHandoffController)).not_to be
      end
    end

    context 'preconditions for hybrid_handoff are present' do
      it 'returns hybrid_handoff' do
        idv_session.welcome_visited = true
        idv_session.idv_consent_given = true
        expect(subject.info_for_latest_step.key).to eq(:hybrid_handoff)
        expect(subject.controller_allowed?(controller: Idv::HybridHandoffController)).to be
        expect(subject.controller_allowed?(controller: Idv::DocumentCaptureController)).not_to be
      end
    end

    context 'preconditions for document_capture are present' do
      it 'returns document_capture' do
        idv_session.welcome_visited = true
        idv_session.idv_consent_given = true
        idv_session.flow_path = 'standard'
        expect(subject.info_for_latest_step.key).to eq(:document_capture)
        expect(subject.controller_allowed?(controller: Idv::DocumentCaptureController)).to be
        expect(subject.controller_allowed?(controller: Idv::SsnController)).not_to be
      end
    end

    context 'preconditions for link_sent are present' do
      it 'returns link_sent' do
        idv_session.welcome_visited = true
        idv_session.idv_consent_given = true
        idv_session.flow_path = 'hybrid'
        expect(subject.info_for_latest_step.key).to eq(:link_sent)
        expect(subject.controller_allowed?(controller: Idv::LinkSentController)).to be
        expect(subject.controller_allowed?(controller: Idv::SsnController)).not_to be
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
        expect(subject.info_for_latest_step.key).to eq(:ssn)
        expect(subject.controller_allowed?(controller: Idv::SsnController)).to be
        expect(subject.controller_allowed?(controller: Idv::VerifyInfoController)).not_to be
      end

      it 'returns ssn for hybrid flow' do
        idv_session.flow_path = 'hybrid'
        expect(subject.info_for_latest_step.key).to eq(:ssn)
        expect(subject.controller_allowed?(controller: Idv::SsnController)).to be
        expect(subject.controller_allowed?(controller: Idv::VerifyInfoController)).not_to be
      end
    end

    context 'preconditions for in_person ssn are present' do
      before do
        idv_session.welcome_visited = true
        idv_session.idv_consent_given = true
        idv_session.flow_path = 'standard'
        idv_session.send(:user_session)['idv/in_person'][:pii_from_user] = { pii: 'value' }
      end

      it 'returns ipp_ssn' do
        expect(subject.info_for_latest_step.key).to eq(:ipp_ssn)
        expect(subject.controller_allowed?(controller: Idv::InPerson::SsnController)).to be
        expect(subject.controller_allowed?(controller: Idv::InPerson::VerifyInfoController)).
          not_to be
      end
    end

    context 'preconditions for verify_info are present' do
      it 'returns verify_info' do
        idv_session.welcome_visited = true
        idv_session.idv_consent_given = true
        idv_session.flow_path = 'standard'
        idv_session.pii_from_doc = { pii: 'value' }
        idv_session.ssn = '666666666'

        expect(subject.info_for_latest_step.key).to eq(:verify_info)
        expect(subject.controller_allowed?(controller: Idv::VerifyInfoController)).to be
        expect(subject.controller_allowed?(controller: Idv::PhoneController)).not_to be
      end
    end

    context 'preconditions for in_person verify_info are present' do
      it 'returns ipp_verify_info' do
        idv_session.welcome_visited = true
        idv_session.idv_consent_given = true
        idv_session.flow_path = 'standard'
        idv_session.send(:user_session)['idv/in_person'][:pii_from_user] = { pii: 'value' }
        idv_session.ssn = '666666666'

        expect(subject.info_for_latest_step.key).to eq(:ipp_verify_info)
        expect(subject.controller_allowed?(controller: Idv::InPerson::VerifyInfoController)).to be
        expect(subject.controller_allowed?(controller: Idv::PhoneController)).not_to be
      end
    end

    context 'preconditions for phone are present' do
      it 'returns phone' do
        idv_session.welcome_visited = true
        idv_session.idv_consent_given = true
        idv_session.flow_path = 'standard'
        idv_session.pii_from_doc = { pii: 'value' }
        idv_session.applicant = { pii: 'value' }
        idv_session.ssn = '666666666'
        idv_session.resolution_successful = true

        expect(subject.info_for_latest_step.key).to eq(:phone)
        expect(subject.controller_allowed?(controller: Idv::PhoneController)).to be
        expect(subject.controller_allowed?(controller: Idv::OtpVerificationController)).not_to be
      end
    end

    context 'preconditions for otp_verification are present' do
      let(:user_phone_confirmation_session) { { code: 'abcde' } }

      it 'returns otp_verification' do
        idv_session.welcome_visited = true
        idv_session.idv_consent_given = true
        idv_session.flow_path = 'standard'
        idv_session.pii_from_doc = { pii: 'value' }
        idv_session.applicant = { pii: 'value' }
        idv_session.ssn = '666666666'
        idv_session.resolution_successful = true
        idv_session.user_phone_confirmation_session = user_phone_confirmation_session

        expect(subject.info_for_latest_step.key).to eq(:otp_verification)
        expect(subject.controller_allowed?(controller: Idv::OtpVerificationController)).to be
        expect(subject.controller_allowed?(controller: Idv::EnterPasswordController)).not_to be
      end
    end

    context 'preconditions for request_letter are present' do
      it 'returns enter_password with gpo verification pending' do
        idv_session.welcome_visited = true
        idv_session.idv_consent_given = true
        idv_session.flow_path = 'standard'
        idv_session.pii_from_doc = { pii: 'value' }
        idv_session.applicant = { pii: 'value' }
        idv_session.ssn = '666666666'
        idv_session.resolution_successful = true

        expect(subject.controller_allowed?(controller: Idv::ByMail::RequestLetterController)).to be
        expect(subject.controller_allowed?(controller: Idv::EnterPasswordController)).not_to be
      end
    end

    context 'preconditions for enter_password are present' do
      let(:user_phone_confirmation_session) { { code: 'abcde' } }

      context 'user has a gpo address_verification_mechanism' do
        it 'returns enter_password with gpo verification pending' do
          idv_session.welcome_visited = true
          idv_session.idv_consent_given = true
          idv_session.flow_path = 'standard'
          idv_session.pii_from_doc = { pii: 'value' }
          idv_session.applicant = { pii: 'value' }
          idv_session.ssn = '666666666'
          idv_session.resolution_successful = true
          idv_session.user_phone_confirmation_session = user_phone_confirmation_session
          idv_session.address_verification_mechanism = 'gpo'

          expect(subject.info_for_latest_step.key).to eq(:enter_password)
          expect(subject.controller_allowed?(controller: Idv::EnterPasswordController)).to be
          # expect(subject.controller_allowed?(controller: Idv::PersonalKeyController)).not_to be
        end
      end

      context 'user passed phone step' do
        it 'returns enter_password' do
          idv_session.welcome_visited = true
          idv_session.idv_consent_given = true
          idv_session.flow_path = 'standard'
          idv_session.pii_from_doc = { pii: 'value' }
          idv_session.applicant = { pii: 'value' }
          idv_session.ssn = '666666666'
          idv_session.resolution_successful = true
          idv_session.user_phone_confirmation_session = user_phone_confirmation_session
          idv_session.vendor_phone_confirmation = true
          idv_session.user_phone_confirmation = true

          expect(subject.info_for_latest_step.key).to eq(:enter_password)
          expect(subject.controller_allowed?(controller: Idv::EnterPasswordController)).to be
          # expect(subject.controller_allowed?(controller: Idv::PersonalKeyController)).not_to be
        end
      end
    end
  end
end
