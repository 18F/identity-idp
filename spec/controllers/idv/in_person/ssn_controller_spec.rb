require 'rails_helper'

RSpec.describe Idv::InPerson::SsnController do
  include IdvHelper

  let(:flow_session) do
    { 'document_capture_session_uuid' => 'fd14e181-6fb1-4cdc-92e0-ef66dad0df4e',
      'pii_from_user' => Idp::Constants::MOCK_IDV_APPLICANT_SAME_ADDRESS_AS_ID_WITH_NO_SSN.dup,
      :threatmetrix_session_id => 'c90ae7a5-6629-4e77-b97c-f1987c2df7d0',
      :flow_path => 'standard' }
  end

  let(:ssn) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn] }

  let(:user) { create(:user) }

  before do
    stub_sign_in(user)
    subject.user_session['idv/in_person'] = flow_session
    stub_analytics
    stub_attempts_tracker
    allow(@analytics).to receive(:track_event)
  end

  describe 'before_actions' do
    it 'checks that feature flag is enabled' do
      expect(subject).to have_actions(
        :before,
        :renders_404_if_in_person_ssn_info_controller_enabled_flag_not_set,
      )
    end

    context 'when in_person_ssn_info_controller_enabled is not set' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_ssn_info_controller_enabled).
          and_return(nil)
      end

      context('#renders_404_if_in_person_ssn_info_controller_enabled_flag_not_set') do
        it 'renders a 404' do
          get :show

          expect(response).to be_not_found
        end
      end
    end

    context 'when in_person_ssn_info_controller_enabled is false' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_ssn_info_controller_enabled).
          and_return(false)
      end

      context('#renders_404_if_in_person_ssn_info_controller_enabled_flag_not_set') do
        it 'renders a 404' do
          get :show

          expect(response).to be_not_found
        end
      end
    end

    context 'when in_person_ssn_info_controller_enabled is true' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_ssn_info_controller_enabled).
          and_return(true)
      end

      context('#confirm_in_person_address_step_complete') do
        it 'redirects if the user hasn\'t completed the address page' do
          # delete address attributes on session
          flow_session['pii_from_user'].delete(:address1)
          flow_session['pii_from_user'].delete(:address2)
          flow_session['pii_from_user'].delete(:city)
          flow_session['pii_from_user'].delete(:state)
          flow_session['pii_from_user'].delete(:zipcode)
          get :show

          expect(response).to redirect_to idv_in_person_step_url(step: :address)
        end
      end

      describe '#show' do
        let(:analytics_name) { 'IdV: doc auth ssn visited' }
        let(:analytics_args) do
          {
            analytics_id: 'In Person Proofing',
            flow_path: 'standard',
            irs_reproofing: false,
            step: 'ssn',
          }
        end

        it 'renders the show template' do
          get :show

          expect(response).to render_template :show
        end

        it 'sends analytics_visited event' do
          get :show

          expect(@analytics).to have_received(:track_event).with(analytics_name, analytics_args)
        end

        it 'updates DocAuthLog ssn_view_count' do
          doc_auth_log = DocAuthLog.create(user_id: user.id)

          expect { get :show }.to(
            change { doc_auth_log.reload.ssn_view_count }.from(0).to(1),
          )
        end

        context 'with an ssn in session' do
          let(:referer) { idv_document_capture_url }
          before do
            flow_session['pii_from_user'][:ssn] = ssn
            request.env['HTTP_REFERER'] = referer
          end

          context 'referer is not verify_info' do
            it 'redirects to verify_info' do
              get :show

              expect(response).to redirect_to(idv_in_person_verify_info_url)
            end
          end

          context 'referer is verify_info' do
            let(:referer) { idv_in_person_verify_info_url }
            it 'does not redirect' do
              get :show

              expect(response).to render_template :show
            end
          end
        end
      end
    end
  end
end
