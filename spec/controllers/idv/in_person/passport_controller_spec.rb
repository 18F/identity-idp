require 'rails_helper'

RSpec.describe Idv::InPerson::PassportController do
  include FlowPolicyHelper

  let(:user) { create(:user) }
  let(:idv_session) { subject.idv_session }
  let(:enrollment) { InPersonEnrollment.new }

  before do
    stub_sign_in(user)
    stub_up_to(:hybrid_handoff, idv_session: subject.idv_session)
    stub_analytics
  end

  describe 'before_actions' do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_passports_enable).and_return(true)
      allow(IdentityConfig.store).to receive(:in_person_passports_enabled).and_return(true)
    end

    it 'includes before_action' do
      expect(subject).to have_actions(:before, :render_404_if_controller_not_enabled)
      expect(subject).to have_actions(:before, :initialize_pii_from_user)
    end
  end

  describe '#show' do
    context 'when passports are not allowed' do
      before do
        allow(IdentityConfig.store).to receive(:doc_auth_passports_enable).and_return(false)
      end

      context 'when in person passports are not allowed' do
        it 'does not log the idv_in_person_proofing_passport_visited event' do
          expect(@analytics).to_not have_logged_event(
            :idv_in_person_proofing_passport_visited,
          )
        end
      end

      context 'when in person passports are allowed' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_passports_enabled).and_return(true)
        end

        it 'does not log the idv_in_person_proofing_passport_visited event' do
          expect(@analytics).to_not have_logged_event(
            :idv_in_person_proofing_passport_visited,
          )
        end
      end
    end

    context 'when passports are allowed' do
      before do
        allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled).and_return(true)
      end

      context 'when in person passports are not allowed' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_passports_enabled).and_return(false)
        end

        it 'does not log the idv_in_person_proofing_passport_visited event' do
          expect(@analytics).to_not have_logged_event(:idv_in_person_proofing_passport_visited)
        end
      end

      context 'when in person passports are allowed' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_passports_enabled).and_return(true)
        end

        let(:analytics_arguments) do
          {
            step: 'passport',
            analytics_id: 'In Person Proofing',
            skip_hybrid_handoff: false,
          }
        end

        before do
          subject.idv_session.opted_in_to_in_person_proofing =
            analytics_arguments[:opted_in_to_in_person_proofing]
          subject.idv_session.skip_hybrid_handoff = analytics_arguments[:skip_hybrid_handoff]
          get :show
        end

        it 'renders the passport form' do
          expect(response).to render_template 'idv/in_person/passport/show'
        end

        it 'logs the idv_in_person_proofing_passport_visited event' do
          expect(@analytics).to have_logged_event(
            :idv_in_person_proofing_passport_visited,
            analytics_arguments,
          )
        end
      end
    end
  end
end
