require 'rails_helper'

describe VerifyController do
  describe '#show' do
    let(:idv_api_enabled_steps) { [] }
    let(:password) { 'sekrit phrase' }
    let(:user) { create(:user, :signed_up, password: password) }
    let(:applicant) do
      {
        first_name: 'Some',
        last_name: 'One',
        address1: '123 Any St',
        address2: 'Ste 456',
        city: 'Anywhere',
        state: 'KS',
        zipcode: '66666',
      }
    end
    let(:profile) { subject.idv_session.profile }
    let(:step) { '' }

    subject(:response) { get :show, params: { step: step } }

    before do
      allow(IdentityConfig.store).to receive(:idv_api_enabled_steps).
        and_return(idv_api_enabled_steps)
      stub_sign_in(user)
      stub_idv_session
    end

    it 'renders 404' do
      expect(response).to be_not_found
    end

    context 'with idv api enabled' do
      let(:idv_api_enabled_steps) { ['something'] }

      context 'invalid step' do
        let(:step) { 'bad' }

        it 'renders 404' do
          expect(response).to be_not_found
        end
      end

      context 'with personal key step enabled' do
        let(:idv_api_enabled_steps) { ['personal_key', 'personal_key_confirm'] }
        let(:step) { 'personal_key' }

        before do
          profile_maker = Idv::ProfileMaker.new(
            applicant: applicant,
            user: user,
            user_password: password,
          )
          profile = profile_maker.save_profile
          controller.idv_session.pii = profile_maker.pii_attributes
          controller.idv_session.profile_id = profile.id
          controller.idv_session.personal_key = profile.personal_key
        end

        it 'renders view' do
          expect(response).to render_template(:show)
        end

        it 'sets app data' do
          response

          expect(assigns[:app_data]).to include(
            base_path: idv_app_path,
            start_over_url: idv_session_path,
            cancel_url: idv_cancel_path,
            completion_url: idv_gpo_verify_url,
            enabled_step_names: idv_api_enabled_steps,
            initial_values: { 'personalKey' => kind_of(String) },
            store_key: kind_of(String),
          )
        end

        context 'empty step' do
          let(:step) { nil }

          it 'renders view' do
            expect(response).to render_template(:show)
          end
        end
      end

      context 'with password confirmation step enabled' do
        let(:idv_api_enabled_steps) { ['password_confirm', 'personal_key', 'personal_key_confirm'] }
        let(:step) { 'password_confirm' }

        it 'renders view' do
          expect(response).to render_template(:show)
        end

        it 'sets app data' do
          response

          expect(assigns[:app_data]).to include(
            base_path: idv_app_path,
            start_over_url: idv_session_path,
            cancel_url: idv_cancel_path,
            completion_url: account_url,
            enabled_step_names: idv_api_enabled_steps,
            initial_values: { 'userBundleToken' => kind_of(String) },
            store_key: kind_of(String),
          )
        end

        context 'empty step' do
          let(:step) { nil }

          it 'renders view' do
            expect(response).to render_template(:show)
          end
        end
      end
    end

    def stub_idv_session
      idv_session = Idv::Session.new(
        user_session: controller.user_session,
        current_user: user,
        service_provider: nil,
      )
      idv_session.applicant = applicant
      idv_session.resolution_successful = true
      allow(controller).to receive(:idv_session).and_return(idv_session)
    end
  end
end
