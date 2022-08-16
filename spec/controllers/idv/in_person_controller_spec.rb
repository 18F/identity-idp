require 'rails_helper'

describe Idv::InPersonController do
  let(:in_person_proofing_enabled) { false }
  let(:in_person_proofing_enabled_issuers) { [] }
  let(:sp) { nil }
  let(:user) { nil }

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).
      and_return(in_person_proofing_enabled)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled_issuers).
      and_return(in_person_proofing_enabled_issuers)
    allow(controller).to receive(:current_sp).and_return(sp)
    stub_sign_in(user) if user
  end

  describe 'before_actions' do
    it 'includes corrects before_actions' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :fsm_initialize,
        :ensure_correct_step,
      )
    end
  end

  describe '#index' do
    it 'renders 404 not found' do
      get :index

      expect(response.status).to eq 404
    end

    context 'with in person proofing enabled' do
      let(:in_person_proofing_enabled) { true }

      it 'redirects to the root url' do
        get :index

        expect(response).to redirect_to root_url
      end

      context 'signed in' do
        let(:user) { build(:user) }

        it 'redirects to idv' do
          get :index

          expect(response).to redirect_to idv_url
        end

        context 'with establishing in-person enrollment' do
          before do
            create(:in_person_enrollment, :establishing, user: user, profile: nil)
          end

          it 'redirects to the first step' do
            get :index

            expect(response).to redirect_to idv_in_person_step_url(step: :state_id)
          end

          context 'with associated service provider' do
            let(:sp) { build(:service_provider) }

            it 'renders 404 not found' do
              get :index

              expect(response.status).to eq 404
            end

            context 'with in person proofing enabled for service provider' do
              let(:in_person_proofing_enabled_issuers) { [sp.issuer] }

              it 'redirects to the first step' do
                get :index

                expect(response).to redirect_to idv_in_person_step_url(step: :state_id)
              end
            end
          end

          context 'with an existing applicant' do
            before do
              idv_session = Idv::Session.new(
                user_session: controller.user_session,
                current_user: user,
                service_provider: nil,
              )
              idv_session.applicant = {}
              allow(controller).to receive(:idv_session).and_return(idv_session)
            end

            it 'finishes the flow' do
              put :update, params: { step: 'state_id' }

              expect(response).to redirect_to idv_phone_url
            end
          end
        end
      end
    end
  end
end
