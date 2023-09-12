require 'rails_helper'

RSpec.describe 'Idv::AllowedStep' do
  let(:user) { create(:user) }

  let(:idv_session) do
    Idv::Session.new(
      user_session: {},
      current_user: user,
      service_provider: nil,
    )
  end

  subject { Idv::AllowedStep.new(idv_session: idv_session) }

  context '#step_allowed?' do
    it 'allows the welcome step' do
      expect(subject.step_allowed?(step: :welcome)).to be true
    end
  end

  context '#latest_step' do
    it 'returns welcome for empty session' do
      expect(subject.latest_step).to eq(:welcome)
    end

    context 'preconditions for document_capture are present' do
      it 'returns document_capture for empty session' do
        idv_session.welcome_visited = true
        idv_session.idv_consent_given = true
        idv_session.flow_path = 'standard'
        expect(subject.latest_step).to eq(:document_capture)
      end
    end

    it 'returns nil for an invalid step' do
      expect(subject.latest_step(current_step: :invalid_step)).to be_nil
    end
  end
end
