require 'rails_helper'
require 'csv'

RSpec.feature 'Analytics Regression', :js do
  include IdvStepHelper
  include InPersonHelper

  let(:user) { user_with_2fa }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:proofing_device_profiling) { :enabled }
  let(:threatmetrix) { true }
  let(:idv_level) { 'in_person' }

  let(:threatmetrix_response_body) do
    {
      account_lex_id: 'super-cool-test-lex-id',
      'fraudpoint.score': '500',
      request_id: '1234',
      request_result: 'success',
      review_status: 'pass',
      risk_rating: 'trusted',
      session_id: 'super-cool-test-session-id',
      summary_risk_score: '-6',
      tmx_risk_rating: 'neutral',
      tmx_summary_reason_code: ['Identity_Negative_History'],
    }
  end

  let(:threatmetrix_response) do
    {
      client: nil,
      errors: {},
      exception: nil,
      review_status: 'pass',
      account_lex_id: 'super-cool-test-lex-id',
      session_id: 'super-cool-test-session-id',
      success: true,
      timed_out: false,
      transaction_id: 'ddp-mock-transaction-id-123',
    }
  end

  let(:base_proofing_components) do
    {
      document_check: 'mock',
      document_type: 'drivers_license',
      source_check: 'StateIdMock',
      resolution_check: 'ResolutionMock',
      residential_resolution_check: 'ResidentialAddressNotRequired',
      threatmetrix: threatmetrix,
      threatmetrix_review_status: 'pass',
    }
  end

  let(:lexis_nexis_address_proofing_components) do
    base_proofing_components.merge(address_check: 'lexis_nexis_address')
  end

  let(:gpo_letter_proofing_components) do
    base_proofing_components.merge(address_check: 'gpo_letter')
  end

  let(:state_id_resolution) do
    { success: true,
      errors: {},
      exception: nil,
      mva_exception: nil,
      requested_attributes: {},
      timed_out: false,
      transaction_id: 'state-id-mock-transaction-id-456',
      vendor_name: 'StateIdMock',
      verified_attributes: [],
      state: 'MT',
      state_id_jurisdiction: 'ND',
      state_id_number: '#############',
      jurisdiction_in_maintenance_window: false }
  end

  let(:state_id_resolution_with_id_type) do
    state_id_resolution.merge(id_doc_type: 'drivers_license')
  end

  let(:resolution_block) do
    { success: true,
      errors: {},
      exception: nil,
      timed_out: false,
      transaction_id: 'resolution-mock-transaction-id-123',
      reference: 'aaa-bbb-ccc',
      can_pass_with_additional_verification: false,
      attributes_requiring_additional_verification: [],
      vendor_name: 'ResolutionMock',
      vendor_workflow: nil,
      verified_attributes: nil }
  end

  let(:base_proofing_results) do
    {
      exception: nil,
      ssn_is_unique: true,
      timed_out: false,
      threatmetrix_review_status: 'pass',
      phone_finder_precheck_passed: false,
      context: {
        device_profiling_adjudication_reason: 'device_profiling_result_pass',
        resolution_adjudication_reason: 'pass_resolution_and_state_id',
        should_proof_state_id: true,
        stages: {
          resolution: resolution_block,
          residential_address: { attributes_requiring_additional_verification: [],
                                 can_pass_with_additional_verification: false,
                                 errors: {},
                                 exception: nil,
                                 reference: '',
                                 success: true,
                                 timed_out: false,
                                 transaction_id: '',
                                 vendor_name: 'ResidentialAddressNotRequired',
                                 vendor_workflow: nil,
                                 verified_attributes: nil },
          state_id: state_id_resolution,
          threatmetrix: threatmetrix_response,
          phone_precheck: { attributes_requiring_additional_verification: [],
                            can_pass_with_additional_verification: false,
                            errors: {},
                            exception: nil,
                            reference: '',
                            success: false,
                            timed_out: false,
                            transaction_id: '',
                            vendor_name: 'NoPhoneNumberAvailable',
                            vendor_workflow: nil,
                            verified_attributes: nil },
        },
      },
      biographical_info: {
        birth_year: 1938,
        identity_doc_address_state: nil,
        state: 'MT',
        state_id_jurisdiction: 'ND',
        state_id_number: '#############',
      },
    }
  end

  let(:doc_auth_verify_proofing_results) do
    base_proofing_results.deep_merge(
      context: { stages: { state_id: state_id_resolution_with_id_type } },
    )
  end

  let(:in_person_path_proofing_results) do
    {
      exception: nil,
      ssn_is_unique: true,
      timed_out: false,
      threatmetrix_review_status: 'pass',
      phone_finder_precheck_passed: false,
      context: {
        device_profiling_adjudication_reason: 'device_profiling_result_pass',
        resolution_adjudication_reason: 'pass_resolution_and_state_id',
        should_proof_state_id: true,
        stages: {
          resolution: resolution_block,
          residential_address: { errors: {},
                                 exception: nil,
                                 reference: 'aaa-bbb-ccc',
                                 success: true,
                                 timed_out: false,
                                 transaction_id: 'resolution-mock-transaction-id-123',
                                 can_pass_with_additional_verification: false,
                                 attributes_requiring_additional_verification: [],
                                 vendor_name: 'ResolutionMock',
                                 vendor_workflow: nil,
                                 verified_attributes: nil },
          state_id: state_id_resolution,
          threatmetrix: threatmetrix_response,
          phone_precheck: { attributes_requiring_additional_verification: [],
                            can_pass_with_additional_verification: false,
                            errors: {},
                            exception: nil,
                            reference: '',
                            success: false,
                            timed_out: false,
                            transaction_id: '',
                            vendor_name: 'PhoneIgnoredForInPersonProofing',
                            vendor_workflow: nil,
                            verified_attributes: nil },
        },
      },
      biographical_info: {
        birth_year: 1938,
        identity_doc_address_state: 'MT',
        state: 'MT',
        state_id_jurisdiction: 'ND',
        state_id_number: '#############',
      },
    }
  end

  # rubocop:disable Layout/LineLength
  # rubocop:disable Layout/MultilineHashKeyLineBreaks

  # Events format:
  #   For each event, please keep single properties together on the first line,
  #   and properties with sub-objects (like proofing_components) on a following line.

  let(:happy_path_events) do
    {
      'IdV: intro visited' => {},
      'IdV: doc auth welcome visited' => {
        step: 'welcome', analytics_id: 'Doc Auth', doc_auth_vendor: 'mock'
      },
      'IdV: doc auth welcome submitted' => {
        step: 'welcome', analytics_id: 'Doc Auth', doc_auth_vendor: 'mock'
      },
      'IdV: doc auth agreement visited' => {
        step: 'agreement', analytics_id: 'Doc Auth'
      },
      'IdV: consent checkbox toggled' => {
        checked: true,
      },
      'IdV: doc auth agreement submitted' => {
        success: true, step: 'agreement', analytics_id: 'Doc Auth'
      },
      'IdV: doc auth hybrid handoff visited' => {
        step: 'hybrid_handoff', analytics_id: 'Doc Auth', selfie_check_required: boolean
      },
      'IdV: doc auth hybrid handoff submitted' => {
        success: true, destination: :document_capture, flow_path: 'standard', step: 'hybrid_handoff', analytics_id: 'Doc Auth', selfie_check_required: boolean
      },
      'IdV: doc auth document_capture visited' => hash_including(flow_path: 'standard', step: 'document_capture', analytics_id: 'Doc Auth', selfie_check_required: boolean, liveness_checking_required: boolean),
      'Frontend: IdV: front image added' => {
        width: 284, height: 38, mimeType: 'image/png', source: 'upload', size: 3694, captureAttempts: 1, flow_path: 'standard', acuant_sdk_upgrade_a_b_testing_enabled: 'false', use_alternate_sdk: anything, acuant_version: kind_of(String), fingerprint: anything, failedImageResubmission: boolean, liveness_checking_required: boolean
      },
      'Frontend: IdV: back image added' => {
        width: 284, height: 38, mimeType: 'image/png', source: 'upload', size: 3694, captureAttempts: 1, flow_path: 'standard', acuant_sdk_upgrade_a_b_testing_enabled: 'false', use_alternate_sdk: anything, acuant_version: kind_of(String), fingerprint: anything, failedImageResubmission: boolean, liveness_checking_required: boolean
      },
      'IdV: doc auth image upload form submitted' => {
        success: true, submit_attempts: 1, remaining_submit_attempts: 3, user_id: user.uuid, flow_path: 'standard', front_image_fingerprint: an_instance_of(String), back_image_fingerprint: an_instance_of(String), liveness_checking_required: boolean, document_type: an_instance_of(String)
      },
      'IdV: doc auth image upload vendor submitted' => hash_including(success: true, flow_path: 'standard', attention_with_barcode: false, doc_auth_result: 'Passed', liveness_checking_required: boolean, document_type: an_instance_of(String), id_doc_type: an_instance_of(String)),
      'IdV: doc auth image upload vendor pii validation' => {
        success: true, user_id: user.uuid, submit_attempts: 1, remaining_submit_attempts: 3, flow_path: 'standard', attention_with_barcode: false, front_image_fingerprint: an_instance_of(String), back_image_fingerprint: an_instance_of(String), liveness_checking_required: boolean, classification_info: {}, id_issued_status: 'present', id_expiration_status: 'present', passport_issued_status: 'missing', passport_expiration_status: 'missing', document_type: an_instance_of(String), id_doc_type: an_instance_of(String)
      },
      'IdV: doc auth document_capture submitted' => hash_including(success: true, flow_path: 'standard', step: 'document_capture', analytics_id: 'Doc Auth', selfie_check_required: boolean, liveness_checking_required: boolean, proofing_components: { document_check: 'mock', document_type: 'drivers_license' }),
      'IdV: doc auth ssn visited' => {
        flow_path: 'standard', step: 'ssn', analytics_id: 'Doc Auth',
        proofing_components: { document_check: 'mock', document_type: 'drivers_license' }
      },
      'IdV: doc auth ssn submitted' => {
        success: true, flow_path: 'standard', step: 'ssn', analytics_id: 'Doc Auth',
        proofing_components: { document_check: 'mock', document_type: 'drivers_license' }
      },
      'IdV: doc auth verify visited' => {
        flow_path: 'standard', step: 'verify', analytics_id: 'Doc Auth',
        proofing_components: { document_check: 'mock', document_type: 'drivers_license' }
      },
      'IdV: doc auth verify submitted' => {
        flow_path: 'standard', step: 'verify', analytics_id: 'Doc Auth',
        proofing_components: { document_check: 'mock', document_type: 'drivers_license' }
      },
      idv_threatmetrix_response_body: (
        if threatmetrix_response_body.present?
          { response_body: threatmetrix_response_body }
        end
      ),
      'IdV: doc auth verify proofing results' => {
        success: true, flow_path: 'standard', address_edited: false, address_line2_present: false, last_name_spaced: false, analytics_id: 'Doc Auth', step: 'verify',
        proofing_results: doc_auth_verify_proofing_results,
        proofing_components: base_proofing_components
      },
      'IdV: phone of record visited' => {
        proofing_components: base_proofing_components,
      },
      'IdV: phone confirmation form' => {
        success: true, phone_type: :mobile, types: [:fixed_or_mobile], carrier: 'Test Mobile Carrier', country_code: 'US', area_code: '202', otp_delivery_preference: 'sms',
        proofing_components: base_proofing_components
      },
      'IdV: phone confirmation vendor' => {
        success: true, vendor: { exception: nil, vendor_name: 'AddressMock', transaction_id: 'address-mock-transaction-id-123', timed_out: false, reference: '' }, new_phone_added: false, hybrid_handoff_phone_used: false, area_code: '202', country_code: 'US', phone_fingerprint: anything,
        proofing_components: lexis_nexis_address_proofing_components
      },
      'IdV: phone confirmation otp sent' => {
        success: true, otp_delivery_preference: :sms, country_code: 'US', area_code: '202', adapter: :test, phone_fingerprint: anything, rate_limit_exceeded: false, telephony_response: anything,
        proofing_components: lexis_nexis_address_proofing_components
      },
      'IdV: phone confirmation otp visited' => {
        proofing_components: lexis_nexis_address_proofing_components,
      },
      'IdV: phone confirmation otp submitted' => {
        success: true, code_expired: false, code_matches: true, otp_delivery_preference: :sms, second_factor_attempts_count: 0,
        proofing_components: lexis_nexis_address_proofing_components
      },
      :idv_enter_password_visited => {
        address_verification_method: 'phone',
        proofing_components: lexis_nexis_address_proofing_components,
      },
      :idv_enter_password_submitted => {
        success: true, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: false, in_person_verification_pending: false, proofing_workflow_time_in_seconds: 0.0,
        active_profile_idv_level: 'legacy_unsupervised',
        proofing_components: lexis_nexis_address_proofing_components
      },
      'IdV: final resolution' => {
        success: true, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: false, in_person_verification_pending: false, proofing_workflow_time_in_seconds: 0.0,
        active_profile_idv_level: 'legacy_unsupervised',
        profile_history: match_array(kind_of(Idv::ProfileLogging)),
        proofing_components: lexis_nexis_address_proofing_components
      },
      'IdV: personal key visited' => {
        address_verification_method: 'phone', encrypted_profiles_missing: false, in_person_verification_pending: false,
        active_profile_idv_level: 'legacy_unsupervised',
        proofing_components: lexis_nexis_address_proofing_components
      },
      'IdV: personal key acknowledgment toggled' => {
        checked: true,
        active_profile_idv_level: 'legacy_unsupervised',
        proofing_components: lexis_nexis_address_proofing_components,
      },
      'IdV: personal key submitted' => {
        address_verification_method: 'phone', fraud_review_pending: false, fraud_rejection: false, in_person_verification_pending: false,
        active_profile_idv_level: 'legacy_unsupervised',
        proofing_components: lexis_nexis_address_proofing_components
      },
    }.compact
  end

  # TODO: Add ["IdV: doc auth link_sent visited", "IdV: doc auth capture_complete visited", "IdV: doc auth link_sent submitted"]
  let(:happy_hybrid_path_events) do
    {
      'IdV: intro visited' => {},
      'IdV: doc auth welcome visited' => {
        step: 'welcome', analytics_id: 'Doc Auth', doc_auth_vendor: 'mock'
      },
      'IdV: doc auth welcome submitted' => {
        step: 'welcome', analytics_id: 'Doc Auth', doc_auth_vendor: 'mock'
      },
      'IdV: doc auth agreement visited' => {
        step: 'agreement', analytics_id: 'Doc Auth'
      },
      'IdV: consent checkbox toggled' => {
        checked: true,
      },
      'IdV: doc auth agreement submitted' => {
        success: true, step: 'agreement', analytics_id: 'Doc Auth'
      },
      'IdV: doc auth hybrid handoff visited' => {
        step: 'hybrid_handoff', analytics_id: 'Doc Auth', selfie_check_required: boolean
      },
      'IdV: doc auth hybrid handoff submitted' => {
        success: true, errors: hash_including(message: nil), destination: :link_sent, flow_path: 'hybrid', step: 'hybrid_handoff', analytics_id: 'Doc Auth', telephony_response: hash_including(errors: {}, message_id: 'fake-message-id', request_id: 'fake-message-request-id', success: true), selfie_check_required: boolean
      },
      'IdV: doc auth document_capture visited' => {
        flow_path: 'hybrid', step: 'document_capture', analytics_id: 'Doc Auth', selfie_check_required: boolean, liveness_checking_required: boolean
      },
      'Frontend: IdV: front image added' => {
        width: 284, height: 38, mimeType: 'image/png', source: 'upload', size: 3694, captureAttempts: 1, flow_path: 'hybrid', acuant_sdk_upgrade_a_b_testing_enabled: 'false', use_alternate_sdk: anything, acuant_version: kind_of(String), fingerprint: anything, failedImageResubmission: boolean, liveness_checking_required: boolean
      },
      'Frontend: IdV: back image added' => {
        width: 284, height: 38, mimeType: 'image/png', source: 'upload', size: 3694, captureAttempts: 1, flow_path: 'hybrid', acuant_sdk_upgrade_a_b_testing_enabled: 'false', use_alternate_sdk: anything, acuant_version: kind_of(String), fingerprint: anything, failedImageResubmission: boolean, liveness_checking_required: boolean
      },
      'IdV: doc auth image upload form submitted' => {
        success: true, submit_attempts: 1, remaining_submit_attempts: 3, user_id: user.uuid, flow_path: 'hybrid', front_image_fingerprint: an_instance_of(String), back_image_fingerprint: an_instance_of(String), liveness_checking_required: boolean, document_type: an_instance_of(String)
      },
      'IdV: doc auth image upload vendor submitted' => hash_including(success: true, flow_path: 'hybrid', attention_with_barcode: false, doc_auth_result: 'Passed', liveness_checking_required: boolean, id_doc_type: an_instance_of(String)),
      'IdV: doc auth image upload vendor pii validation' => {
        success: true, user_id: user.uuid, submit_attempts: 1, remaining_submit_attempts: 3, flow_path: 'hybrid', attention_with_barcode: false, front_image_fingerprint: an_instance_of(String), back_image_fingerprint: an_instance_of(String), liveness_checking_required: boolean, classification_info: {}, id_issued_status: 'present', id_expiration_status: 'present', passport_issued_status: 'missing', passport_expiration_status: 'missing', document_type: an_instance_of(String), id_doc_type: an_instance_of(String)
      },
      'IdV: doc auth document_capture submitted' => {
        success: true, flow_path: 'hybrid', step: 'document_capture', analytics_id: 'Doc Auth', selfie_check_required: boolean, liveness_checking_required: boolean
      },
      'IdV: doc auth ssn visited' => {
        flow_path: 'hybrid', step: 'ssn', analytics_id: 'Doc Auth',
        proofing_components: { document_check: 'mock', document_type: 'drivers_license' }
      },
      'IdV: doc auth ssn submitted' => {
        success: true, flow_path: 'hybrid', step: 'ssn', analytics_id: 'Doc Auth',
        proofing_components: { document_check: 'mock', document_type: 'drivers_license' }
      },
      'IdV: doc auth verify visited' => {
        flow_path: 'hybrid', step: 'verify', analytics_id: 'Doc Auth',
        proofing_components: { document_check: 'mock', document_type: 'drivers_license' }
      },
      'IdV: doc auth verify submitted' => {
        flow_path: 'hybrid', step: 'verify', analytics_id: 'Doc Auth',
        proofing_components: { document_check: 'mock', document_type: 'drivers_license' }
      },
      idv_threatmetrix_response_body: (
        if threatmetrix_response_body.present?
          { response_body: threatmetrix_response_body }
        end
      ),
      'IdV: doc auth verify proofing results' => {
        success: true, flow_path: 'hybrid', address_edited: false, address_line2_present: false, last_name_spaced: false, analytics_id: 'Doc Auth', step: 'verify',
        proofing_results: doc_auth_verify_proofing_results,
        proofing_components: base_proofing_components
      },
      'IdV: phone of record visited' => {
        proofing_components: base_proofing_components,
      },
      'IdV: phone confirmation form' => {
        success: true, phone_type: :mobile, types: [:fixed_or_mobile], carrier: 'Test Mobile Carrier', country_code: 'US', area_code: '202', otp_delivery_preference: 'sms',
        proofing_components: base_proofing_components
      },
      'IdV: phone confirmation vendor' => {
        success: true, vendor: { exception: nil, vendor_name: 'AddressMock', transaction_id: 'address-mock-transaction-id-123', timed_out: false, reference: '' }, new_phone_added: false, hybrid_handoff_phone_used: true, area_code: '202', country_code: 'US', phone_fingerprint: anything,
        proofing_components: lexis_nexis_address_proofing_components
      },
      'IdV: phone confirmation otp sent' => {
        success: true, otp_delivery_preference: :sms, country_code: 'US', area_code: '202', adapter: :test, phone_fingerprint: anything, rate_limit_exceeded: false, telephony_response: anything,
        proofing_components: lexis_nexis_address_proofing_components
      },
      'IdV: phone confirmation otp visited' => {
        proofing_components: lexis_nexis_address_proofing_components,
      },
      'IdV: phone confirmation otp submitted' => {
        success: true, code_expired: false, code_matches: true, otp_delivery_preference: :sms, second_factor_attempts_count: 0,
        proofing_components: lexis_nexis_address_proofing_components
      },
      :idv_enter_password_visited => {
        address_verification_method: 'phone',
        proofing_components: lexis_nexis_address_proofing_components,
      },
      :idv_enter_password_submitted => {
        success: true, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: false, in_person_verification_pending: false, proofing_workflow_time_in_seconds: 0.0,
        active_profile_idv_level: 'legacy_unsupervised',
        proofing_components: lexis_nexis_address_proofing_components
      },
      'IdV: final resolution' => {
        success: true, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: false, in_person_verification_pending: false, proofing_workflow_time_in_seconds: 0.0,
        active_profile_idv_level: 'legacy_unsupervised',
        profile_history: match_array(kind_of(Idv::ProfileLogging)),
        proofing_components: lexis_nexis_address_proofing_components
      },
      'IdV: personal key visited' => {
        address_verification_method: 'phone', encrypted_profiles_missing: false, in_person_verification_pending: false,
        active_profile_idv_level: 'legacy_unsupervised',
        proofing_components: lexis_nexis_address_proofing_components
      },
      'IdV: personal key acknowledgment toggled' => {
        checked: true,
        active_profile_idv_level: 'legacy_unsupervised',
        proofing_components: lexis_nexis_address_proofing_components,
      },
      'IdV: personal key submitted' => {
        address_verification_method: 'phone', fraud_review_pending: false, fraud_rejection: false, in_person_verification_pending: false,
        active_profile_idv_level: 'legacy_unsupervised',
        proofing_components: lexis_nexis_address_proofing_components
      },
    }.compact
  end

  # TODO: Add ["IdV: consent checkbox toggled"]
  let(:gpo_path_events) do
    {
      'IdV: intro visited' => {},
      'IdV: doc auth welcome visited' => {
        step: 'welcome', analytics_id: 'Doc Auth', doc_auth_vendor: 'mock'
      },
      'IdV: doc auth welcome submitted' => {
        step: 'welcome', analytics_id: 'Doc Auth', doc_auth_vendor: 'mock'
      },
      'IdV: doc auth agreement visited' => {
        step: 'agreement', analytics_id: 'Doc Auth'
      },
      'IdV: doc auth agreement submitted' => {
        success: true, step: 'agreement', analytics_id: 'Doc Auth'
      },
      'IdV: doc auth hybrid handoff visited' => {
        step: 'hybrid_handoff', analytics_id: 'Doc Auth', selfie_check_required: boolean
      },
      'IdV: doc auth hybrid handoff submitted' => {
        success: true, destination: :document_capture, flow_path: 'standard', step: 'hybrid_handoff', analytics_id: 'Doc Auth', selfie_check_required: boolean
      },
      'IdV: doc auth document_capture visited' => {
        flow_path: 'standard', step: 'document_capture', analytics_id: 'Doc Auth', selfie_check_required: boolean, liveness_checking_required: boolean
      },
      'Frontend: IdV: front image added' => {
        width: 284, height: 38, mimeType: 'image/png', source: 'upload', size: 3694, captureAttempts: 1, flow_path: 'standard', acuant_sdk_upgrade_a_b_testing_enabled: 'false', use_alternate_sdk: anything, acuant_version: kind_of(String), fingerprint: anything, failedImageResubmission: boolean, liveness_checking_required: boolean
      },
      'Frontend: IdV: back image added' => {
        width: 284, height: 38, mimeType: 'image/png', source: 'upload', size: 3694, captureAttempts: 1, flow_path: 'standard', acuant_sdk_upgrade_a_b_testing_enabled: 'false', use_alternate_sdk: anything, acuant_version: kind_of(String), fingerprint: anything, failedImageResubmission: boolean, liveness_checking_required: boolean
      },
      'IdV: doc auth image upload form submitted' => {
        success: true, submit_attempts: 1, remaining_submit_attempts: 3, user_id: user.uuid, flow_path: 'standard', front_image_fingerprint: an_instance_of(String), back_image_fingerprint: an_instance_of(String), liveness_checking_required: boolean, document_type: an_instance_of(String)
      },
      'IdV: doc auth image upload vendor submitted' => hash_including(success: true, flow_path: 'standard', attention_with_barcode: false, doc_auth_result: 'Passed', liveness_checking_required: boolean, id_doc_type: an_instance_of(String)),
      'IdV: doc auth image upload vendor pii validation' => {
        success: true, user_id: user.uuid, submit_attempts: 1, remaining_submit_attempts: 3, flow_path: 'standard', attention_with_barcode: false, front_image_fingerprint: an_instance_of(String), back_image_fingerprint: an_instance_of(String), liveness_checking_required: boolean, classification_info: {}, id_issued_status: 'present', id_expiration_status: 'present', passport_issued_status: 'missing', passport_expiration_status: 'missing', document_type: an_instance_of(String), id_doc_type: an_instance_of(String)
      },
      'IdV: doc auth document_capture submitted' => {
        success: true, flow_path: 'standard', step: 'document_capture', analytics_id: 'Doc Auth', selfie_check_required: boolean, liveness_checking_required: boolean,
        proofing_components: { document_check: 'mock', document_type: 'drivers_license' }
      },
      'IdV: doc auth ssn visited' => {
        flow_path: 'standard', step: 'ssn', analytics_id: 'Doc Auth',
        proofing_components: { document_check: 'mock', document_type: 'drivers_license' }
      },
      'IdV: doc auth ssn submitted' => {
        success: true, flow_path: 'standard', step: 'ssn', analytics_id: 'Doc Auth',
        proofing_components: { document_check: 'mock', document_type: 'drivers_license' }
      },
      'IdV: doc auth verify visited' => {
        flow_path: 'standard', step: 'verify', analytics_id: 'Doc Auth',
        proofing_components: { document_check: 'mock', document_type: 'drivers_license' }
      },
      'IdV: doc auth verify submitted' => {
        flow_path: 'standard', step: 'verify', analytics_id: 'Doc Auth',
        proofing_components: { document_check: 'mock', document_type: 'drivers_license' }
      },
      idv_threatmetrix_response_body: (
        if threatmetrix_response_body.present?
          { response_body: threatmetrix_response_body }
        end
      ),
      'IdV: doc auth verify proofing results' => {
        success: true, flow_path: 'standard', address_edited: false, address_line2_present: false, last_name_spaced: false, analytics_id: 'Doc Auth', step: 'verify',
        proofing_results: doc_auth_verify_proofing_results,
        proofing_components: base_proofing_components
      },
      'IdV: phone of record visited' => {
        proofing_components: base_proofing_components,
      },
      'IdV: USPS address letter requested' => {
        resend: false, phone_step_attempts: 0, hours_since_first_letter: 0,
        proofing_components: base_proofing_components
      },
      'IdV: request letter visited' => {
        proofing_components: base_proofing_components,
      },
      :idv_enter_password_visited => {
        address_verification_method: 'gpo',
        proofing_components: gpo_letter_proofing_components,
      },
      'IdV: USPS address letter enqueued' => {
        enqueued_at: Time.zone.now.utc, resend: false, phone_step_attempts: 0, first_letter_requested_at: Time.zone.now.utc, hours_since_first_letter: 0,
        proofing_components: gpo_letter_proofing_components
      },
      :idv_enter_password_submitted => {
        success: true, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: true, in_person_verification_pending: false, proofing_workflow_time_in_seconds: 0.0,
        proofing_components: gpo_letter_proofing_components
      },
      'IdV: final resolution' => {
        success: true, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: true, in_person_verification_pending: false, proofing_workflow_time_in_seconds: 0.0,
        # NOTE: pending_profile_idv_level should be set here, a nil value is cached for current_user.pending_profile.
        profile_history: match_array(kind_of(Idv::ProfileLogging)),
        proofing_components: gpo_letter_proofing_components
      },
      'IdV: letter enqueued visited' => {
        pending_profile_idv_level: 'legacy_unsupervised',
        proofing_components: gpo_letter_proofing_components,
      },
    }.compact
  end

  # TODO: Add ["IdV: consent checkbox toggled", "IdV: doc auth image upload vendor pii validation", "IdV: in person proofing location search submitted", "IdV: phone of record visited"]
  let(:in_person_path_events) do
    {
      'IdV: doc auth welcome visited' => {
        step: 'welcome', analytics_id: 'Doc Auth', doc_auth_vendor: 'mock'
      },
      'IdV: doc auth welcome submitted' => {
        step: 'welcome', analytics_id: 'Doc Auth', doc_auth_vendor: 'mock'
      },
      'IdV: doc auth agreement visited' => {
        step: 'agreement', analytics_id: 'Doc Auth'
      },
      'IdV: doc auth agreement submitted' => {
        success: true, step: 'agreement', analytics_id: 'Doc Auth'
      },
      'IdV: doc auth hybrid handoff visited' => {
        step: 'hybrid_handoff', analytics_id: 'Doc Auth', selfie_check_required: boolean
      },
      'IdV: doc auth hybrid handoff submitted' => {
        success: true, destination: :document_capture, flow_path: 'standard', step: 'hybrid_handoff', analytics_id: 'Doc Auth', selfie_check_required: boolean
      },
      'IdV: doc auth document_capture visited' => {
        flow_path: 'standard', step: 'document_capture', analytics_id: 'Doc Auth', selfie_check_required: boolean, liveness_checking_required: boolean
      },
      'Frontend: IdV: front image added' => {
        width: 284, height: 38, mimeType: 'image/png', source: 'upload', size: 3694, captureAttempts: 1, flow_path: 'standard', acuant_sdk_upgrade_a_b_testing_enabled: 'false', use_alternate_sdk: anything, acuant_version: kind_of(String), fingerprint: anything, failedImageResubmission: boolean, liveness_checking_required: boolean
      },
      'Frontend: IdV: back image added' => {
        width: 284, height: 38, mimeType: 'image/png', source: 'upload', size: 3694, captureAttempts: 1, flow_path: 'standard', acuant_sdk_upgrade_a_b_testing_enabled: 'false', use_alternate_sdk: anything, acuant_version: kind_of(String), fingerprint: anything, failedImageResubmission: boolean, liveness_checking_required: boolean
      },
      'IdV: doc auth image upload form submitted' => {
        success: true, submit_attempts: 1, remaining_submit_attempts: 3, user_id: user.uuid, flow_path: 'standard', front_image_fingerprint: an_instance_of(String), back_image_fingerprint: an_instance_of(String), liveness_checking_required: boolean, document_type: an_instance_of(String)
      },
      'IdV: doc auth image upload vendor submitted' => hash_including(success: true, flow_path: 'standard', attention_with_barcode: true, doc_auth_result: 'Attention', liveness_checking_required: boolean, id_doc_type: an_instance_of(String)),
      'IdV: verify in person troubleshooting option clicked' => {
        flow_path: 'standard', opted_in_to_in_person_proofing: false, submit_attempts: 1
      },
      'IdV: in person proofing location visited' => {
        flow_path: 'standard', opted_in_to_in_person_proofing: false
      },
      'IdV: in person proofing location submitted' => {
        flow_path: 'standard', selected_location: '606 E JUNEAU AVE, MILWAUKEE, WI, 53202-9998', opted_in_to_in_person_proofing: false
      },
      'IdV: in person proofing prepare visited' => {
        flow_path: 'standard', opted_in_to_in_person_proofing: false
      },
      'IdV: in person proofing prepare submitted' => {
        flow_path: 'standard', opted_in_to_in_person_proofing: false
      },
      'IdV: in person proofing state_id visited' => {
        step: 'state_id', flow_path: 'standard', analytics_id: 'In Person Proofing'
      },
      'IdV: in person proofing state_id submitted' => {
        success: true, flow_path: 'standard', step: 'state_id', analytics_id: 'In Person Proofing', birth_year: '1938', document_zip_code: '12345', proofing_components: { document_check: 'usps' }
      },
      'IdV: in person proofing address visited' => {
        step: 'address', flow_path: 'standard', analytics_id: 'In Person Proofing', proofing_components: { document_check: 'usps' }
      },
      'IdV: in person proofing residential address submitted' => {
        success: true, step: 'address', flow_path: 'standard', analytics_id: 'In Person Proofing', current_address_zip_code: '59010', proofing_components: { document_check: 'usps' }
      },
      'IdV: doc auth ssn visited' => {
        analytics_id: 'In Person Proofing', step: 'ssn', flow_path: 'standard', proofing_components: { document_check: 'usps' }
      },
      'IdV: doc auth ssn submitted' => {
        analytics_id: 'In Person Proofing', success: true, step: 'ssn', flow_path: 'standard', proofing_components: { document_check: 'usps' }
      },
      'IdV: doc auth verify visited' => {
        analytics_id: 'In Person Proofing', step: 'verify', flow_path: 'standard', proofing_components: { document_check: 'usps' }
      },
      'IdV: doc auth verify submitted' => {
        analytics_id: 'In Person Proofing', step: 'verify', flow_path: 'standard', proofing_components: { document_check: 'usps' }
      },
      idv_threatmetrix_response_body: (
        if threatmetrix_response_body.present?
          { response_body: threatmetrix_response_body }
        end
      ),
      'IdV: doc auth verify proofing results' => {
        success: true, flow_path: 'standard', address_edited: false, address_line2_present: false, last_name_spaced: false, analytics_id: 'In Person Proofing', step: 'verify',
        proofing_results: in_person_path_proofing_results,
        proofing_components: { document_check: 'usps', resolution_check: 'ResolutionMock', residential_resolution_check: 'ResolutionMock', source_check: 'StateIdMock', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass' }
      },
      'IdV: phone confirmation form' => {
        success: true, phone_type: :mobile, types: [:fixed_or_mobile], carrier: 'Test Mobile Carrier', country_code: 'US', area_code: '202', otp_delivery_preference: 'sms',
        proofing_components: { document_check: 'usps', resolution_check: 'ResolutionMock', residential_resolution_check: 'ResolutionMock', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', source_check: 'StateIdMock' }
      },
      'IdV: phone confirmation vendor' => {
        success: true, vendor: { exception: nil, vendor_name: 'AddressMock', transaction_id: 'address-mock-transaction-id-123', timed_out: false, reference: '' }, new_phone_added: false, hybrid_handoff_phone_used: false, area_code: '202', country_code: 'US', phone_fingerprint: anything,
        proofing_components: { address_check: 'lexis_nexis_address', document_check: 'usps', resolution_check: 'ResolutionMock', residential_resolution_check: 'ResolutionMock', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', source_check: 'StateIdMock' }
      },
      'IdV: phone confirmation otp sent' => {
        success: true, otp_delivery_preference: :sms, country_code: 'US', area_code: '202', adapter: :test, phone_fingerprint: anything, rate_limit_exceeded: false, telephony_response: anything,
        proofing_components: { address_check: 'lexis_nexis_address', document_check: 'usps', resolution_check: 'ResolutionMock', residential_resolution_check: 'ResolutionMock', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', source_check: 'StateIdMock' }
      },
      'IdV: phone confirmation otp visited' => {
        proofing_components: { address_check: 'lexis_nexis_address', document_check: 'usps', resolution_check: 'ResolutionMock', residential_resolution_check: 'ResolutionMock', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', source_check: 'StateIdMock' },
      },
      'IdV: phone confirmation otp submitted' => {
        success: true, code_expired: false, code_matches: true, otp_delivery_preference: :sms, second_factor_attempts_count: 0,
        proofing_components: { document_check: 'usps', source_check: 'StateIdMock', resolution_check: 'ResolutionMock', residential_resolution_check: 'ResolutionMock', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      :idv_enter_password_visited => {
        address_verification_method: 'phone',
        proofing_components: { document_check: 'usps', source_check: 'StateIdMock', resolution_check: 'ResolutionMock', residential_resolution_check: 'ResolutionMock', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' },
      },
      :idv_enter_password_submitted => {
        success: true, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: false, in_person_verification_pending: true, proofing_workflow_time_in_seconds: 0.0,
        proofing_components: { document_check: 'usps', source_check: 'StateIdMock', resolution_check: 'ResolutionMock', residential_resolution_check: 'ResolutionMock', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      'IdV: final resolution' => {
        success: true, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: false, in_person_verification_pending: true, proofing_workflow_time_in_seconds: 0.0,
        # NOTE: pending_profile_idv_level should be set here, a nil value is cached for current_user.pending_profile.
        profile_history: match_array(kind_of(Idv::ProfileLogging)),
        proofing_components: { document_check: 'usps', source_check: 'StateIdMock', resolution_check: 'ResolutionMock', residential_resolution_check: 'ResolutionMock', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      'IdV: personal key visited' => {
        in_person_verification_pending: true,
        address_verification_method: 'phone',
        encrypted_profiles_missing: false, pending_profile_idv_level: idv_level,
        proofing_components: { document_check: 'usps', source_check: 'StateIdMock', resolution_check: 'ResolutionMock', residential_resolution_check: 'ResolutionMock', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      'IdV: personal key acknowledgment toggled' => {
        checked: true, pending_profile_idv_level: idv_level,
        proofing_components: { document_check: 'usps', source_check: 'StateIdMock', resolution_check: 'ResolutionMock', residential_resolution_check: 'ResolutionMock', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      'IdV: personal key submitted' => {
        address_verification_method: 'phone', fraud_review_pending: false, fraud_rejection: false, in_person_verification_pending: true, pending_profile_idv_level: idv_level,
        proofing_components: { document_check: 'usps', source_check: 'StateIdMock', resolution_check: 'ResolutionMock', residential_resolution_check: 'ResolutionMock', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      'IdV: in person ready to verify visited' => {
        pending_profile_idv_level: idv_level,
        proofing_components: { document_check: 'usps', source_check: 'StateIdMock', resolution_check: 'ResolutionMock', residential_resolution_check: 'ResolutionMock', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' },
      },
      'IdV: user clicked what to bring link on ready to verify page' => {},
      'IdV: user clicked sp link on ready to verify page' => {},
    }.compact
  end

  let(:happy_mobile_selfie_path_events) do
    {
      'IdV: intro visited' => {},
      'IdV: doc auth welcome visited' => {
        step: 'welcome', analytics_id: 'Doc Auth', doc_auth_vendor: 'mock'
      },
      'IdV: doc auth welcome submitted' => {
        step: 'welcome', analytics_id: 'Doc Auth', doc_auth_vendor: 'mock'
      },
      'IdV: doc auth agreement visited' => {
        step: 'agreement', analytics_id: 'Doc Auth'
      },
      'IdV: consent checkbox toggled' => {
        checked: true,
      },
      'IdV: doc auth agreement submitted' => {
        success: true, step: 'agreement', analytics_id: 'Doc Auth'
      },
      'IdV: doc auth hybrid handoff visited' => {
        step: 'hybrid_handoff', analytics_id: 'Doc Auth', selfie_check_required: boolean
      },
      'IdV: doc auth hybrid handoff submitted' => {
        success: true, destination: :document_capture, flow_path: 'standard', step: 'hybrid_handoff', analytics_id: 'Doc Auth', selfie_check_required: boolean
      },
      'IdV: doc auth document_capture visited' => {
        flow_path: 'standard', step: 'document_capture', analytics_id: 'Doc Auth', selfie_check_required: boolean, liveness_checking_required: true
      },
      'Frontend: IdV: front image added' => {
        width: 284, height: 38, mimeType: 'image/png', source: 'upload', size: 3694, captureAttempts: 1, flow_path: 'standard', acuant_sdk_upgrade_a_b_testing_enabled: 'false', use_alternate_sdk: anything, acuant_version: kind_of(String), fingerprint: anything, failedImageResubmission: boolean, liveness_checking_required: boolean
      },
      'Frontend: IdV: back image added' => {
        width: 284, height: 38, mimeType: 'image/png', source: 'upload', size: 3694, captureAttempts: 1, flow_path: 'standard', acuant_sdk_upgrade_a_b_testing_enabled: 'false', use_alternate_sdk: anything, acuant_version: kind_of(String), fingerprint: anything, failedImageResubmission: boolean, liveness_checking_required: boolean
      },
      'IdV: doc auth image upload form submitted' => {
        success: true, submit_attempts: 1, remaining_submit_attempts: 3, user_id: user.uuid, flow_path: 'standard', front_image_fingerprint: an_instance_of(String), back_image_fingerprint: an_instance_of(String), selfie_image_fingerprint: an_instance_of(String), liveness_checking_required: boolean, document_type: an_instance_of(String)
      },
      'IdV: doc auth image upload vendor submitted' => hash_including(success: true, flow_path: 'standard', attention_with_barcode: false, doc_auth_result: 'Passed', id_doc_type: an_instance_of(String)),
      'IdV: doc auth image upload vendor pii validation' => {
        success: true, user_id: user.uuid, submit_attempts: 1, remaining_submit_attempts: 3, flow_path: 'standard', attention_with_barcode: false, front_image_fingerprint: an_instance_of(String), back_image_fingerprint: an_instance_of(String), selfie_image_fingerprint: an_instance_of(String), liveness_checking_required: boolean, classification_info: {}, id_issued_status: 'present', id_expiration_status: 'present', passport_issued_status: 'missing', passport_expiration_status: 'missing', document_type: an_instance_of(String), id_doc_type: an_instance_of(String)
      },
      'IdV: doc auth document_capture submitted' => {
        success: true, flow_path: 'standard', step: 'document_capture', analytics_id: 'Doc Auth', selfie_check_required: boolean, liveness_checking_required: true,
        proofing_components: { document_check: 'mock', document_type: 'drivers_license' }
      },
      :idv_selfie_image_added => {
        acuant_version: kind_of(String), captureAttempts: 1, fingerprint: 'aIzxkX_iMtoxFOURZr55qkshs53emQKUOr7VfTf6G1Q', flow_path: 'standard', height: 38, mimeType: 'image/png', size: 3694, source: 'upload', width: 284, liveness_checking_required: boolean, selfie_attempts: 0
      },
      'IdV: doc auth ssn visited' => {
        flow_path: 'standard', step: 'ssn', analytics_id: 'Doc Auth',
        proofing_components: { document_check: 'mock', document_type: 'drivers_license' }
      },
      'IdV: doc auth ssn submitted' => {
        success: true, flow_path: 'standard', step: 'ssn', analytics_id: 'Doc Auth',
        proofing_components: { document_check: 'mock', document_type: 'drivers_license' }
      },
      'IdV: doc auth verify visited' => {
        flow_path: 'standard', step: 'verify', analytics_id: 'Doc Auth',
        proofing_components: { document_check: 'mock', document_type: 'drivers_license' }
      },
      'IdV: doc auth verify submitted' => {
        flow_path: 'standard', step: 'verify', analytics_id: 'Doc Auth',
        proofing_components: { document_check: 'mock', document_type: 'drivers_license' }
      },
      idv_threatmetrix_response_body: (
        if threatmetrix_response_body.present?
          { response_body: threatmetrix_response_body }
        end
      ),
      'IdV: doc auth verify proofing results' => {
        success: true, flow_path: 'standard', address_edited: false, address_line2_present: false, last_name_spaced: false, analytics_id: 'Doc Auth', step: 'verify',
        proofing_results: doc_auth_verify_proofing_results,
        proofing_components: base_proofing_components
      },
      'IdV: phone of record visited' => {
        proofing_components: base_proofing_components,
      },
      'IdV: phone confirmation form' => {
        success: true, phone_type: :mobile, types: [:fixed_or_mobile], carrier: 'Test Mobile Carrier', country_code: 'US', area_code: '202', otp_delivery_preference: 'sms',
        proofing_components: base_proofing_components
      },
      'IdV: phone confirmation vendor' => {
        success: true, vendor: { exception: nil, vendor_name: 'AddressMock', transaction_id: 'address-mock-transaction-id-123', timed_out: false, reference: '' }, new_phone_added: false, hybrid_handoff_phone_used: false, area_code: '202', country_code: 'US', phone_fingerprint: anything,
        proofing_components: lexis_nexis_address_proofing_components
      },
      'IdV: phone confirmation otp sent' => {
        success: true, otp_delivery_preference: :sms, country_code: 'US', area_code: '202', adapter: :test, phone_fingerprint: anything, rate_limit_exceeded: false, telephony_response: anything,
        proofing_components: lexis_nexis_address_proofing_components
      },
      'IdV: phone confirmation otp visited' => {
        proofing_components: lexis_nexis_address_proofing_components,
      },
      'IdV: phone confirmation otp submitted' => {
        success: true, code_expired: false, code_matches: true, otp_delivery_preference: :sms, second_factor_attempts_count: 0,
        proofing_components: lexis_nexis_address_proofing_components
      },
      :idv_enter_password_visited => {
        address_verification_method: 'phone',
        proofing_components: lexis_nexis_address_proofing_components,
      },
      :idv_enter_password_submitted => {
        success: true, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: false, in_person_verification_pending: false, proofing_workflow_time_in_seconds: 0.0,
        active_profile_idv_level: 'unsupervised_with_selfie',
        proofing_components: lexis_nexis_address_proofing_components
      },
      'IdV: final resolution' => {
        success: true, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: false, in_person_verification_pending: false, proofing_workflow_time_in_seconds: 0.0,
        active_profile_idv_level: 'unsupervised_with_selfie',
        profile_history: match_array(kind_of(Idv::ProfileLogging)),
        proofing_components: lexis_nexis_address_proofing_components
      },
      'IdV: personal key visited' => {
        address_verification_method: 'phone', in_person_verification_pending: false, encrypted_profiles_missing: false,
        active_profile_idv_level: 'unsupervised_with_selfie',
        proofing_components: lexis_nexis_address_proofing_components
      },
      'IdV: personal key acknowledgment toggled' => {
        checked: true,
        active_profile_idv_level: 'unsupervised_with_selfie',
        proofing_components: lexis_nexis_address_proofing_components,
      },
      'IdV: personal key submitted' => {
        address_verification_method: 'phone', fraud_review_pending: false, fraud_rejection: false, in_person_verification_pending: false,
        active_profile_idv_level: 'unsupervised_with_selfie',
        proofing_components: lexis_nexis_address_proofing_components
      },
    }.compact
  end
  # rubocop:enable Layout/LineLength
  # rubocop:enable Layout/MultilineHashKeyLineBreaks

  # Needed for enqueued_at in RequestLetter
  around do |ex|
    freeze_time { ex.run }
  end

  before do
    allow(IdentityConfig.store).to receive(:proofing_device_profiling)
      .and_return(proofing_device_profiling)
    allow_any_instance_of(ApplicationController).to receive(:analytics) do |controller|
      fake_analytics.user = controller.analytics_user
      fake_analytics.session = controller.session
      fake_analytics
    end
    allow(IdentityConfig.store).to receive(:idv_acuant_sdk_upgrade_a_b_testing_enabled)
      .and_return(false)
  end

  context 'Happy path' do
    before do
      sign_in_and_2fa_user(user)
      visit_idp_from_sp_with_ial2(:oidc)
      complete_welcome_step
      complete_agreement_step
      complete_hybrid_handoff_step
      complete_document_capture_step
      complete_ssn_step
      complete_verify_step
      complete_phone_step(user)
      complete_enter_password_step(user)
      acknowledge_and_confirm_personal_key
    end

    it 'records all of the events' do
      aggregate_failures 'analytics events' do
        happy_path_events.each do |event, attributes|
          expect(fake_analytics).to have_logged_event(event, attributes)
        end
      end

      aggregate_failures 'populates data for each step of the Daily Dropoff Report' do
        row = CSV.parse(
          Reports::DailyDropoffsReport.new.tap { |r| r.report_date = Time.zone.now }.report_body,
          headers: true,
        ).first

        Reports::DailyDropoffsReport::STEPS.each do |step|
          expect(row[step].to_i).to(be > 0, "step #{step} was counted")
        end
      end
    end

    context 'proofing_device_profiling disabled' do
      let(:proofing_device_profiling) { :disabled }
      let(:threatmetrix) { false }
      let(:threatmetrix_response_body) { nil }

      let(:threatmetrix_response) do
        {
          client: 'tmx_disabled',
          success: true,
          errors: {},
          exception: nil,
          timed_out: false,
          transaction_id: nil,
          review_status: 'pass',
          account_lex_id: nil,
          session_id: nil,
        }
      end

      it 'records all of the events' do
        aggregate_failures 'analytics events' do
          happy_path_events.each do |event, attributes|
            expect(fake_analytics).to have_logged_event(event, attributes)
          end
        end
      end
    end
  end

  context 'Happy hybrid path' do
    before do
      allow(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
        @sms_link = config[:link]
        impl.call(**config)
      end.at_least(1).times

      perform_in_browser(:desktop) do
        sign_in_and_2fa_user(user)
        visit_idp_from_sp_with_ial2(:oidc)
        complete_welcome_step
        complete_agreement_step
        click_send_link
      end

      perform_in_browser(:mobile) do
        visit @sms_link
        attach_and_submit_images
        visit idv_hybrid_mobile_document_capture_url
      end

      perform_in_browser(:desktop) do
        click_idv_continue
        visit idv_ssn_url
        complete_ssn_step
        complete_verify_step
        fill_out_phone_form_ok('202-555-1212')
        verify_phone_otp
        complete_enter_password_step(user)
        acknowledge_and_confirm_personal_key
      end
    end

    it 'records all of the events' do
      aggregate_failures 'analytics events' do
        happy_hybrid_path_events.each do |event, attributes|
          expect(fake_analytics).to have_logged_event(event, attributes)
        end
      end

      aggregate_failures 'populates data for each step of the Daily Dropoff Report' do
        row = CSV.parse(
          Reports::DailyDropoffsReport.new.tap { |r| r.report_date = Time.zone.now }.report_body,
          headers: true,
        ).first

        Reports::DailyDropoffsReport::STEPS.each do |step|
          expect(row[step].to_i).to(be > 0, "step #{step} was counted")
        end
      end
    end

    context 'proofing_device_profiling disabled' do
      let(:proofing_device_profiling) { :disabled }
      let(:threatmetrix) { false }
      let(:threatmetrix_response_body) { nil }

      let(:threatmetrix_response) do
        {
          client: 'tmx_disabled',
          success: true,
          errors: {},
          exception: nil,
          timed_out: false,
          transaction_id: nil,
          review_status: 'pass',
          account_lex_id: nil,
          session_id: nil,
        }
      end

      it 'records all of the events' do
        aggregate_failures 'analytics events' do
          happy_hybrid_path_events.each do |event, attributes|
            expect(fake_analytics).to have_logged_event(event, attributes)
          end
        end
      end
    end
  end

  context 'GPO path' do
    before do
      fake_analytics.events.clear
      sign_in_and_2fa_user(user)
      visit_idp_from_sp_with_ial2(:oidc)
      complete_welcome_step
      complete_agreement_step
      complete_hybrid_handoff_step
      complete_document_capture_step
      complete_ssn_step
      complete_verify_step
      enter_gpo_flow
      complete_request_letter
      complete_enter_password_step(user)
    end

    it 'records all of the events' do
      aggregate_failures 'analytics_events' do
        gpo_path_events.each do |event, attributes|
          expect(fake_analytics).to have_logged_event(event, attributes)
        end
      end
    end

    context 'proofing_device_profiling disabled' do
      let(:proofing_device_profiling) { :disabled }
      let(:threatmetrix) { false }
      let(:threatmetrix_response_body) { nil }

      let(:threatmetrix_response) do
        {
          client: 'tmx_disabled',
          success: true,
          errors: {},
          exception: nil,
          timed_out: false,
          transaction_id: nil,
          review_status: 'pass',
          account_lex_id: nil,
          session_id: nil,
        }
      end

      it 'records all of the events' do
        aggregate_failures 'analytics events' do
          gpo_path_events.each do |event, attributes|
            expect(fake_analytics).to have_logged_event(event, attributes)
          end
        end
      end
    end
  end

  context 'Hybrid flow' do
    context 'facial comparison not required - Happy path' do
      before do
        sign_in_and_2fa_user(user)
        visit_idp_from_sp_with_ial2(:oidc)
        complete_welcome_step
        complete_agreement_step
        complete_hybrid_handoff_step
        complete_document_capture_step
        complete_ssn_step
        complete_verify_step
        complete_phone_step(user)
        complete_enter_password_step(user)
        acknowledge_and_confirm_personal_key
      end

      it 'records all of the events' do
        aggregate_failures 'analytics events' do
          happy_path_events.each do |event, attributes|
            expect(fake_analytics).to have_logged_event(event, attributes)
          end
        end

        aggregate_failures 'populates data for each step of the Daily Dropoff Report' do
          row = CSV.parse(
            Reports::DailyDropoffsReport.new.tap do |r|
              r.report_date = Time.zone.now
            end.report_body,
            headers: true,
          ).first

          Reports::DailyDropoffsReport::STEPS.each do |step|
            expect(row[step].to_i).to(be > 0, "step #{step} was counted")
          end
        end
      end

      context 'proofing_device_profiling disabled' do
        let(:proofing_device_profiling) { :disabled }
        let(:threatmetrix) { false }
        let(:threatmetrix_response_body) { nil }

        let(:threatmetrix_response) do
          {
            client: 'tmx_disabled',
            success: true,
            errors: {},
            exception: nil,
            timed_out: false,
            transaction_id: nil,
            review_status: 'pass',
            account_lex_id: nil,
            session_id: nil,
          }
        end

        it 'records all of the events', allow_browser_log: true do
          aggregate_failures 'analytics events' do
            happy_path_events.each do |event, attributes|
              expect(fake_analytics).to have_logged_event(event, attributes)
            end
          end
        end
      end
    end

    context 'facial comparison required - Happy path' do
      before do
        allow_any_instance_of(DocAuth::Response).to receive(:selfie_status).and_return(:success)

        perform_in_browser(:mobile) do
          sign_in_and_2fa_user(user)
          visit_idp_from_sp_with_ial2(:oidc, facial_match_required: true)
          complete_doc_auth_steps_before_document_capture_step
          attach_images
          click_continue
          click_button 'Take photo'
          attach_selfie
          submit_images

          click_idv_continue
          visit idv_ssn_url
          complete_ssn_step
          complete_verify_step
          fill_out_phone_form_ok('202-555-1212')
          verify_phone_otp
          complete_enter_password_step(user)
          acknowledge_and_confirm_personal_key
        end
      end

      it 'records all of the events' do
        happy_mobile_selfie_path_events.each do |event, attributes|
          expect(fake_analytics).to have_logged_event(event, attributes)
        end
      end

      context 'proofing_device_profiling disabled' do
        let(:proofing_device_profiling) { :disabled }
        let(:threatmetrix) { false }
        let(:threatmetrix_response_body) { nil }

        let(:threatmetrix_response) do
          {
            client: 'tmx_disabled',
            success: true,
            errors: {},
            exception: nil,
            timed_out: false,
            transaction_id: nil,
            review_status: 'pass',
            account_lex_id: nil,
            session_id: nil,
          }
        end

        it 'records all of the events' do
          aggregate_failures 'analytics events' do
            happy_mobile_selfie_path_events.each do |event, attributes|
              expect(fake_analytics).to have_logged_event(event, attributes)
            end
          end
        end
      end
    end
  end

  context 'facial comparison not required - Happy path' do
    before do
      allow(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
        @sms_link = config[:link]
        impl.call(**config)
      end.at_least(1).times

      perform_in_browser(:desktop) do
        sign_in_and_2fa_user(user)
        visit_idp_from_sp_with_ial2(:oidc)
        complete_welcome_step
        complete_agreement_step
        click_send_link
      end

      perform_in_browser(:mobile) do
        visit @sms_link
        attach_and_submit_images
        visit idv_hybrid_mobile_document_capture_url
      end

      perform_in_browser(:desktop) do
        click_idv_continue
        visit idv_ssn_url
        complete_ssn_step
        complete_verify_step
        fill_out_phone_form_ok('202-555-1212')
        verify_phone_otp
        complete_enter_password_step(user)
        acknowledge_and_confirm_personal_key
      end
    end

    it 'records all of the events' do
      aggregate_failures 'analytics events' do
        happy_hybrid_path_events.each do |event, attributes|
          expect(fake_analytics).to have_logged_event(event, attributes)
        end
      end

      aggregate_failures 'populates data for each step of the Daily Dropoff Report' do
        row = CSV.parse(
          Reports::DailyDropoffsReport.new.tap { |r| r.report_date = Time.zone.now }.report_body,
          headers: true,
        ).first

        Reports::DailyDropoffsReport::STEPS.each do |step|
          expect(row[step].to_i).to(be > 0, "step #{step} was counted")
        end
      end
    end

    context 'proofing_device_profiling disabled' do
      let(:proofing_device_profiling) { :disabled }
      let(:threatmetrix) { false }
      let(:threatmetrix_response_body) { nil }

      let(:threatmetrix_response) do
        {
          client: 'tmx_disabled',
          success: true,
          errors: {},
          exception: nil,
          timed_out: false,
          transaction_id: nil,
          review_status: 'pass',
          account_lex_id: nil,
          session_id: nil,
        }
      end

      it 'records all of the events' do
        aggregate_failures 'analytics events' do
          happy_hybrid_path_events.each do |event, attributes|
            expect(fake_analytics).to have_logged_event(event, attributes)
          end
        end
      end
    end
  end

  context 'in person path' do
    let(:return_sp_url) { 'https://example.com/some/idv/ipp/url' }

    before do
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled).and_return(false)
      allow(IdentityConfig.store).to receive(:in_person_passports_enabled).and_return(false)
      allow(Idv::InPersonConfig).to receive(:enabled_for_issuer?).and_return(true)
      allow_any_instance_of(Idv::InPerson::ReadyToVerifyPresenter)
        .to receive(:service_provider_homepage_url).and_return(return_sp_url)
      allow_any_instance_of(Idv::InPerson::ReadyToVerifyPresenter)
        .to receive(:sp_name).and_return(sp_friendly_name)
      allow(IdentityConfig.store).to receive(:in_person_proofing_enforce_tmx)
        .and_return(true)

      start_idv_from_sp(:saml)
      sign_in_and_2fa_user(user)
      begin_in_person_proofing(user)
      complete_all_in_person_proofing_steps(user, same_address_as_id: false)
      complete_phone_step(user)
      complete_enter_password_step(user)
      acknowledge_and_confirm_personal_key
      visit_help_center
      visit_sp_from_in_person_ready_to_verify
    end

    it 'records all of the events', allow_browser_log: true do
      max_wait = Time.zone.now + 5.seconds
      wait_for_event('IdV: user clicked what to bring link on ready to verify page', max_wait)
      wait_for_event('IdV: user clicked sp link on ready to verify page', max_wait)
      in_person_path_events.each do |event, attributes|
        expect(fake_analytics).to have_logged_event(event, attributes)
      end
    end

    context 'proofing_device_profiling disabled' do
      let(:proofing_device_profiling) { :disabled }
      let(:idv_level) { 'legacy_in_person' }
      let(:threatmetrix) { false }
      let(:threatmetrix_response_body) { nil }

      let(:threatmetrix_response) do
        {
          client: 'tmx_disabled',
          success: true,
          errors: {},
          exception: nil,
          timed_out: false,
          transaction_id: nil,
          review_status: 'pass',
          account_lex_id: nil,
          session_id: nil,
        }
      end

      it 'records all of the events', allow_browser_log: true do
        max_wait = Time.zone.now + 5.seconds
        wait_for_event('IdV: user clicked what to bring link on ready to verify page', max_wait)
        wait_for_event('IdV: user clicked sp link on ready to verify page', max_wait)
        in_person_path_events.each do |event, attributes|
          expect(fake_analytics).to have_logged_event(event, attributes)
        end
      end
    end

    # wait for event to happen
    def wait_for_event(event, wait)
      frequency = 0.1.seconds
      loop do
        expect(fake_analytics).to have_logged_event(event)
        return
      rescue RSpec::Expectations::ExpectationNotMetError => err
        raise err if wait - Time.zone.now < frequency
        sleep frequency
        next
      end
    end
  end
end
