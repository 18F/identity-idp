require 'rails_helper'

RSpec.describe 'state id 50/50 state', js: true, allowed_extra_analytics: [:*],
                                       allow_browser_log: true do
  include IdvStepHelper
  include InPersonHelper

  let(:ipp_service_provider) { create(:service_provider, :active, :in_person_proofing_enabled) }
  let(:user) { user_with_2fa }

  before do
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled).and_return(true)
  end

  context 'when navigating to state id page from PO search location page' do
    context 'when the controller is switched from enabled to disabled' do
      before do
        allow(IdentityConfig.store).to receive(
          :in_person_state_id_controller_enabled,
        ).and_return(true)
        visit_idp_from_sp_with_ial2(:oidc, **{ client_id: ipp_service_provider.issuer })
        sign_in_via_branded_page(user)
        begin_in_person_proofing_with_opt_in_ipp_enabled_and_opting_in
        complete_prepare_step(user)
        allow(IdentityConfig.store).to receive(
          :in_person_state_id_controller_enabled,
        ).and_return(false)
        complete_location_step
      end

      it 'navigates to the FSM state_id route' do
        expect(page).to have_current_path(idv_in_person_step_path(step: :state_id), wait: 10)
      end
    end

    context 'when the controller is switched from disabled to enabled' do
      before do
        allow(IdentityConfig.store).to receive(
          :in_person_state_id_controller_enabled,
        ).and_return(false)
        visit_idp_from_sp_with_ial2(:oidc, **{ client_id: ipp_service_provider.issuer })
        sign_in_via_branded_page(user)
        begin_in_person_proofing_with_opt_in_ipp_enabled_and_opting_in
        complete_prepare_step(user)
        allow(IdentityConfig.store).to receive(
          :in_person_state_id_controller_enabled,
        ).and_return(true)
        complete_location_step
      end

      it 'navigates to the controller state_id route' do
        expect(page).to have_current_path(idv_in_person_proofing_state_id_path, wait: 10)
      end
    end
  end

  context 'when refreshing the state id page' do
    context 'when the controller is switched from enabled to disabled' do
      before do
        allow(IdentityConfig.store).to receive(
          :in_person_state_id_controller_enabled,
        ).and_return(true)
        visit_idp_from_sp_with_ial2(:oidc, **{ client_id: ipp_service_provider.issuer })
        sign_in_via_branded_page(user)
        begin_in_person_proofing_with_opt_in_ipp_enabled_and_opting_in
        complete_prepare_step(user)
        complete_location_step
        allow(IdentityConfig.store).to receive(
          :in_person_state_id_controller_enabled,
        ).and_return(false)
        page.refresh
      end

      it 'renders the 404 page' do
        expect(page).to have_content(
          "The page you were looking for doesn’t exist.\nYou might want to double-check your link" \
          " and try again. (404)",
        )
      end
    end

    context 'when the controller is switched from disabled to enabled' do
      before do
        allow(IdentityConfig.store).to receive(
          :in_person_state_id_controller_enabled,
        ).and_return(false)
        visit_idp_from_sp_with_ial2(:oidc, **{ client_id: ipp_service_provider.issuer })
        sign_in_via_branded_page(user)
        begin_in_person_proofing_with_opt_in_ipp_enabled_and_opting_in
        complete_prepare_step(user)
        complete_location_step
        allow(IdentityConfig.store).to receive(
          :in_person_state_id_controller_enabled,
        ).and_return(true)
        page.refresh
      end

      it 'renders the FSM state_id page' do
        expect(page).to have_current_path(idv_in_person_step_path(step: :state_id), wait: 10)
      end
    end
  end

  context 'when navigating to state id page from verify info page' do
    context 'when the controller is switched from enabled to disabled' do
      before do
        allow(IdentityConfig.store).to receive(
          :in_person_state_id_controller_enabled,
        ).and_return(true)
        visit_idp_from_sp_with_ial2(:oidc, **{ client_id: ipp_service_provider.issuer })
        sign_in_via_branded_page(user)
        begin_in_person_proofing_with_opt_in_ipp_enabled_and_opting_in
        complete_prepare_step(user)
        complete_location_step
        complete_state_id_controller(user, same_address_as_id: true)
        complete_ssn_step(user)
        expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
        allow(IdentityConfig.store).to receive(
          :in_person_state_id_controller_enabled,
        ).and_return(false)
        click_button t('idv.buttons.change_state_id_label')
      end

      it 'navigates to the FSM state_id route' do
        expect(page).to have_current_path(idv_in_person_step_path(step: :state_id), wait: 10)
        # state id page has fields that are pre-populated
        expect(page).to have_field(
          t('in_person_proofing.form.state_id.first_name'),
          with: InPersonHelper::GOOD_FIRST_NAME,
        )
        expect(page).to have_field(
          t('in_person_proofing.form.state_id.last_name'),
          with: InPersonHelper::GOOD_LAST_NAME,
        )
        expect(page).to have_field(t('components.memorable_date.month'), with: '10')
        expect(page).to have_field(t('components.memorable_date.day'), with: '6')
        expect(page).to have_field(t('components.memorable_date.year'), with: '1938')
        expect(page).to have_field(
          t('in_person_proofing.form.state_id.state_id_jurisdiction'),
          with: Idp::Constants::MOCK_IDV_APPLICANT[:state_id_jurisdiction],
        )
        expect(page).to have_field(
          t('in_person_proofing.form.state_id.state_id_number'),
          with: InPersonHelper::GOOD_STATE_ID_NUMBER,
        )
        expect(page).to have_field(
          t('in_person_proofing.form.state_id.address1'),
          with: InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1,
        )
        expect(page).to have_field(
          t('in_person_proofing.form.state_id.address2'),
          with: InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS2,
        )
        expect(page).to have_field(
          t('in_person_proofing.form.state_id.city'),
          with: InPersonHelper::GOOD_IDENTITY_DOC_CITY,
        )
        expect(page).to have_field(
          t('in_person_proofing.form.state_id.zipcode'),
          with: InPersonHelper::GOOD_IDENTITY_DOC_ZIPCODE,
        )
        expect(page).to have_field(
          t('in_person_proofing.form.state_id.identity_doc_address_state'),
          with: Idp::Constants::MOCK_IDV_APPLICANT[:state_id_jurisdiction],
        )
        expect(page).to have_checked_field(
          t('in_person_proofing.form.state_id.same_address_as_id_yes'),
          visible: false,
        )
      end
    end

    context 'when the controller is switched from disabled to enabled' do
      before do
        allow(IdentityConfig.store).to receive(
          :in_person_state_id_controller_enabled,
        ).and_return(false)
        visit_idp_from_sp_with_ial2(:oidc, **{ client_id: ipp_service_provider.issuer })
        sign_in_via_branded_page(user)
        begin_in_person_proofing_with_opt_in_ipp_enabled_and_opting_in
        complete_prepare_step(user)
        complete_location_step
        complete_state_id_step(user, same_address_as_id: true)
        complete_ssn_step(user)
        expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
        allow(IdentityConfig.store).to receive(
          :in_person_state_id_controller_enabled,
        ).and_return(true)
        click_button t('idv.buttons.change_state_id_label')
      end

      it 'navigates to the controller state_id route' do
        expect(page).to have_current_path(idv_in_person_proofing_state_id_path, wait: 10)
        # state id page has fields that are pre-populated
        expect(page).to have_field(
          t('in_person_proofing.form.state_id.first_name'),
          with: InPersonHelper::GOOD_FIRST_NAME,
        )
        expect(page).to have_field(
          t('in_person_proofing.form.state_id.last_name'),
          with: InPersonHelper::GOOD_LAST_NAME,
        )
        expect(page).to have_field(t('components.memorable_date.month'), with: '10')
        expect(page).to have_field(t('components.memorable_date.day'), with: '6')
        expect(page).to have_field(t('components.memorable_date.year'), with: '1938')
        expect(page).to have_field(
          t('in_person_proofing.form.state_id.state_id_jurisdiction'),
          with: Idp::Constants::MOCK_IDV_APPLICANT[:state_id_jurisdiction],
        )
        expect(page).to have_field(
          t('in_person_proofing.form.state_id.state_id_number'),
          with: InPersonHelper::GOOD_STATE_ID_NUMBER,
        )
        expect(page).to have_field(
          t('in_person_proofing.form.state_id.address1'),
          with: InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1,
        )
        expect(page).to have_field(
          t('in_person_proofing.form.state_id.address2'),
          with: InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS2,
        )
        expect(page).to have_field(
          t('in_person_proofing.form.state_id.city'),
          with: InPersonHelper::GOOD_IDENTITY_DOC_CITY,
        )
        expect(page).to have_field(
          t('in_person_proofing.form.state_id.zipcode'),
          with: InPersonHelper::GOOD_IDENTITY_DOC_ZIPCODE,
        )
        expect(page).to have_field(
          t('in_person_proofing.form.state_id.identity_doc_address_state'),
          with: Idp::Constants::MOCK_IDV_APPLICANT[:state_id_jurisdiction],
        )
        expect(page).to have_checked_field(
          t('in_person_proofing.form.state_id.same_address_as_id_yes'),
          visible: false,
        )
      end
    end
  end

  context 'when updating state id info from the verify info page' do
    let(:first_name_update) { 'Natalya' }

    context 'when the controller is switched from enabled to disabled' do
      before do
        allow(IdentityConfig.store).to receive(
          :in_person_state_id_controller_enabled,
        ).and_return(true)
        visit_idp_from_sp_with_ial2(:oidc, **{ client_id: ipp_service_provider.issuer })
        sign_in_via_branded_page(user)
        begin_in_person_proofing_with_opt_in_ipp_enabled_and_opting_in
        complete_prepare_step(user)
        complete_location_step
        complete_state_id_controller(user, same_address_as_id: true)
        complete_ssn_step(user)
        expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
        allow(IdentityConfig.store).to receive(
          :in_person_state_id_controller_enabled,
        ).and_return(false)
        click_button t('idv.buttons.change_state_id_label')
        fill_in t('in_person_proofing.form.state_id.first_name'), with: first_name_update
        click_button t('forms.buttons.submit.update')
      end

      it 'navigates back to the verify_info page' do
        expect(page).to have_current_path(idv_in_person_verify_info_path)
        expect(page).to have_text(first_name_update)
      end
    end

    context 'when the controller is switched from disabled to enabled' do
      before do
        allow(IdentityConfig.store).to receive(
          :in_person_state_id_controller_enabled,
        ).and_return(false)
        visit_idp_from_sp_with_ial2(:oidc, **{ client_id: ipp_service_provider.issuer })
        sign_in_via_branded_page(user)
        begin_in_person_proofing_with_opt_in_ipp_enabled_and_opting_in
        complete_prepare_step(user)
        complete_location_step
        complete_state_id_step(user, same_address_as_id: true)
        complete_ssn_step(user)
        expect_in_person_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))
        allow(IdentityConfig.store).to receive(
          :in_person_state_id_controller_enabled,
        ).and_return(true)
        click_button t('idv.buttons.change_state_id_label')
        fill_in t('in_person_proofing.form.state_id.first_name'), with: first_name_update
        click_button t('forms.buttons.submit.update')
      end

      it 'navigates back to the verify_info page' do
        expect(page).to have_current_path(idv_in_person_verify_info_path)
        expect(page).to have_text(first_name_update)
      end
    end
  end

  context 'when navigating to state id page from hybrid PO search location page' do
    let(:phone_number) { '415-555-0199' }

    before do
      allow(FeatureManagement).to receive(:doc_capture_polling_enabled?).and_return(true)
      allow(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
        @sms_link = config[:link]
        impl.call(**config)
      end.at_least(1).times
    end

    context 'when the controller is switched from enabled to disabled' do
      before do
        perform_in_browser(:desktop) do
          allow(IdentityConfig.store).to receive(
            :in_person_state_id_controller_enabled,
          ).and_return(true)
          visit_idp_from_sp_with_ial2(:oidc, **{ client_id: ipp_service_provider.issuer })
          sign_in_via_branded_page(user)
          complete_doc_auth_steps_before_hybrid_handoff_step
          click_on t('forms.buttons.continue_remote')
          clear_and_fill_in(:doc_auth_phone, phone_number)
          click_send_link
        end

        perform_in_browser(:mobile) do
          visit @sms_link
          mock_doc_auth_fail_face_match_fail
          attach_and_submit_images
          click_button t('in_person_proofing.body.cta.button')
          click_idv_continue
          allow(IdentityConfig.store).to receive(
            :in_person_state_id_controller_enabled,
          ).and_return(false)
          complete_location_step
        end
      end

      it 'navigates to the FSM state_id route' do
        perform_in_browser(:desktop) do
          expect(page).to have_current_path(idv_in_person_step_path(step: :state_id), wait: 10)
        end
      end
    end

    context 'when the controller is switched from disabled to enabled' do
      before do
        perform_in_browser(:desktop) do
          allow(IdentityConfig.store).to receive(
            :in_person_state_id_controller_enabled,
          ).and_return(false)
          visit_idp_from_sp_with_ial2(:oidc, **{ client_id: ipp_service_provider.issuer })
          sign_in_via_branded_page(user)
          complete_doc_auth_steps_before_hybrid_handoff_step
          click_on t('forms.buttons.continue_remote')
          clear_and_fill_in(:doc_auth_phone, phone_number)
          click_send_link
        end

        perform_in_browser(:mobile) do
          visit @sms_link
          mock_doc_auth_fail_face_match_fail
          attach_and_submit_images
          click_button t('in_person_proofing.body.cta.button')
          click_idv_continue
          allow(IdentityConfig.store).to receive(
            :in_person_state_id_controller_enabled,
          ).and_return(true)
          complete_location_step
        end
      end

      it 'navigates to the controller state_id route' do
        perform_in_browser(:desktop) do
          expect(page).to have_current_path(idv_in_person_proofing_state_id_path, wait: 10)
        end
      end
    end
  end
end
