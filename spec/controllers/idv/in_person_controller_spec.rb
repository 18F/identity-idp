require 'rails_helper'

RSpec.describe Idv::InPersonController do
  let(:in_person_proofing_enabled) { false }
  let(:sp) { nil }
  let(:user) { nil }

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled)
      .and_return(in_person_proofing_enabled)
    allow(controller).to receive(:current_sp).and_return(sp)
    stub_sign_in(user) if user
  end

  describe 'before_actions' do
    it 'includes correct before_actions' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
        :set_usps_form_presenter,
        :redirect_unless_enrollment,
        :initialize_in_person_session,
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
            create(:in_person_enrollment, :establishing, user: user)
          end

          it 'initializes the in-person session' do
            get :index
            expect(controller.user_session['idv/in_person']).to include(
              pii_from_user: { uuid: user.uuid },
            )
          end

          it 'redirects to the first step' do
            get :index

            expect(response).to redirect_to idv_in_person_state_id_path
          end

          it 'has non-nil presenter' do
            get :index
            expect(assigns(:presenter)).to be_kind_of(Idv::InPerson::UspsFormPresenter)
          end

          context 'with associated service provider' do
            let(:sp) { create(:service_provider, in_person_proofing_enabled: false) }

            it 'renders 404 not found' do
              get :index

              expect(response.status).to eq 404
            end

            context 'with in person proofing enabled for service provider' do
              before do
                ServiceProvider.find_by(issuer: sp.issuer)
                  .update(in_person_proofing_enabled: true)
              end

              it 'redirects to the first step' do
                get :index

                expect(response).to redirect_to idv_in_person_state_id_path
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
              put :update

              expect(response).to redirect_to idv_in_person_state_id_path
            end
          end
        end
      end
    end
  end
end
