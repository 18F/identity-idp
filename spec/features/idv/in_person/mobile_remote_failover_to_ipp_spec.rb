require 'rails_helper'

RSpec.describe 'mobile remote failover to In-person Proofing', js: true,
                                                               driver: :headless_chrome_mobile do
  include IdvStepHelper
  include SpAuthHelper
  include InPersonHelper
  include UspsIppHelper

  context 'when passports are enabled for IdV' do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled).and_return(true)
      allow(IdentityConfig.store).to receive(:doc_auth_passports_percent).and_return(100)
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled).and_return(true)
      stub_request(:get, IdentityConfig.store.dos_passport_composite_healthcheck_endpoint)
        .to_return({ status: 200, body: { status: 'UP' }.to_json })
      reload_ab_tests
    end

    context 'when In-person passports are disabled' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_passports_enabled).and_return(false)
      end

      context 'when the user fails remote docauth and switches to IPP', allow_browser_log: true do
        before do
          sign_in_and_2fa_user
          complete_doc_auth_steps_before_agreement_step
          complete_agreement_step
          choose_id_type(:state_id)

          # Fail docauth
          complete_document_capture_step_with_yml(
            'spec/fixtures/ial2_test_credential_multiple_doc_auth_failures_both_sides.yml',
            expected_path: idv_document_capture_url,
          )

          # begin in-person proofing
          find(:button, t('in_person_proofing.body.cta.button'), wait: 10).click
        end

        context 'when the user selects a post office location' do
          before do
            complete_prepare_step
            complete_location_step
          end

          it 'then the user is navigated to the state-id form step' do
            expect(page).to have_current_path(idv_in_person_state_id_path)
          end
        end
      end
    end

    context 'when In-person passports are enabled' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_passports_enabled).and_return(true)
      end

      context 'when the user fails remote docauth and switches to IPP', allow_browser_log: true do
        before do
          sign_in_and_2fa_user
          complete_doc_auth_steps_before_agreement_step
          complete_agreement_step
          choose_id_type(:state_id)

          # Fail docauth
          complete_document_capture_step_with_yml(
            'spec/fixtures/ial2_test_credential_multiple_doc_auth_failures_both_sides.yml',
            expected_path: idv_document_capture_url,
          )
          # begin in-person proofing
          find(:button, t('in_person_proofing.body.cta.button'), wait: 10).click
        end

        context 'when the user selects a post office location and ID type state-ID' do
          before do
            complete_prepare_step
            complete_location_step
            choose_id_type(:state_id)
          end

          it 'then the user is navigated to the state-id form' do
            expect(page).to have_current_path(idv_in_person_state_id_path)
          end
        end

        context 'when the user selects a post office location and ID type passport' do
          before do
            complete_prepare_step
            complete_location_step
            choose_id_type(:passport)
          end

          it 'then the user is navigated to the passport form' do
            expect(page).to have_current_path(idv_in_person_passport_path)
          end
        end
      end
    end
  end
end
