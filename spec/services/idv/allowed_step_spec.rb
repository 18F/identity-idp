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

  subject { Idv::AllowedStep.new(idv_session: idv_session, user: user) }

  context '#step_allowed?' do
    it 'allows the welcome step' do
      expect(subject.step_allowed?(step: :welcome)).to be true
    end

    context 'a/b test' do
      before do
        allow(AbTests::IDV_GETTING_STARTED).to receive(:bucket).and_return(:getting_started)
      end

      it 'allows the getting started step' do
        expect(subject.step_allowed?(step: :welcome)).to be false
        expect(subject.step_allowed?(step: :getting_started)).to be true
      end
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

    # it 'works' do
    #   # go to hybrid handoff
    #   expect(check_steps).to eq 'yNyyNNNNNN'
    # end
  end

  # def check_steps
  #   [
  #     allowed_step?(:welcome) ? y : N,
  #     allowed_step?(:document_capture)? y : N,
  #     allowed_step?(:agreement) ? y : N,
  #     allowed_step?(:hybrid_handoff) ? y : N,
  #   ].join('')
  # end
end
