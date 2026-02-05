require 'rails_helper'

RSpec.describe Idv::InPerson::StateIdController do
  include FlowPolicyHelper
  include InPersonHelper

  let(:user) { build(:user) }
  let(:enrollment) { create(:in_person_enrollment, :establishing, user:) }

  before do
    stub_sign_in(user)
    stub_up_to(:hybrid_handoff, idv_session: subject.idv_session)
    allow(user).to receive(:establishing_in_person_enrollment).and_return(enrollment)
    subject.user_session['idv/in_person'] = { pii_from_user: {} }
    subject.idv_session.ssn = nil # This made specs pass. Might need more investigation.
    subject.idv_session.opted_in_to_in_person_proofing = true
    stub_analytics
  end

  describe 'before_actions' do
    it 'includes correct before_actions' do
      expect(subject).to have_actions(
        :before,
        :set_usps_form_presenter,
        :initialize_pii_from_user,
        :confirm_step_allowed,
      )
    end

    context '#step_info preconditions check if enrollment exists' do
      let(:enrollment) { nil }

      it 'redirects to document capture if not complete' do
        # Set up DocumentCaptureSession to satisfy choose_id_type completion
        subject.idv_session.document_capture_session_uuid = SecureRandom.uuid
        create(
          :document_capture_session,
          uuid: subject.idv_session.document_capture_session_uuid,
          user:,
          requested_at: Time.zone.now,
          passport_status: 'requested',
        )

        get :show

        expect(response).to redirect_to idv_document_capture_url
      end
    end

    context 'initializes idv/in_person if it is not present' do
      it 'initializes idv/in_person' do
        subject.user_session.delete('idv/in_person')
        get :show

        expect(subject.user_session['idv/in_person']).to eq(
          { 'pii_from_user' => { 'uuid' => user.uuid } },
        )
      end
    end

    context 'initializes pii_from_user if it is not present' do
      it 'initializes pii_from_user' do
        subject.user_session['idv/in_person'].delete(:pii_from_user)
        get :show

        expect(subject.user_session['idv/in_person'][:pii_from_user]).to eq({ 'uuid' => user.uuid })
      end
    end
  end

  describe '#show' do
    let(:analytics_name) { 'IdV: in person proofing state_id visited' }

    let(:analytics_args) do
      {
        analytics_id: 'In Person Proofing',
        flow_path: 'standard',
        step: 'state_id',
        opted_in_to_in_person_proofing: true,
      }
    end

    it 'has non-nil presenter' do
      get :show
      expect(assigns(:presenter)).to be_kind_of(Idv::InPerson::UspsFormPresenter)
    end

    it 'renders the show template' do
      get :show

      expect(response).to render_template :show
    end

    context 'pii_from_user is nil' do
      it 'renders the show template' do
        subject.user_session['idv/in_person'].delete(:pii_from_user)
        get :show

        expect(response).to render_template :show
      end
    end

    context 'user_session does not have idv/in_person' do
      before do
        subject.user_session.delete('idv/in_person')
      end

      it 'renders the show template' do
        get :show
        expect(response).to render_template :show
      end
    end

    it 'logs idv_in_person_proofing_state_id_visited' do
      get :show

      expect(@analytics).to have_logged_event(analytics_name, analytics_args)
    end

    it 'has correct extra_view_variables' do
      expect(subject.extra_view_variables).to include(
        form: Idv::StateIdForm,
        updating_state_id: false,
      )

      expect(subject.extra_view_variables[:pii]).to_not have_key(
        :address1,
      )
    end
  end

  describe '#update' do
    let(:first_name) { 'Charity' }
    let(:last_name) { 'Johnson' }
    let(:formatted_dob) { InPersonHelper::GOOD_DOB }
    let(:formatted_expiration) { InPersonHelper::GOOD_STATE_ID_EXPIRATION }

    let(:dob) do
      parsed_dob = Date.parse(formatted_dob)
      { month: parsed_dob.month.to_s,
        day: parsed_dob.day.to_s,
        year: parsed_dob.year.to_s }
    end

    let(:id_expiration) do
      parsed_exp = Date.parse(formatted_expiration)
      { month: parsed_exp.month.to_s,
        day: parsed_exp.day.to_s,
        year: parsed_exp.year.to_s }
    end

    # residential
    let(:address1) { InPersonHelper::GOOD_ADDRESS1 }
    let(:address2) { InPersonHelper::GOOD_ADDRESS2 }
    let(:city) { InPersonHelper::GOOD_CITY }
    let(:state) { InPersonHelper::GOOD_STATE }
    let(:zipcode) { InPersonHelper::GOOD_ZIPCODE }
    let(:id_number) { 'ABC123234' }
    let(:state_id_jurisdiction) { 'AL' }
    let(:same_address_as_id) { 'true' }
    let(:identity_doc_address1) { InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1 }
    let(:identity_doc_address2) { InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS2 }
    let(:identity_doc_city) { InPersonHelper::GOOD_IDENTITY_DOC_CITY }
    let(:identity_doc_address_state) { InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS_STATE }
    let(:identity_doc_zipcode) { InPersonHelper::GOOD_IDENTITY_DOC_ZIPCODE }

    let(:params) do
      {
        identity_doc: {
          first_name:,
          last_name:,
          same_address_as_id:,
          identity_doc_address1:,
          identity_doc_address2:,
          identity_doc_city:,
          state_id_jurisdiction:,
          id_number:,
          identity_doc_address_state:,
          identity_doc_zipcode:,
          dob:,
          id_expiration:,
        },
      }
    end

    context 'with values submitted' do
      let(:invalid_params) do
        params.merge(
          identity_doc: {
            first_name: 'S@ndy!',
          },
        )
      end

      let(:analytics_name) { 'IdV: in person proofing state_id submitted' }

      let(:analytics_args) do
        {
          success: true,
          analytics_id: 'In Person Proofing',
          flow_path: 'standard',
          step: 'state_id',
          birth_year: dob[:year],
          document_zip_code: identity_doc_zipcode&.slice(0, 5),
          opted_in_to_in_person_proofing: true,
        }
      end

      it 'logs idv_in_person_proofing_state_id_submitted' do
        put :update, params: params

        expect(@analytics).to have_logged_event(analytics_name, analytics_args)
      end

      it 'renders show when validation errors are present when first visiting page' do
        put :update, params: invalid_params

        expect(subject.idv_session.ssn).to eq(nil)
        expect(subject.idv_session.doc_auth_vendor).to eq(nil)
        expect(enrollment.document_type).to eq(nil)
        expect(subject.extra_view_variables[:updating_state_id]).to eq(false)
        expect(response).to render_template :show
      end

      it 'renders show when validation errors are present when re-visiting page' do
        subject.idv_session.ssn = '123-45-6789'
        put :update, params: invalid_params

        expect(enrollment.document_type).to eq(nil)
        expect(subject.extra_view_variables[:updating_state_id]).to eq(true)
        expect(response).to render_template :show
      end

      it 'invalidates future steps, but does not clear ssn' do
        subject.idv_session.ssn = '123-45-6789'
        expect(subject).to receive(:clear_future_steps_from!).and_call_original

        expect { put :update, params: params }.not_to change { subject.idv_session.ssn }
      end

      it 'sets values in flow session' do
        Idv::StateIdForm::ATTRIBUTES.each do |attr|
          expect(subject.user_session['idv/in_person'][:pii_from_user]).to_not have_key attr
        end

        put :update, params: params

        pii_from_user = subject.user_session['idv/in_person'][:pii_from_user]
        expect(pii_from_user[:first_name]).to eq first_name
        expect(pii_from_user[:last_name]).to eq last_name
        expect(pii_from_user[:dob]).to eq formatted_dob
        expect(pii_from_user[:state_id_expiration]).to eq formatted_expiration
        expect(pii_from_user[:identity_doc_zipcode]).to eq identity_doc_zipcode
        expect(pii_from_user[:identity_doc_address_state]).to eq identity_doc_address_state
        # param from form as id_number but is renamed to state_id_number on update
        expect(pii_from_user[:state_id_number]).to eq id_number
      end

      it 'sets values in Idv::Session' do
        put :update, params: params

        expect(subject.idv_session.doc_auth_vendor).to eq(Idp::Constants::Vendors::USPS)
      end

      it 'sets the enrollment document type' do
        put :update, params: params

        expect(enrollment.document_type).to eq(InPersonEnrollment::DOCUMENT_TYPE_STATE_ID)
      end
    end

    context 'when same_address_as_id is...' do
      let(:pii_from_user) { subject.user_session['idv/in_person'][:pii_from_user] }

      context 'changed from "true" to "false"' do
        let(:same_address_as_id) { 'false' }

        it 'retains identity_doc_ attrs/value but removes addr attr in flow session' do
          Idv::StateIdForm::ATTRIBUTES.each do |attr|
            expect(subject.user_session['idv/in_person'][:pii_from_user]).to_not have_key attr
          end

          build_pii_before_state_id_update

          # since same_address_as_id was initially true, pii includes residential address attrs,
          # which are the same as state id address attrs, on re-visiting state id pg
          expect(subject.user_session['idv/in_person'][:pii_from_user]).to include(
            identity_doc_address1:,
            identity_doc_address2:,
            identity_doc_city:,
            identity_doc_address_state:,
            identity_doc_zipcode:,
            address1: identity_doc_address1,
            address2: identity_doc_address2,
            city: identity_doc_city,
            state: identity_doc_address_state,
            zipcode: identity_doc_zipcode,
          )

          # On Verify, user changes response from "Yes,..." to
          # "No, I live at a different address", see submitted_values above
          put :update, params: params

          # retains identity_doc_ attributes and values in flow session
          expect(subject.user_session['idv/in_person'][:pii_from_user]).to include(
            identity_doc_address1:,
            identity_doc_address2:,
            identity_doc_city:,
            identity_doc_address_state:,
            identity_doc_zipcode:,
          )

          # removes address attributes (non identity_doc_ attributes) in flow session
          expect(subject.user_session['idv/in_person'][:pii_from_user]).not_to include(
            address1:,
            address2:,
            city:,
            state:,
            zipcode:,
          )
        end
      end

      context 'changed from "false" to "true"' do
        it <<~EOS.squish do
          retains identity_doc_ attrs/value ands addr attr
          with same value as identity_doc in flow session
        EOS
          Idv::StateIdForm::ATTRIBUTES.each do |attr|
            expect(subject.user_session['idv/in_person'][:pii_from_user]).to_not have_key attr
          end

          build_pii_before_state_id_update(same_address_as_id: 'false')

          # On Verify, user changes response from "No,..." to
          # "Yes, I live at the address on my state-issued ID
          put :update, params: params
          # expect addr attr values to the same as the identity_doc attr values
          expect(pii_from_user[:address1]).to eq identity_doc_address1
          expect(pii_from_user[:address2]).to eq identity_doc_address2
          expect(pii_from_user[:city]).to eq identity_doc_city
          expect(pii_from_user[:state]).to eq identity_doc_address_state
          expect(pii_from_user[:zipcode]).to eq identity_doc_zipcode
        end
      end

      context 'not changed from "false"' do
        let(:same_address_as_id) { 'false' }

        it 'retains identity_doc_ and addr attrs/value in flow session' do
          Idv::StateIdForm::ATTRIBUTES.each do |attr|
            expect(subject.user_session['idv/in_person'][:pii_from_user]).to_not have_key attr
          end

          # User picks "No, I live at a different address" on state ID
          build_pii_before_state_id_update(same_address_as_id: 'false')

          # On Verify, user does not changes response "No,..."
          put :update, params: params

          # retains identity_doc_ & addr attributes and values in flow session
          expect(subject.user_session['idv/in_person'][:pii_from_user]).to include(
            identity_doc_address1:,
            identity_doc_address2:,
            identity_doc_city:,
            identity_doc_address_state:,
            identity_doc_zipcode:,
            address1:,
            address2:,
            city:,
            state:,
            zipcode:,
          )

          # those values are different
          pii_from_user = subject.user_session['idv/in_person'][:pii_from_user]
          expect(pii_from_user[:address1]).to_not eq identity_doc_address1
          expect(pii_from_user[:address2]).to_not eq identity_doc_address2
          expect(pii_from_user[:city]).to_not eq identity_doc_city
          expect(pii_from_user[:state]).to_not eq identity_doc_address_state
          expect(pii_from_user[:zipcode]).to_not eq identity_doc_zipcode
        end
      end
    end
  end

  describe '#step_info' do
    it 'returns a valid StepInfo object' do
      expect(Idv::InPerson::StateIdController.step_info).to be_valid
    end

    context 'undo_step' do
      before do
        subject.idv_session.source_check_vendor = 'aamva'
        subject.idv_session.ipp_aamva_result = { success: true }
        subject.idv_session.ipp_aamva_pending_state_id_pii = { first_name: 'Test' }
        allow(subject.idv_session).to receive(:invalidate_in_person_pii_from_user!)
        described_class.step_info.undo_step.call(idv_session: subject.idv_session, user:)
      end

      it 'clears source_check_vendor, ipp_aamva_result, and pending_pii' do
        expect(subject.idv_session).to have_received(:invalidate_in_person_pii_from_user!)
        expect(subject.idv_session.source_check_vendor).to be_nil
        expect(subject.idv_session.ipp_aamva_result).to be_nil
        expect(subject.idv_session.ipp_aamva_pending_state_id_pii).to be_nil
      end
    end
  end

  describe 'AAMVA integration' do
    before do
      allow(IdentityConfig.store).to receive(:idv_aamva_at_doc_auth_ipp_enabled).and_return(true)
    end

    def valid_state_id_params(same_address_as_id: 'true')
      {
        identity_doc: {
          first_name: 'Charity',
          last_name: 'Johnson',
          same_address_as_id: same_address_as_id,
          identity_doc_address1: InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1,
          identity_doc_address2: InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS2,
          identity_doc_city: InPersonHelper::GOOD_IDENTITY_DOC_CITY,
          state_id_jurisdiction: 'AL',
          id_number: 'ABC123234',
          identity_doc_address_state: InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS_STATE,
          identity_doc_zipcode: InPersonHelper::GOOD_IDENTITY_DOC_ZIPCODE,
          dob: { month: '1', day: '1', year: '1980' },
          id_expiration: { month: '12', day: '31', year: '2030' },
        },
      }
    end

    context 'when redirecting to SSN page (same_address_as_id is true)' do
      let(:params) { valid_state_id_params(same_address_as_id: 'true') }

      it 'enqueues async AAMVA job and redirects to state_id page for polling' do
        expect(IppAamvaProofingJob).to receive(:perform_later)

        put :update, params: params

        expect(response).to redirect_to(idv_in_person_state_id_url)
        expect(subject.idv_session.ipp_aamva_document_capture_session_uuid).to be_present
      end

      it 'stores PII in pending session key, not pii_from_user' do
        allow(IppAamvaProofingJob).to receive(:perform_later)

        put :update, params: params

        # PII should be in pending, not yet committed to pii_from_user
        expect(subject.idv_session.ipp_aamva_pending_state_id_pii).to be_present
        expect(subject.idv_session.ipp_aamva_pending_state_id_pii[:first_name]).to eq('Charity')

        # pii_from_user should NOT have the new data yet
        pii = subject.user_session['idv/in_person'][:pii_from_user]
        expect(pii[:first_name]).to be_nil
      end

      it 'does not create duplicate DocumentCaptureSession if one already exists' do
        put :update, params: params
        first_uuid = subject.idv_session.ipp_aamva_document_capture_session_uuid

        expect do
          put :update, params: params
        end.not_to change { DocumentCaptureSession.count }

        expect(subject.idv_session.ipp_aamva_document_capture_session_uuid).to eq(first_uuid)
      end

      context 'when async AAMVA check is in progress' do
        let(:document_capture_session) do
          create(:document_capture_session, user:, requested_at: Time.zone.now)
        end

        before do
          document_capture_session.create_proofing_session
          subject.idv_session.ipp_aamva_document_capture_session_uuid =
            document_capture_session.uuid
        end

        it 'renders the wait page' do
          get :show

          expect(response).to render_template('shared/wait')
        end

        it 'logs polling wait event' do
          get :show

          expect(@analytics).to have_logged_event(:idv_ipp_aamva_verification_polling_wait)
        end
      end

      context 'when async AAMVA check completes successfully' do
        let(:document_capture_session) do
          create(:document_capture_session, user:, requested_at: Time.zone.now)
        end

        let(:successful_result) do
          {
            success: true,
            errors: {},
            vendor_name: 'TestAAMVA',
            checked_at: Time.zone.now.iso8601,
          }
        end

        before do
          document_capture_session.create_proofing_session
          document_capture_session.store_proofing_result(successful_result)
          subject.idv_session.ipp_aamva_document_capture_session_uuid =
            document_capture_session.uuid
        end

        it 'redirects to SSN page' do
          get :show

          expect(response).to redirect_to(idv_in_person_ssn_url)
        end

        it 'stores AAMVA result in idv_session' do
          get :show

          expect(subject.idv_session.ipp_aamva_result).to be_present
          expect(subject.idv_session.ipp_aamva_result['success']).to eq(true)
          expect(subject.idv_session.source_check_vendor).to be_present
        end

        it 'commits pending PII to pii_from_user on success' do
          # Set up pending PII as if form was just submitted
          subject.idv_session.ipp_aamva_pending_state_id_pii = {
            first_name: 'Charity',
            last_name: 'Johnson',
            same_address_as_id: 'true',
          }

          get :show

          pii = subject.user_session['idv/in_person'][:pii_from_user]
          expect(pii[:first_name]).to eq('Charity')
          expect(pii[:last_name]).to eq('Johnson')

          # Pending should be cleared
          expect(subject.idv_session.ipp_aamva_pending_state_id_pii).to be_nil
        end

        it 'handles nil pii_from_user gracefully' do
          subject.idv_session.ipp_aamva_pending_state_id_pii = {
            first_name: 'Charity',
            last_name: 'Johnson',
          }
          subject.user_session['idv/in_person'][:pii_from_user] = nil

          expect { get :show }.not_to raise_error
          expect(response).to redirect_to(idv_in_person_ssn_url)
        end

        it 'clears the async state' do
          get :show

          expect(subject.idv_session.ipp_aamva_document_capture_session_uuid).to be_nil
        end

        it 'logs completion event with success' do
          get :show

          expect(@analytics).to have_logged_event(
            :idv_ipp_aamva_verification_completed,
            success: true,
            vendor_name: 'TestAAMVA',
            step: 'state_id',
          )
        end
      end

      context 'when async AAMVA check completes successfully on final attempt (rate limited)' do
        let(:document_capture_session) do
          create(:document_capture_session, user:, requested_at: Time.zone.now)
        end

        let(:successful_result) do
          {
            success: true,
            errors: {},
            vendor_name: 'TestAAMVA',
            checked_at: Time.zone.now.iso8601,
          }
        end

        before do
          document_capture_session.create_proofing_session
          document_capture_session.store_proofing_result(successful_result)
          subject.idv_session.ipp_aamva_document_capture_session_uuid =
            document_capture_session.uuid
          # Simulate user at max attempts (rate limited)
          RateLimiter.new(user:, rate_limit_type: :idv_doc_auth).increment_to_limited!
        end

        it 'redirects to SSN page (allows success on final attempt)' do
          get :show

          expect(response).to redirect_to(idv_in_person_ssn_url)
        end

        it 'clears the async state' do
          get :show

          expect(subject.idv_session.ipp_aamva_document_capture_session_uuid).to be_nil
        end

        it 'logs completion event with success' do
          get :show

          expect(@analytics).to have_logged_event(
            :idv_ipp_aamva_verification_completed,
            success: true,
            vendor_name: 'TestAAMVA',
            step: 'state_id',
          )
        end

        it 'does not log rate limit event' do
          get :show

          expect(@analytics).not_to have_logged_event('Rate Limit Reached')
        end
      end

      context 'when async AAMVA check fails on final attempt (rate limited)' do
        let(:document_capture_session) do
          create(:document_capture_session, user:, requested_at: Time.zone.now)
        end

        let(:failed_result) do
          {
            success: false,
            errors: { state_id: 'Unable to verify state ID' },
            vendor_name: 'TestAAMVA',
            checked_at: Time.zone.now.iso8601,
          }
        end

        before do
          document_capture_session.create_proofing_session
          document_capture_session.store_proofing_result(failed_result)
          subject.idv_session.ipp_aamva_document_capture_session_uuid =
            document_capture_session.uuid
          # Simulate user at max attempts - 1, so after increment they're at max
          rate_limiter = RateLimiter.new(user:, rate_limit_type: :idv_doc_auth)
          (RateLimiter.max_attempts(:idv_doc_auth) - 1).times { rate_limiter.increment! }
        end

        it 'redirects to rate limit error page' do
          get :show

          expect(response).to redirect_to(idv_session_errors_rate_limited_url)
        end

        it 'clears the async state' do
          get :show

          expect(subject.idv_session.ipp_aamva_document_capture_session_uuid).to be_nil
        end

        it 'logs rate limit event' do
          get :show

          expect(@analytics).to have_logged_event(
            'Rate Limit Reached',
            limiter_type: :idv_doc_auth,
            step_name: 'ipp_state_id',
          )
        end

        it 'logs completion event with failure before rate limit redirect' do
          get :show

          expect(@analytics).to have_logged_event(
            :idv_ipp_aamva_verification_completed,
            success: false,
            vendor_name: 'TestAAMVA',
            step: 'state_id',
          )
        end
      end

      context 'when async AAMVA check fails' do
        let(:document_capture_session) do
          create(:document_capture_session, user:, requested_at: Time.zone.now)
        end

        let(:failed_result) do
          {
            success: false,
            errors: { state_id: 'Unable to verify state ID' },
            vendor_name: 'TestAAMVA',
            checked_at: Time.zone.now.iso8601,
          }
        end

        before do
          document_capture_session.create_proofing_session
          document_capture_session.store_proofing_result(failed_result)
          subject.idv_session.ipp_aamva_document_capture_session_uuid =
            document_capture_session.uuid
        end

        it 'does not redirect to SSN page' do
          get :show

          expect(response).to render_template(:show)
        end

        it 'displays an error message' do
          get :show

          expect(flash.now[:error]).to eq(I18n.t('idv.failure.verify.heading'))
        end

        it 'clears the async state' do
          get :show

          expect(subject.idv_session.ipp_aamva_document_capture_session_uuid).to be_nil
        end

        it 'logs completion event with failure' do
          get :show

          expect(@analytics).to have_logged_event(
            :idv_ipp_aamva_verification_completed,
            success: false,
            vendor_name: 'TestAAMVA',
            step: 'state_id',
          )
        end

        it 'does not commit pending PII to pii_from_user on failure' do
          # Set up pending PII as if form was just submitted
          subject.idv_session.ipp_aamva_pending_state_id_pii = {
            first_name: 'Charity',
            last_name: 'Johnson',
            same_address_as_id: 'true',
          }

          get :show

          # PII should NOT be committed to pii_from_user
          pii = subject.user_session['idv/in_person'][:pii_from_user]
          expect(pii[:first_name]).to be_nil
        end

        it 'preserves pending PII on failure so form is pre-filled' do
          subject.idv_session.ipp_aamva_pending_state_id_pii = {
            first_name: 'Charity',
            last_name: 'Johnson',
            same_address_as_id: 'true',
          }

          get :show

          # Pending PII should be preserved so form shows user's data
          expect(subject.idv_session.ipp_aamva_pending_state_id_pii).to be_present
          expect(subject.idv_session.ipp_aamva_pending_state_id_pii[:first_name]).to eq('Charity')
        end
      end

      context 'when async AAMVA state is none' do
        before do
          subject.idv_session.ipp_aamva_document_capture_session_uuid = nil
        end

        it 'renders the show page' do
          get :show

          expect(response).to render_template(:show)
        end

        it 'logs state_id visited event' do
          get :show

          expect(@analytics).to have_logged_event(
            'IdV: in person proofing state_id visited',
            analytics_id: 'In Person Proofing',
            flow_path: 'standard',
            step: 'state_id',
            opted_in_to_in_person_proofing: true,
          )
        end
      end

      context 'when async AAMVA state is missing' do
        let(:document_capture_session) do
          create(:document_capture_session, user:, requested_at: Time.zone.now)
        end

        before do
          # Create DCS but don't store any proofing result (simulates expired Redis data)
          subject.idv_session.ipp_aamva_document_capture_session_uuid =
            document_capture_session.uuid
        end

        it 'renders the show page with error' do
          get :show

          expect(response).to render_template(:show)
          expect(flash[:error]).to eq(I18n.t('idv.failure.timeout'))
        end

        it 'clears the async state' do
          get :show

          expect(subject.idv_session.ipp_aamva_document_capture_session_uuid).to be_nil
        end

        it 'preserves pending PII so form is pre-filled' do
          subject.idv_session.ipp_aamva_pending_state_id_pii = {
            first_name: 'Charity',
            last_name: 'Johnson',
            same_address_as_id: 'true',
          }

          get :show

          expect(subject.idv_session.ipp_aamva_pending_state_id_pii).to be_present
          expect(subject.idv_session.ipp_aamva_pending_state_id_pii[:first_name]).to eq('Charity')
        end

        it 'logs missing result event' do
          get :show

          expect(@analytics).to have_logged_event(:idv_ipp_aamva_proofing_result_missing)
        end
      end

      context 'when AAMVA is disabled' do
        before do
          allow(IdentityConfig.store).to receive(:idv_aamva_at_doc_auth_ipp_enabled)
            .and_return(false)
        end

        it 'does not enqueue job' do
          expect(IppAamvaProofingJob).not_to receive(:perform_later)

          put :update, params: params
        end

        it 'redirects directly to SSN page' do
          put :update, params: params

          expect(response).to redirect_to(idv_in_person_ssn_url)
        end
      end
    end

    context 'when redirecting to Address page (same_address_as_id is false)' do
      let(:params) { valid_state_id_params(same_address_as_id: 'false') }

      it 'enqueues AAMVA job and redirects to state_id page for polling' do
        expect(IppAamvaProofingJob).to receive(:perform_later)

        put :update, params: params

        expect(response).to redirect_to(idv_in_person_state_id_url)
        expect(subject.idv_session.ipp_aamva_document_capture_session_uuid).to be_present
        expect(subject.idv_session.ipp_aamva_redirect_url).to eq(idv_in_person_address_url)
      end

      context 'when async AAMVA check completes successfully' do
        let(:document_capture_session) do
          create(:document_capture_session, user:, requested_at: Time.zone.now)
        end

        let(:successful_result) do
          {
            success: true,
            errors: {},
            vendor_name: 'TestAAMVA',
            checked_at: Time.zone.now.iso8601,
          }
        end

        before do
          document_capture_session.create_proofing_session
          document_capture_session.store_proofing_result(successful_result)
          subject.idv_session.ipp_aamva_document_capture_session_uuid =
            document_capture_session.uuid
          subject.idv_session.ipp_aamva_redirect_url = idv_in_person_address_url
        end

        it 'redirects to Address page (not SSN)' do
          get :show

          expect(response).to redirect_to(idv_in_person_address_url)
        end

        it 'stores AAMVA result in idv_session' do
          get :show

          expect(subject.idv_session.ipp_aamva_result).to be_present
          expect(subject.idv_session.ipp_aamva_result['success']).to eq(true)
        end

        it 'clears the async state and redirect URL' do
          get :show

          expect(subject.idv_session.ipp_aamva_document_capture_session_uuid).to be_nil
          expect(subject.idv_session.ipp_aamva_redirect_url).to be_nil
        end
      end
    end

    context 'when rate limited' do
      let(:params) { valid_state_id_params(same_address_as_id: 'true') }

      before do
        allow(subject).to receive(:idv_attempter_rate_limited?).with(:idv_doc_auth).and_return(true)
      end

      it 'redirects to rate limit error page' do
        put :update, params: params

        expect(response).to redirect_to(idv_session_errors_rate_limited_url)
      end

      it 'logs rate limit event' do
        put :update, params: params

        expect(@analytics).to have_logged_event(
          'Rate Limit Reached',
          limiter_type: :idv_doc_auth,
          step_name: 'ipp_state_id',
        )
      end

      it 'does not enqueue AAMVA job when rate limited' do
        expect(IppAamvaProofingJob).not_to receive(:perform_later)

        put :update, params: params
      end
    end

    context 'rate limiter increment' do
      let(:params) { valid_state_id_params(same_address_as_id: 'true') }
      let(:document_capture_session) do
        create(:document_capture_session, user:, requested_at: Time.zone.now)
      end

      let(:successful_result) do
        {
          success: true,
          errors: {},
          vendor_name: 'TestAAMVA',
          checked_at: Time.zone.now.iso8601,
        }
      end

      it 'increments rate limiter when async AAMVA result is processed' do
        document_capture_session.create_proofing_session
        document_capture_session.store_proofing_result(successful_result)
        subject.idv_session.ipp_aamva_document_capture_session_uuid =
          document_capture_session.uuid

        expect { get :show }.to(
          change { RateLimiter.new(user:, rate_limit_type: :idv_doc_auth).remaining_count }.by(-1),
        )
      end

      it 'does not increment rate limiter when already rate limited' do
        allow(subject).to receive(:idv_attempter_rate_limited?).with(:idv_doc_auth).and_return(true)
        RateLimiter.new(user:, rate_limit_type: :idv_doc_auth).increment_to_limited!

        expect { put :update, params: params }.not_to(
          change { RateLimiter.new(user:, rate_limit_type: :idv_doc_auth).remaining_count },
        )
      end
    end
  end
end
