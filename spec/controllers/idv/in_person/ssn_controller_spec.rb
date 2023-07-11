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
    it 'includes authentication before_action' do
      expect(subject).to have_actions(
        :before,
        :confirm_two_factor_authenticated,
      )
    end

    it 'checks that feature flag is enabled' do
      expect(subject).to have_actions(
        :before,
        :renders_404_if_in_person_ssn_info_controller_enabled_flag_not_set,
      )
    end

    it 'includes outage before_action' do
      expect(subject).to have_actions(
        :before,
        :check_for_outage,
      )
    end

    it 'checks that the previous step is complete' do
      expect(subject).to have_actions(
        :before,
        :confirm_in_person_address_step_complete,
      )
    end

    it 'overrides CSPs for ThreatMetrix' do
      expect(subject).to have_actions(
        :before,
        :override_csp_for_threat_metrix_no_fsm,
      )
    end

    context 'when in_person_ssn_info_controller_enabled is true' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_ssn_info_controller_enabled).
          and_return(true)
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

        it 'overrides Content Security Policies for ThreatMetrix' do
          allow(IdentityConfig.store).to receive(:proofing_device_profiling).
            and_return(:enabled)
          get :show

          csp = response.request.content_security_policy

          aggregate_failures do
            expect(csp.directives['script-src']).to include('h.online-metrix.net')
            expect(csp.directives['script-src']).to include("'unsafe-eval'")

            expect(csp.directives['style-src']).to include("'unsafe-inline'")

            expect(csp.directives['child-src']).to include('h.online-metrix.net')

            expect(csp.directives['connect-src']).to include('h.online-metrix.net')

            expect(csp.directives['img-src']).to include('*.online-metrix.net')
          end
        end

        it 'does not override the Content Security for CSP disabled test users' do
          allow(IdentityConfig.store).to receive(:proofing_device_profiling).
            and_return(:enabled)
          allow(IdentityConfig.store).to receive(:idv_tmx_test_csp_disabled_emails).
            and_return([user.email_addresses.first.email])

          get :show

          csp = response.request.content_security_policy

          aggregate_failures do
            expect(csp.directives['script-src']).to_not include('h.online-metrix.net')

            expect(csp.directives['style-src']).to_not include("'unsafe-inline'")

            expect(csp.directives['child-src']).to_not include('h.online-metrix.net')

            expect(csp.directives['connect-src']).to_not include('h.online-metrix.net')

            expect(csp.directives['img-src']).to_not include('*.online-metrix.net')
          end
        end
      end

      # describe '#should_render_threatmetrix_js?' do
      #   it 'returns true if the JS should be disabled for the user' do
      #     allow(IdentityConfig.store).to receive(:proofing_device_profiling).
      #       and_return(:enabled)
      #     allow(IdentityConfig.store).to receive(:idv_tmx_test_js_disabled_emails).
      #       and_return([user.email_addresses.first.email])

      #     expect(controller.should_render_threatmetrix_js?).to eq(false)
      #   end

      #   it 'returns true if the JS should not be disabled for the user' do
      #     allow(IdentityConfig.store).to receive(:proofing_device_profiling).
      #       and_return(:enabled)

      #     expect(controller.should_render_threatmetrix_js?).to eq(true)
      #   end

      #   it 'returns false if TMx profiling is disabled' do
      #     allow(IdentityConfig.store).to receive(:proofing_device_profiling).
      #       and_return(:disabled)

      #     expect(controller.should_render_threatmetrix_js?).to eq(false)
      #   end
      # end
    end
  end
end
