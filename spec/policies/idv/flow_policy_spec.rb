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

  context '#controller_allowed?' do
    it 'allows the welcome step' do
      expect(subject.controller_allowed?(controller: Idv::WelcomeController)).to be true
    end
  end

  context '#undo_steps_from!' do
    it 'does not undo any steps if success' do
      expect { subject.undo_steps_from!(step: :success) }.not_to change { idv_session }
    end

    context 'user is on document_capture step' do
      before do
        idv_session.welcome_visited = true
        idv_session.idv_consent_given = true
        idv_session.flow_path = 'standard'
      end

      it 'user goes back and submits welcome' do
        subject.undo_steps_from!(step: :welcome)

        expect(idv_session.welcome_visited).to be_nil
        expect(idv_session.idv_consent_given).to be_nil
        expect(idv_session.flow_path).to be_nil
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
        # expect(subject.controller_allowed?(controller: Idv::SsnController)).not_to be
      end
    end

    context 'preconditions for link_sent are present' do
      it 'returns link_sent' do
        idv_session.welcome_visited = true
        idv_session.idv_consent_given = true
        idv_session.flow_path = 'hybrid'
        expect(subject.info_for_latest_step.key).to eq(:link_sent)
        expect(subject.controller_allowed?(controller: Idv::LinkSentController)).to be
        # expect(subject.controller_allowed?(controller: Idv::SsnController)).not_to be
      end
    end
  end
end
