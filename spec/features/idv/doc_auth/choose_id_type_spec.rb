require 'rails_helper'

RSpec.feature 'choose id type step' do
  include DocAuthHelper
  include AbTestsHelper
  include IdvStepHelper

  let(:fake_analytics) { FakeAnalytics.new }

  before do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
  end

  context 'happy path' do
    let(:ipp_service_provider) do
      create(:service_provider, :active, :in_person_proofing_enabled)
    end
    let(:doc_auth_passports_enabled) { true }
    let(:doc_auth_passports_percent) { 100 }
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled)
        .and_return(doc_auth_passports_enabled)
      allow(IdentityConfig.store).to receive(:doc_auth_passports_percent)
        .and_return(doc_auth_passports_percent)
      allow_any_instance_of(ServiceProviderSession).to receive(:sp_name)
        .and_return(ipp_service_provider)
      allow(IdentityConfig.store).to receive(:doc_auth_passport_vendor_default)
        .and_return(Idp::Constants::Vendors::SOCURE)
      stub_request(:get, IdentityConfig.store.dos_passport_composite_healthcheck_endpoint)
        .to_return({ status: 200, body: { status: 'UP' }.to_json })
      reload_ab_tests
      visit_idp_from_sp_with_ial2(
        :oidc,
        **{ client_id: ipp_service_provider.issuer },
      )
      sign_in_and_2fa_user
    end

    after do
      reload_ab_tests
    end

    context 'desktop flow', :js, :allow_browser_log do
      before do
        complete_doc_auth_steps_before_hybrid_handoff_step
      end

      it 'shows choose id type screen and continues after passport option' do
        expect(page).to have_content(t('doc_auth.headings.upload_from_computer'))
        click_on t('forms.buttons.upload_photos')
        expect(page).to have_current_path(idv_choose_id_type_url)
        choose(t('doc_auth.forms.id_type_preference.passport'))
        click_on t('forms.buttons.continue')
        expect(page).to have_current_path(idv_socure_document_capture_url)
        expect(fake_analytics).to have_logged_event(
          :passport_api_health_check,
          step: 'choose_id_type',
          success: true,
          body: '{"status":"UP"}',
          errors: {},
        )
        visit idv_choose_id_type_url
        expect(page).to have_checked_field(
          'doc_auth_choose_id_type_preference_passport',
          visible: :all,
        )
        choose(t('doc_auth.forms.id_type_preference.drivers_license'))
        click_on t('forms.buttons.continue')
        expect(page).to have_current_path(idv_document_capture_url)
      end

      it 'shows choose id type screen and continues after license option' do
        expect(page).to have_content(t('doc_auth.headings.upload_from_computer'))
        click_on t('forms.buttons.upload_photos')
        expect(page).to have_current_path(idv_choose_id_type_url)
        choose(t('doc_auth.forms.id_type_preference.drivers_license'))
        click_on t('forms.buttons.continue')
        expect(page).to have_current_path(idv_document_capture_url)
        expect(fake_analytics).not_to have_logged_event(
          :passport_api_health_check,
        )
        visit idv_choose_id_type_url
        expect(page).to have_checked_field(
          'doc_auth_choose_id_type_preference_drivers_license',
          visible: :all,
        )
        choose(t('doc_auth.forms.id_type_preference.passport'))
        click_on t('forms.buttons.continue')
        expect(page).to have_current_path(idv_socure_document_capture_url)
        expect(fake_analytics).to have_logged_event(
          :passport_api_health_check,
          step: 'choose_id_type',
          success: true,
          body: '{"status":"UP"}',
          errors: {},
        )
      end
    end

    context 'mobile flow', :js, driver: :headless_chrome_mobile do
      context 'with in-person proofing enabled and passports enabled' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
          allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled)
            .and_return(true)
          allow_any_instance_of(ServiceProvider).to receive(
            :in_person_proofing_enabled,
          ).and_return(true)
          complete_doc_auth_steps_before_agreement_step
          complete_agreement_step
        end

        it 'shows choose id type screen and continues after drivers license option' do
          expect(page).to have_current_path(idv_how_to_verify_url)
          click_button t('forms.buttons.continue_online')
          expect(page).to have_current_path(idv_choose_id_type_url)
          choose(t('doc_auth.forms.id_type_preference.drivers_license'))
          click_on t('forms.buttons.continue')
          expect(page).to have_current_path(idv_document_capture_url)
          expect(fake_analytics).not_to have_logged_event(
            :passport_api_health_check,
            step: 'choose_id_type',
            success: true,
            body: '{"status":"UP"}',
            errors: {},
          )
          visit idv_choose_id_type_url
          expect(page).to have_checked_field(
            'doc_auth_choose_id_type_preference_drivers_license',
            visible: :all,
          )
        end
      end
      context 'with in-person proofing disabled' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(false)
          allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled)
            .and_return(false)
          complete_doc_auth_steps_before_agreement_step
          complete_agreement_step
        end

        it 'shows choose id type screen and continues after drivers license option' do
          expect(page).to have_current_path(idv_choose_id_type_url)
          choose(t('doc_auth.forms.id_type_preference.drivers_license'))
          click_on t('forms.buttons.continue')
          expect(page).to have_current_path(idv_document_capture_url)
          visit idv_choose_id_type_url
          expect(page).to have_checked_field(
            'doc_auth_choose_id_type_preference_drivers_license',
            visible: :all,
          )
        end
      end
      context 'with in-person proofing enabled and passports disabled' do
        let(:doc_auth_passports_enabled) { false }
        let(:doc_auth_passports_percent) { 0 }
        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
          allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled)
            .and_return(true)
          allow_any_instance_of(ServiceProvider).to receive(
            :in_person_proofing_enabled,
          ).and_return(true)
          complete_doc_auth_steps_before_agreement_step
          complete_agreement_step
        end
        it 'goes from how to verify to document capture' do
          expect(page).to have_current_path(idv_how_to_verify_url)
          click_button t('forms.buttons.continue_online')
          complete_choose_id_type_step
          expect(page).to have_current_path(idv_document_capture_url)
        end
      end
    end
  end

  context 'api health check failure after welcome step' do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled).and_return(true)
      allow(IdentityConfig.store).to receive(:doc_auth_passports_percent).and_return(100)
      stub_request(:get, IdentityConfig.store.dos_passport_composite_healthcheck_endpoint)
        .to_return({ status: 200, body: { status: 'UP' }.to_json })
      reload_ab_tests
      sign_in_and_2fa_user
    end

    after do
      reload_ab_tests
    end

    context 'desktop flow', :js do
      before do
        complete_doc_auth_steps_before_hybrid_handoff_step
      end

      it 'shows choose id type screen with passport field disabled' do
        expect(page).to have_content(t('doc_auth.headings.upload_from_computer'))
        stub_request(:get, IdentityConfig.store.dos_passport_composite_healthcheck_endpoint)
          .to_return({ status: 200, body: { status: 'DOWN' }.to_json })
        click_on t('forms.buttons.upload_photos')
        expect(page).to have_current_path(idv_choose_id_type_url)
        choose(t('doc_auth.forms.id_type_preference.passport'))
        click_on t('forms.buttons.continue')
        expect(page).to have_current_path(idv_choose_id_type_url(passports: false))
        expect(fake_analytics).to have_logged_event(
          :passport_api_health_check,
          step: 'choose_id_type',
          success: false,
          body: '{"status":"DOWN"}',
          errors: {},
        )
        # expect radio button field 'doc_auth_choose_id_type_preference_passport' to be disabled
        expect(page).to have_field(
          'doc_auth_choose_id_type_preference_passport',
          visible: :all,
          disabled: true,
        )
        click_on t('forms.buttons.continue')
        expect(page).to have_current_path(idv_document_capture_url)
      end
    end
  end

  context 'flow policy' do
    include DocAuthHelper

    before do
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled)
        .and_return(true)

      sign_in_and_2fa_user
    end

    scenario 'User fails attempt to navigate to choose_id_type after starting IPP flow' do
      complete_up_to_how_to_verify_step_for_opt_in_ipp(remote: false)
      visit idv_choose_id_type_url
      expect(page).not_to have_current_path(idv_choose_id_type_url)
    end
  end
end
