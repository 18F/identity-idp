## frozen_string_literal: true

require 'rails_helper'
require 'axe-rspec'

RSpec.describe 'In Person Proofing Passports', js: true do
  include IdvStepHelper
  include InPersonHelper
  include AbTestsHelper
  include PassportApiHelpers

  let(:service_provider) { :oidc }
  let(:user) { user_with_2fa }
  let(:service_provider_name) { 'Test SP' }

  before do
    ServiceProvider.find_by(issuer: service_provider_issuer(service_provider))
      .update(in_person_proofing_enabled: true)
    allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
  end

  context 'when passports are allowed' do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled).and_return(true)
      allow(IdentityConfig.store).to receive(:doc_auth_passports_percent).and_return(100)
      stub_health_check_settings
      stub_health_check_endpoints
    end

    context 'when in person passports are enabled' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_passports_enabled).and_return(true)
      end

      it 'allows the user to accesss in person passport content' do
        reload_ab_tests
        visit_idp_from_sp_with_ial2(service_provider)
        sign_in_live_with_2fa(user)

        expect(page).to have_current_path(idv_welcome_path)
        expect(page).to have_content t('doc_auth.headings.welcome', sp_name: service_provider_name)
        expect(page).to have_content t('doc_auth.instructions.bullet1b')

        complete_welcome_step

        expect(page).to have_current_path(idv_agreement_path)
        complete_agreement_step

        expect(page).to have_current_path(idv_how_to_verify_path)
        expect(page).to have_content t('doc_auth.info.verify_online_description_passport')

        click_on t('forms.buttons.continue_ipp')

        expect(page).to have_current_path(idv_document_capture_path(step: 'how_to_verify'))

        click_on t('forms.buttons.continue')
        complete_location_step(user)

        expect(page).to have_current_path(idv_in_person_choose_id_type_path)

        expect(page).to have_content t('doc_auth.headings.choose_id_type')
        expect(page).to have_content t('in_person_proofing.info.choose_id_type')
        expect(page).to have_content t('doc_auth.forms.id_type_preference.drivers_license')
        expect(page).to have_content t('doc_auth.forms.id_type_preference.passport')
      end
    end

    context 'when in person passports are disabled' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_passports_enabled).and_return(false)
      end

      it 'does not allow the user to access in person passport content' do
        reload_ab_tests
        visit_idp_from_sp_with_ial2(service_provider)
        sign_in_live_with_2fa(user)

        expect(page).to have_current_path(idv_welcome_path)
        expect(page).to have_content t('doc_auth.headings.welcome', sp_name: service_provider_name)
        expect(page).to have_content t('doc_auth.instructions.bullet1b')

        complete_welcome_step

        expect(page).to have_current_path(idv_agreement_path)
        complete_agreement_step

        expect(page).to have_current_path(idv_how_to_verify_path)
        expect(page).to have_content strip_tags(
          t('doc_auth.info.verify_at_post_office_description_passport_html'),
        )

        click_on t('forms.buttons.continue_ipp')

        expect(page).to have_current_path(idv_document_capture_path(step: 'how_to_verify'))

        click_on t('forms.buttons.continue')
        complete_location_step(user)

        expect(page).to have_current_path(idv_in_person_state_id_path)
      end
    end
  end

  context 'when passports are not allowed' do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled).and_return(false)
    end

    context 'when in person passports are enabled' do
      before do
        allow(IdentityConfig.store).to receive(:in_person_passports_enabled).and_return(true)
      end

      it 'does not allow the user to access in person passport content' do
        reload_ab_tests
        visit_idp_from_sp_with_ial2(service_provider)
        sign_in_live_with_2fa(user)

        expect(page).to have_current_path(idv_welcome_path)
        expect(page).to have_content t('doc_auth.headings.welcome', sp_name: service_provider_name)
        expect(page).to have_content t('doc_auth.instructions.bullet1a')

        complete_welcome_step

        expect(page).to have_current_path(idv_agreement_path)
        complete_agreement_step

        expect(page).to have_current_path(idv_how_to_verify_path)
        expect(page).to_not have_content t('doc_auth.info.verify_online_description_passport')
        expect(page).to_not have_content strip_tags(
          t('doc_auth.info.verify_at_post_office_description_passport_html'),
        )

        click_on t('forms.buttons.continue_ipp')

        expect(page).to have_current_path(idv_document_capture_path(step: 'how_to_verify'))

        click_on t('forms.buttons.continue')
        complete_location_step(user)

        expect(page).to have_current_path(idv_in_person_state_id_path)
      end
    end
  end
end
