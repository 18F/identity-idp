require 'rails_helper'
require 'csv'

RSpec.feature 'Analytics Regression', js: true do
  include IdvStepHelper
  include InPersonHelper

  let(:user) { user_with_2fa }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:proofing_device_profiling) { :enabled }
  let(:threatmetrix) { true }
  let(:threatmetrix_response) do
    { client: nil,
      errors: {},
      exception: nil,
      response_body: { first_name: '[redacted]',
                       "fraudpoint.score": '500',
                       request_id: '1234',
                       request_result: 'success',
                       review_status: 'pass',
                       risk_rating: 'trusted',
                       summary_risk_score: '-6',
                       tmx_risk_rating: 'neutral',
                       tmx_summary_reason_code: ['Identity_Negative_History'] },
      review_status: 'pass',
      success: true,
      timed_out: false,
      transaction_id: 'ddp-mock-transaction-id-123' }
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
        step: 'welcome', analytics_id: 'Doc Auth', irs_reproofing: false, skip_hybrid_handoff: nil, lexisnexis_instant_verify_workflow_ab_test_bucket: :default
      },
      'IdV: doc auth welcome submitted' => {
        step: 'welcome', analytics_id: 'Doc Auth', irs_reproofing: false, skip_hybrid_handoff: nil, lexisnexis_instant_verify_workflow_ab_test_bucket: :default
      },
      'IdV: doc auth agreement visited' => {
        step: 'agreement', analytics_id: 'Doc Auth', skip_hybrid_handoff: nil, irs_reproofing: false, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default
      },
      'IdV: consent checkbox toggled' => {
        checked: true,
      },
      'IdV: doc auth agreement submitted' => {
        success: true, errors: {}, step: 'agreement', analytics_id: 'Doc Auth', skip_hybrid_handoff: nil, irs_reproofing: false, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default
      },
      'IdV: doc auth hybrid handoff visited' => {
        step: 'hybrid_handoff', redo_document_capture: nil, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, analytics_id: 'Doc Auth', skip_hybrid_handoff: nil, irs_reproofing: false
      },
      'IdV: doc auth hybrid handoff submitted' => {
        success: true, errors: {}, destination: :document_capture, flow_path: 'standard', step: 'hybrid_handoff', redo_document_capture: nil, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, analytics_id: 'Doc Auth', skip_hybrid_handoff: nil, irs_reproofing: false
      },
      'IdV: doc auth document_capture visited' => {
        flow_path: 'standard', step: 'document_capture', redo_document_capture: nil, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, analytics_id: 'Doc Auth', skip_hybrid_handoff: nil, irs_reproofing: false
      },
      'Frontend: IdV: front image added' => {
        width: 284, height: 38, mimeType: 'image/png', source: 'upload', size: 3694, attempt: 1, flow_path: 'standard', acuant_sdk_upgrade_a_b_testing_enabled: 'false', use_alternate_sdk: anything, acuant_version: anything, acuantCaptureMode: nil, fingerprint: anything, failedImageResubmission: boolean, documentType: nil, dpi: nil, glare: nil, glareScoreThreshold: nil, isAssessedAsBlurry: nil, isAssessedAsGlare: nil, isAssessedAsUnsupported: nil, moire: nil, sharpness: nil, sharpnessScoreThreshold: nil, assessment: nil
      },
      'Frontend: IdV: back image added' => {
        width: 284, height: 38, mimeType: 'image/png', source: 'upload', size: 3694, attempt: 1, flow_path: 'standard', acuant_sdk_upgrade_a_b_testing_enabled: 'false', use_alternate_sdk: anything, acuant_version: anything, acuantCaptureMode: nil, fingerprint: anything, failedImageResubmission: boolean, documentType: nil, dpi: nil, glare: nil, glareScoreThreshold: nil, isAssessedAsBlurry: nil, isAssessedAsGlare: nil, isAssessedAsUnsupported: nil, moire: nil, sharpness: nil, sharpnessScoreThreshold: nil, assessment: nil
      },
      'IdV: doc auth image upload form submitted' => {
        success: true, errors: {}, attempts: 1, remaining_attempts: 3, user_id: user.uuid, flow_path: 'standard', front_image_fingerprint: an_instance_of(String), back_image_fingerprint: an_instance_of(String)
      },
      'IdV: doc auth image upload vendor pii validation' => {
        success: true, errors: {}, user_id: user.uuid, attempts: 1, remaining_attempts: 3, flow_path: 'standard', attention_with_barcode: false, front_image_fingerprint: an_instance_of(String), back_image_fingerprint: an_instance_of(String), classification_info: {}
      },
      'IdV: doc auth document_capture submitted' => {
        success: true, errors: {}, flow_path: 'standard', step: 'document_capture', redo_document_capture: nil, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, analytics_id: 'Doc Auth', skip_hybrid_handoff: nil, irs_reproofing: false
      },
      'IdV: doc auth ssn visited' => {
        flow_path: 'standard', step: 'ssn', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, analytics_id: 'Doc Auth', irs_reproofing: false
      },
      'IdV: doc auth ssn submitted' => {
        success: true, errors: {}, flow_path: 'standard', step: 'ssn', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, analytics_id: 'Doc Auth', irs_reproofing: false
      },
      'IdV: doc auth verify visited' => {
        flow_path: 'standard', step: 'verify', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, analytics_id: 'Doc Auth', irs_reproofing: false
      },
      'IdV: doc auth verify submitted' => {
        flow_path: 'standard', step: 'verify', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, analytics_id: 'Doc Auth', irs_reproofing: false
      },
      'IdV: doc auth verify proofing results' => {
        success: true, errors: {}, flow_path: 'standard', address_edited: false, address_line2_present: false, analytics_id: 'Doc Auth', ssn_is_unique: true, step: 'verify', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, irs_reproofing: false, skip_hybrid_handoff: nil,
        proofing_results: { exception: nil, timed_out: false, threatmetrix_review_status: 'pass', context: { device_profiling_adjudication_reason: 'device_profiling_result_pass', resolution_adjudication_reason: 'pass_resolution_and_state_id', should_proof_state_id: true, stages: { resolution: { success: true, errors: {}, exception: nil, timed_out: false, transaction_id: 'resolution-mock-transaction-id-123', reference: 'aaa-bbb-ccc', can_pass_with_additional_verification: false, attributes_requiring_additional_verification: [], vendor_name: 'ResolutionMock', vendor_workflow: nil }, residential_address: { attributes_requiring_additional_verification: [], can_pass_with_additional_verification: false, errors: {}, exception: nil, reference: '', success: true, timed_out: false, transaction_id: '', vendor_name: 'ResidentialAddressNotRequired', vendor_workflow: nil }, state_id: { success: true, errors: {}, exception: nil, mva_exception: nil, timed_out: false, transaction_id: 'state-id-mock-transaction-id-456', vendor_name: 'StateIdMock', verified_attributes: [], state: 'MT', state_id_jurisdiction: 'ND', state_id_number: '#############' }, threatmetrix: threatmetrix_response } } }
      },
      'IdV: phone of record visited' => {
        acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass' }
      },
      'IdV: phone confirmation form' => {
        success: true, errors: {}, phone_type: :mobile, types: [:fixed_or_mobile], carrier: 'Test Mobile Carrier', country_code: 'US', area_code: '202', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, otp_delivery_preference: 'sms',
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass' }
      },
      'IdV: phone confirmation vendor' => {
        success: true, errors: {}, vendor: { exception: nil, vendor_name: 'AddressMock', transaction_id: 'address-mock-transaction-id-123', timed_out: false, reference: '' }, new_phone_added: false, hybrid_handoff_phone_used: false, area_code: '202', country_code: 'US', phone_fingerprint: anything,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      'IdV: phone confirmation otp sent' => {
        success: true, otp_delivery_preference: :sms, country_code: 'US', area_code: '202', adapter: :test, errors: {}, phone_fingerprint: anything, rate_limit_exceeded: false, telephony_response: anything,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      'IdV: phone confirmation otp visited' => {
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' },
      },
      'IdV: phone confirmation otp submitted' => {
        success: true, code_expired: false, code_matches: true, second_factor_attempts_count: 0, second_factor_locked_at: nil, errors: {},
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      :idv_enter_password_visited => {
        address_verification_method: 'phone', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      :idv_enter_password_submitted => {
        success: true, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: false, in_person_verification_pending: false, deactivation_reason: nil,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      'IdV: final resolution' => {
        success: true, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: false, in_person_verification_pending: false, deactivation_reason: nil,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      'IdV: personal key visited' => {
        address_verification_method: 'phone', in_person_verification_pending: false,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      'IdV: personal key acknowledgment toggled' => {
        checked: true,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' },
      },
      'IdV: personal key submitted' => {
        address_verification_method: 'phone', fraud_review_pending: false, fraud_rejection: false, in_person_verification_pending: false, deactivation_reason: nil,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
    }
  end

  let(:happy_hybrid_path_events) do
    {
      'IdV: intro visited' => {},
      'IdV: doc auth welcome visited' => {
        step: 'welcome', analytics_id: 'Doc Auth', irs_reproofing: false, skip_hybrid_handoff: nil, lexisnexis_instant_verify_workflow_ab_test_bucket: :default
      },
      'IdV: doc auth welcome submitted' => {
        step: 'welcome', analytics_id: 'Doc Auth', irs_reproofing: false, skip_hybrid_handoff: nil, lexisnexis_instant_verify_workflow_ab_test_bucket: :default
      },
      'IdV: doc auth agreement visited' => {
        step: 'agreement', analytics_id: 'Doc Auth', skip_hybrid_handoff: nil, irs_reproofing: false, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default
      },
      'IdV: consent checkbox toggled' => {
        checked: true,
      },
      'IdV: doc auth agreement submitted' => {
        success: true, errors: {}, step: 'agreement', analytics_id: 'Doc Auth', skip_hybrid_handoff: nil, irs_reproofing: false, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default
      },
      'IdV: doc auth hybrid handoff visited' => {
        step: 'hybrid_handoff', redo_document_capture: nil, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, analytics_id: 'Doc Auth', skip_hybrid_handoff: nil, irs_reproofing: false
      },
      'IdV: doc auth hybrid handoff submitted' => {
        success: true, errors: hash_including(message: nil), destination: :link_sent, flow_path: 'hybrid', step: 'hybrid_handoff', redo_document_capture: nil, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, analytics_id: 'Doc Auth', skip_hybrid_handoff: nil, irs_reproofing: false, telephony_response: hash_including(errors: {}, message_id: 'fake-message-id', request_id: 'fake-message-request-id', success: true)
      },
      'IdV: doc auth document_capture visited' => {
        flow_path: 'hybrid', step: 'document_capture', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, analytics_id: 'Doc Auth', irs_reproofing: false
      },
      'Frontend: IdV: front image added' => {
        width: 284, height: 38, mimeType: 'image/png', source: 'upload', size: 3694, attempt: 1, flow_path: 'hybrid', acuant_sdk_upgrade_a_b_testing_enabled: 'false', use_alternate_sdk: anything, acuant_version: anything, acuantCaptureMode: nil, fingerprint: anything, failedImageResubmission: boolean, documentType: nil, dpi: nil, glare: nil, glareScoreThreshold: nil, isAssessedAsBlurry: nil, isAssessedAsGlare: nil, isAssessedAsUnsupported: nil, moire: nil, sharpness: nil, sharpnessScoreThreshold: nil, assessment: nil
      },
      'Frontend: IdV: back image added' => {
        width: 284, height: 38, mimeType: 'image/png', source: 'upload', size: 3694, attempt: 1, flow_path: 'hybrid', acuant_sdk_upgrade_a_b_testing_enabled: 'false', use_alternate_sdk: anything, acuant_version: anything, acuantCaptureMode: nil, fingerprint: anything, failedImageResubmission: boolean, documentType: nil, dpi: nil, glare: nil, glareScoreThreshold: nil, isAssessedAsBlurry: nil, isAssessedAsGlare: nil, isAssessedAsUnsupported: nil, moire: nil, sharpness: nil, sharpnessScoreThreshold: nil, assessment: nil
      },
      'IdV: doc auth image upload form submitted' => {
        success: true, errors: {}, attempts: 1, remaining_attempts: 3, user_id: user.uuid, flow_path: 'hybrid', front_image_fingerprint: an_instance_of(String), back_image_fingerprint: an_instance_of(String)
      },
      'IdV: doc auth image upload vendor pii validation' => {
        success: true, errors: {}, user_id: user.uuid, attempts: 1, remaining_attempts: 3, flow_path: 'hybrid', attention_with_barcode: false, front_image_fingerprint: an_instance_of(String), back_image_fingerprint: an_instance_of(String), classification_info: {}
      },
      'IdV: doc auth document_capture submitted' => {
        success: true, errors: {}, flow_path: 'hybrid', step: 'document_capture', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, analytics_id: 'Doc Auth', irs_reproofing: false
      },
      'IdV: doc auth ssn visited' => {
        flow_path: 'hybrid', step: 'ssn', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, analytics_id: 'Doc Auth', irs_reproofing: false
      },
      'IdV: doc auth ssn submitted' => {
        success: true, errors: {}, flow_path: 'hybrid', step: 'ssn', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, analytics_id: 'Doc Auth', irs_reproofing: false
      },
      'IdV: doc auth verify visited' => {
        flow_path: 'hybrid', step: 'verify', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, analytics_id: 'Doc Auth', irs_reproofing: false
      },
      'IdV: doc auth verify submitted' => {
        flow_path: 'hybrid', step: 'verify', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, analytics_id: 'Doc Auth', irs_reproofing: false
      },
      'IdV: doc auth verify proofing results' => {
        success: true, errors: {}, flow_path: 'hybrid', address_edited: false, address_line2_present: false, analytics_id: 'Doc Auth', ssn_is_unique: true, step: 'verify', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, irs_reproofing: false, skip_hybrid_handoff: nil,
        proofing_results: { exception: nil, timed_out: false, threatmetrix_review_status: 'pass', context: { device_profiling_adjudication_reason: 'device_profiling_result_pass', resolution_adjudication_reason: 'pass_resolution_and_state_id', should_proof_state_id: true, stages: { resolution: { success: true, errors: {}, exception: nil, timed_out: false, transaction_id: 'resolution-mock-transaction-id-123', reference: 'aaa-bbb-ccc', can_pass_with_additional_verification: false, attributes_requiring_additional_verification: [], vendor_name: 'ResolutionMock', vendor_workflow: nil }, residential_address: { attributes_requiring_additional_verification: [], can_pass_with_additional_verification: false, errors: {}, exception: nil, reference: '', success: true, timed_out: false, transaction_id: '', vendor_name: 'ResidentialAddressNotRequired', vendor_workflow: nil }, state_id: { success: true, errors: {}, exception: nil, mva_exception: nil, timed_out: false, transaction_id: 'state-id-mock-transaction-id-456', vendor_name: 'StateIdMock', verified_attributes: [], state: 'MT', state_id_jurisdiction: 'ND', state_id_number: '#############' }, threatmetrix: threatmetrix_response } } }
      },
      'IdV: phone of record visited' => {
        acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass' }
      },
      'IdV: phone confirmation form' => {
        success: true, errors: {}, phone_type: :mobile, types: [:fixed_or_mobile], carrier: 'Test Mobile Carrier', country_code: 'US', area_code: '202', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, otp_delivery_preference: 'sms',
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass' }
      },
      'IdV: phone confirmation vendor' => {
        success: true, errors: {}, vendor: { exception: nil, vendor_name: 'AddressMock', transaction_id: 'address-mock-transaction-id-123', timed_out: false, reference: '' }, new_phone_added: false, hybrid_handoff_phone_used: true, area_code: '202', country_code: 'US', phone_fingerprint: anything,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      'IdV: phone confirmation otp sent' => {
        success: true, otp_delivery_preference: :sms, country_code: 'US', area_code: '202', adapter: :test, errors: {}, phone_fingerprint: anything, rate_limit_exceeded: false, telephony_response: anything,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      'IdV: phone confirmation otp visited' => {
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' },
      },
      'IdV: phone confirmation otp submitted' => {
        success: true, code_expired: false, code_matches: true, second_factor_attempts_count: 0, second_factor_locked_at: nil, errors: {},
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      :idv_enter_password_visited => {
        address_verification_method: 'phone', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      :idv_enter_password_submitted => {
        success: true, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: false, in_person_verification_pending: false, deactivation_reason: nil,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      'IdV: final resolution' => {
        success: true, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: false, in_person_verification_pending: false, deactivation_reason: nil,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      'IdV: personal key visited' => {
        address_verification_method: 'phone', in_person_verification_pending: false,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      'IdV: personal key acknowledgment toggled' => {
        checked: true,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' },
      },
      'IdV: personal key submitted' => {
        address_verification_method: 'phone', fraud_review_pending: false, fraud_rejection: false, in_person_verification_pending: false, deactivation_reason: nil,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
    }
  end

  let(:gpo_path_events) do
    {
      'IdV: intro visited' => {},
      'IdV: doc auth welcome visited' => {
        step: 'welcome', analytics_id: 'Doc Auth', irs_reproofing: false, skip_hybrid_handoff: nil, lexisnexis_instant_verify_workflow_ab_test_bucket: :default
      },
      'IdV: doc auth welcome submitted' => {
        step: 'welcome', analytics_id: 'Doc Auth', irs_reproofing: false, skip_hybrid_handoff: nil, lexisnexis_instant_verify_workflow_ab_test_bucket: :default
      },
      'IdV: doc auth agreement visited' => {
        step: 'agreement', analytics_id: 'Doc Auth', skip_hybrid_handoff: nil, irs_reproofing: false, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default
      },
      'IdV: doc auth agreement submitted' => {
        success: true, errors: {}, step: 'agreement', analytics_id: 'Doc Auth', skip_hybrid_handoff: nil, irs_reproofing: false, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default
      },
      'IdV: doc auth hybrid handoff visited' => {
        step: 'hybrid_handoff', redo_document_capture: nil, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, analytics_id: 'Doc Auth', skip_hybrid_handoff: nil, irs_reproofing: false
      },
      'IdV: doc auth hybrid handoff submitted' => {
        success: true, errors: {}, destination: :document_capture, flow_path: 'standard', redo_document_capture: nil, step: 'hybrid_handoff', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, analytics_id: 'Doc Auth', skip_hybrid_handoff: nil, irs_reproofing: false
      },
      'IdV: doc auth document_capture visited' => {
        flow_path: 'standard', step: 'document_capture', redo_document_capture: nil, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, analytics_id: 'Doc Auth', irs_reproofing: false
      },
      'Frontend: IdV: front image added' => {
        width: 284, height: 38, mimeType: 'image/png', source: 'upload', size: 3694, attempt: 1, flow_path: 'standard', acuant_sdk_upgrade_a_b_testing_enabled: 'false', use_alternate_sdk: anything, acuant_version: anything, acuantCaptureMode: nil, fingerprint: anything, failedImageResubmission: boolean, documentType: nil, dpi: nil, glare: nil, glareScoreThreshold: nil, isAssessedAsBlurry: nil, isAssessedAsGlare: nil, isAssessedAsUnsupported: nil, moire: nil, sharpness: nil, sharpnessScoreThreshold: nil, assessment: nil
      },
      'Frontend: IdV: back image added' => {
        width: 284, height: 38, mimeType: 'image/png', source: 'upload', size: 3694, attempt: 1, flow_path: 'standard', acuant_sdk_upgrade_a_b_testing_enabled: 'false', use_alternate_sdk: anything, acuant_version: anything, acuantCaptureMode: nil, fingerprint: anything, failedImageResubmission: boolean, documentType: nil, dpi: nil, glare: nil, glareScoreThreshold: nil, isAssessedAsBlurry: nil, isAssessedAsGlare: nil, isAssessedAsUnsupported: nil, moire: nil, sharpness: nil, sharpnessScoreThreshold: nil, assessment: nil
      },
      'IdV: doc auth image upload form submitted' => {
        success: true, errors: {}, attempts: 1, remaining_attempts: 3, user_id: user.uuid, flow_path: 'standard', front_image_fingerprint: an_instance_of(String), back_image_fingerprint: an_instance_of(String)
      },
      'IdV: doc auth image upload vendor pii validation' => {
        success: true, errors: {}, user_id: user.uuid, attempts: 1, remaining_attempts: 3, flow_path: 'standard', attention_with_barcode: false, front_image_fingerprint: an_instance_of(String), back_image_fingerprint: an_instance_of(String), classification_info: {}
      },
      'IdV: doc auth document_capture submitted' => {
        success: true, errors: {}, flow_path: 'standard', step: 'document_capture', redo_document_capture: nil, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, analytics_id: 'Doc Auth', irs_reproofing: false
      },
      'IdV: doc auth ssn visited' => {
        flow_path: 'standard', step: 'ssn', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, analytics_id: 'Doc Auth', irs_reproofing: false
      },
      'IdV: doc auth ssn submitted' => {
        success: true, errors: {}, flow_path: 'standard', step: 'ssn', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, analytics_id: 'Doc Auth', irs_reproofing: false
      },
      'IdV: doc auth verify visited' => {
        flow_path: 'standard', step: 'verify', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, analytics_id: 'Doc Auth', irs_reproofing: false
      },
      'IdV: doc auth verify submitted' => {
        flow_path: 'standard', step: 'verify', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, analytics_id: 'Doc Auth', irs_reproofing: false
      },
      'IdV: doc auth verify proofing results' => {
        success: true, errors: {}, flow_path: 'standard', address_edited: false, address_line2_present: false, analytics_id: 'Doc Auth', ssn_is_unique: true, step: 'verify', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, irs_reproofing: false, skip_hybrid_handoff: nil,
        proofing_results: { exception: nil, timed_out: false, threatmetrix_review_status: 'pass', context: { device_profiling_adjudication_reason: 'device_profiling_result_pass', resolution_adjudication_reason: 'pass_resolution_and_state_id', should_proof_state_id: true, stages: { resolution: { success: true, errors: {}, exception: nil, timed_out: false, transaction_id: 'resolution-mock-transaction-id-123', reference: 'aaa-bbb-ccc', can_pass_with_additional_verification: false, attributes_requiring_additional_verification: [], vendor_name: 'ResolutionMock', vendor_workflow: nil }, residential_address: { attributes_requiring_additional_verification: [], can_pass_with_additional_verification: false, errors: {}, exception: nil, reference: '', success: true, timed_out: false, transaction_id: '', vendor_name: 'ResidentialAddressNotRequired', vendor_workflow: nil }, state_id: { success: true, errors: {}, exception: nil, mva_exception: nil, timed_out: false, transaction_id: 'state-id-mock-transaction-id-456', vendor_name: 'StateIdMock', verified_attributes: [], state: 'MT', state_id_jurisdiction: 'ND', state_id_number: '#############' }, threatmetrix: threatmetrix_response } } }
      },
      'IdV: phone of record visited' => {
        acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass' }
      },
      'IdV: USPS address letter requested' => {
        resend: false, phone_step_attempts: 0, first_letter_requested_at: nil, hours_since_first_letter: 0, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass' }
      },
      'IdV: request letter visited' => {
        letter_already_sent: false,
      },
      :idv_enter_password_visited => {
        address_verification_method: 'gpo', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'gpo_letter' }
      },
      'IdV: USPS address letter enqueued' => {
        enqueued_at: Time.zone.now.utc, resend: false, phone_step_attempts: 0, first_letter_requested_at: Time.zone.now.utc, hours_since_first_letter: 0, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'gpo_letter' }
      },
      :idv_enter_password_submitted => {
        success: true, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: true, in_person_verification_pending: false, deactivation_reason: nil,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'gpo_letter' }
      },
      'IdV: final resolution' => {
        success: true, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: true, in_person_verification_pending: false, deactivation_reason: nil,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'gpo_letter' }
      },
      'IdV: letter enqueued visited' => {
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'gpo_letter' },
      },
    }
  end

  let(:in_person_path_events) do
    {
      'IdV: doc auth welcome visited' => {
        step: 'welcome', analytics_id: 'Doc Auth', irs_reproofing: false, skip_hybrid_handoff: nil, lexisnexis_instant_verify_workflow_ab_test_bucket: :default
      },
      'IdV: doc auth welcome submitted' => {
        step: 'welcome', analytics_id: 'Doc Auth', irs_reproofing: false, skip_hybrid_handoff: nil, lexisnexis_instant_verify_workflow_ab_test_bucket: :default
      },
      'IdV: doc auth agreement visited' => {
        step: 'agreement', analytics_id: 'Doc Auth', skip_hybrid_handoff: nil, irs_reproofing: false, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default
      },
      'IdV: doc auth agreement submitted' => {
        success: true, errors: {}, step: 'agreement', analytics_id: 'Doc Auth', skip_hybrid_handoff: nil, irs_reproofing: false, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default
      },
      'IdV: doc auth hybrid handoff visited' => {
        step: 'hybrid_handoff', redo_document_capture: nil, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, analytics_id: 'Doc Auth', skip_hybrid_handoff: nil, irs_reproofing: false
      },
      'IdV: doc auth hybrid handoff submitted' => {
        success: true, errors: {}, destination: :document_capture, flow_path: 'standard', redo_document_capture: nil, step: 'hybrid_handoff', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, analytics_id: 'Doc Auth', skip_hybrid_handoff: nil, irs_reproofing: false
      },
      'IdV: doc auth document_capture visited' => {
        flow_path: 'standard', step: 'document_capture', redo_document_capture: nil, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, analytics_id: 'Doc Auth', skip_hybrid_handoff: nil, irs_reproofing: false
      },
      'Frontend: IdV: front image added' => {
        width: 284, height: 38, mimeType: 'image/png', source: 'upload', size: 3694, attempt: 1, flow_path: 'standard', acuant_sdk_upgrade_a_b_testing_enabled: 'false', use_alternate_sdk: anything, acuant_version: anything, acuantCaptureMode: nil, fingerprint: anything, failedImageResubmission: boolean, documentType: nil, dpi: nil, glare: nil, glareScoreThreshold: nil, isAssessedAsBlurry: nil, isAssessedAsGlare: nil, isAssessedAsUnsupported: nil, moire: nil, sharpness: nil, sharpnessScoreThreshold: nil, assessment: nil
      },
      'Frontend: IdV: back image added' => {
        width: 284, height: 38, mimeType: 'image/png', source: 'upload', size: 3694, attempt: 1, flow_path: 'standard', acuant_sdk_upgrade_a_b_testing_enabled: 'false', use_alternate_sdk: anything, acuant_version: anything, acuantCaptureMode: nil, fingerprint: anything, failedImageResubmission: boolean, documentType: nil, dpi: nil, glare: nil, glareScoreThreshold: nil, isAssessedAsBlurry: nil, isAssessedAsGlare: nil, isAssessedAsUnsupported: nil, moire: nil, sharpness: nil, sharpnessScoreThreshold: nil, assessment: nil
      },
      'IdV: doc auth image upload form submitted' => {
        success: true, errors: {}, attempts: 1, remaining_attempts: 3, user_id: user.uuid, flow_path: 'standard', front_image_fingerprint: an_instance_of(String), back_image_fingerprint: an_instance_of(String)
      },
      'IdV: doc auth image upload vendor submitted' => hash_including(success: true, flow_path: 'standard', attention_with_barcode: true, doc_auth_result: 'Attention'),
      'IdV: verify in person troubleshooting option clicked' => {
        flow_path: 'standard', opted_in_to_in_person_proofing: nil
      },
      'IdV: in person proofing location visited' => {
        flow_path: 'standard', opted_in_to_in_person_proofing: nil
      },
      'IdV: in person proofing location submitted' => {
        flow_path: 'standard', selected_location: '606 E JUNEAU AVE, MILWAUKEE, WI, 53202-9998', opted_in_to_in_person_proofing: nil
      },
      'IdV: in person proofing prepare visited' => {
        flow_path: 'standard', opted_in_to_in_person_proofing: nil
      },
      'IdV: in person proofing prepare submitted' => {
        flow_path: 'standard', opted_in_to_in_person_proofing: nil
      },
      'IdV: in person proofing state_id visited' => {
        step: 'state_id', flow_path: 'standard', step_count: 1, analytics_id: 'In Person Proofing', irs_reproofing: false, opted_in_to_in_person_proofing: nil
      },
      'IdV: in person proofing state_id submitted' => {
        success: true, flow_path: 'standard', step: 'state_id', step_count: 1, analytics_id: 'In Person Proofing', irs_reproofing: false, errors: {}, same_address_as_id: false, opted_in_to_in_person_proofing: nil
      },
      'IdV: in person proofing address visited' => {
        step: 'address', flow_path: 'standard', step_count: 1, analytics_id: 'In Person Proofing', irs_reproofing: false, same_address_as_id: false, opted_in_to_in_person_proofing: nil
      },
      'IdV: in person proofing residential address submitted' => {
        success: true, step: 'address', flow_path: 'standard', step_count: 1, analytics_id: 'In Person Proofing', irs_reproofing: false, errors: {}, same_address_as_id: false
      },
      'IdV: doc auth ssn visited' => {
        analytics_id: 'In Person Proofing', step: 'ssn', flow_path: 'standard', irs_reproofing: false, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, same_address_as_id: false
      },
      'IdV: doc auth ssn submitted' => {
        analytics_id: 'In Person Proofing', success: true, step: 'ssn', flow_path: 'standard', irs_reproofing: false, errors: {}, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, same_address_as_id: false
      },
      'IdV: doc auth verify visited' => {
        analytics_id: 'In Person Proofing', step: 'verify', flow_path: 'standard', irs_reproofing: false, same_address_as_id: false, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil
      },
      'IdV: doc auth verify submitted' => {
        analytics_id: 'In Person Proofing', step: 'verify', flow_path: 'standard', irs_reproofing: false, same_address_as_id: false, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil
      },
      'IdV: doc auth verify proofing results' => {
        success: true, errors: {}, flow_path: 'standard', address_edited: false, address_line2_present: false, analytics_id: 'In Person Proofing', ssn_is_unique: true, step: 'verify', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, irs_reproofing: false, same_address_as_id: false, skip_hybrid_handoff: nil,
        proofing_results: { exception: nil, timed_out: false, threatmetrix_review_status: 'pass', context: { device_profiling_adjudication_reason: 'device_profiling_result_pass', resolution_adjudication_reason: 'pass_resolution_and_state_id', should_proof_state_id: true, stages: { resolution: { success: true, errors: {}, exception: nil, timed_out: false, transaction_id: 'resolution-mock-transaction-id-123', reference: 'aaa-bbb-ccc', can_pass_with_additional_verification: false, attributes_requiring_additional_verification: [], vendor_name: 'ResolutionMock', vendor_workflow: nil }, residential_address: { errors: {}, exception: nil, reference: 'aaa-bbb-ccc', success: true, timed_out: false, transaction_id: 'resolution-mock-transaction-id-123', can_pass_with_additional_verification: false, attributes_requiring_additional_verification: [], vendor_name: 'ResolutionMock', vendor_workflow: nil }, state_id: { success: true, errors: {}, exception: nil, mva_exception: nil, timed_out: false, transaction_id: 'state-id-mock-transaction-id-456', vendor_name: 'StateIdMock', verified_attributes: [], state: 'MT', state_id_jurisdiction: 'ND', state_id_number: '#############' }, threatmetrix: threatmetrix_response } } }
      },
      'IdV: phone confirmation form' => {
        success: true, errors: {}, phone_type: :mobile, types: [:fixed_or_mobile], carrier: 'Test Mobile Carrier', country_code: 'US', area_code: '202', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, otp_delivery_preference: 'sms',
        proofing_components: { document_check: 'usps', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', source_check: 'aamva' }
      },
      'IdV: phone confirmation vendor' => {
        success: true, errors: {}, vendor: { exception: nil, vendor_name: 'AddressMock', transaction_id: 'address-mock-transaction-id-123', timed_out: false, reference: '' }, new_phone_added: false, hybrid_handoff_phone_used: false, area_code: '202', country_code: 'US', phone_fingerprint: anything,
        proofing_components: { address_check: 'lexis_nexis_address', document_check: 'usps', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', source_check: 'aamva' }
      },
      'IdV: phone confirmation otp sent' => {
        success: true, otp_delivery_preference: :sms, country_code: 'US', area_code: '202', adapter: :test, errors: {}, phone_fingerprint: anything, rate_limit_exceeded: false, telephony_response: anything,
        proofing_components: { address_check: 'lexis_nexis_address', document_check: 'usps', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', source_check: 'aamva' }
      },
      'IdV: phone confirmation otp visited' => {
        proofing_components: { address_check: 'lexis_nexis_address', document_check: 'usps', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', source_check: 'aamva' },
      },
      'IdV: phone confirmation otp submitted' => {
        success: true, code_expired: false, code_matches: true, second_factor_attempts_count: 0, second_factor_locked_at: nil, errors: {},
        proofing_components: { document_check: 'usps', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      :idv_enter_password_visited => {
        acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, address_verification_method: 'phone',
        proofing_components: { document_check: 'usps', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      :idv_enter_password_submitted => {
        success: true, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: false, in_person_verification_pending: true, deactivation_reason: nil,
        proofing_components: { document_check: 'usps', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      'IdV: final resolution' => {
        success: true, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: false, in_person_verification_pending: true, deactivation_reason: nil,
        proofing_components: { document_check: 'usps', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      'IdV: personal key visited' => {
        in_person_verification_pending: true,
        proofing_components: { document_check: 'usps', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }, address_verification_method: 'phone'
      },
      'IdV: personal key acknowledgment toggled' => {
        checked: true,
        proofing_components: { document_check: 'usps', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' },
      },
      'IdV: personal key submitted' => {
        address_verification_method: 'phone', fraud_review_pending: false, fraud_rejection: false, in_person_verification_pending: true, deactivation_reason: nil,
        proofing_components: { document_check: 'usps', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      'IdV: in person ready to verify visited' => {
        proofing_components: { document_check: 'usps', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' },
      },
      'IdV: user clicked what to bring link on ready to verify page' => {},
      'IdV: user clicked sp link on ready to verify page' => {},
    }
  end

  let(:happy_selfie_path_events) do
    {
      'IdV: intro visited' => {},
      'IdV: doc auth welcome visited' => {
        step: 'welcome', analytics_id: 'Doc Auth', irs_reproofing: false, skip_hybrid_handoff: nil, lexisnexis_instant_verify_workflow_ab_test_bucket: :default
      },
      'IdV: doc auth welcome submitted' => {
        step: 'welcome', analytics_id: 'Doc Auth', irs_reproofing: false, skip_hybrid_handoff: nil, lexisnexis_instant_verify_workflow_ab_test_bucket: :default
      },
      'IdV: doc auth agreement visited' => {
        step: 'agreement', analytics_id: 'Doc Auth', skip_hybrid_handoff: nil, irs_reproofing: false, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default
      },
      'IdV: consent checkbox toggled' => {
        checked: true,
      },
      'IdV: doc auth agreement submitted' => {
        success: true, errors: {}, step: 'agreement', analytics_id: 'Doc Auth', skip_hybrid_handoff: nil, irs_reproofing: false, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default
      },
      'IdV: doc auth hybrid handoff visited' => {
        step: 'hybrid_handoff', redo_document_capture: nil, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, analytics_id: 'Doc Auth', skip_hybrid_handoff: nil, irs_reproofing: false
      },
      'IdV: doc auth hybrid handoff submitted' => {
        success: true, errors: {}, destination: :document_capture, flow_path: 'standard', step: 'hybrid_handoff', redo_document_capture: nil, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, analytics_id: 'Doc Auth', skip_hybrid_handoff: nil, irs_reproofing: false
      },
      'IdV: doc auth document_capture visited' => {
        flow_path: 'standard', step: 'document_capture', redo_document_capture: nil, skip_hybrid_handoff: nil, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, analytics_id: 'Doc Auth', irs_reproofing: false
      },
      'Frontend: IdV: front image added' => {
        width: 284, height: 38, mimeType: 'image/png', source: 'upload', size: 3694, attempt: 1, flow_path: 'standard', acuant_sdk_upgrade_a_b_testing_enabled: 'false', use_alternate_sdk: anything, acuant_version: anything, acuantCaptureMode: nil, fingerprint: anything, failedImageResubmission: boolean, documentType: nil, dpi: nil, glare: nil, glareScoreThreshold: nil, isAssessedAsBlurry: nil, isAssessedAsGlare: nil, isAssessedAsUnsupported: nil, moire: nil, sharpness: nil, sharpnessScoreThreshold: nil, assessment: nil
      },
      'Frontend: IdV: back image added' => {
        width: 284, height: 38, mimeType: 'image/png', source: 'upload', size: 3694, attempt: 1, flow_path: 'standard', acuant_sdk_upgrade_a_b_testing_enabled: 'false', use_alternate_sdk: anything, acuant_version: anything, acuantCaptureMode: nil, fingerprint: anything, failedImageResubmission: boolean, documentType: nil, dpi: nil, glare: nil, glareScoreThreshold: nil, isAssessedAsBlurry: nil, isAssessedAsGlare: nil, isAssessedAsUnsupported: nil, moire: nil, sharpness: nil, sharpnessScoreThreshold: nil, assessment: nil
      },
      'IdV: doc auth image upload form submitted' => {
        success: true, errors: {}, attempts: 1, remaining_attempts: 3, user_id: user.uuid, flow_path: 'standard', front_image_fingerprint: an_instance_of(String), back_image_fingerprint: an_instance_of(String)
      },
      'IdV: doc auth image upload vendor pii validation' => {
        success: true, errors: {}, user_id: user.uuid, attempts: 1, remaining_attempts: 3, flow_path: 'standard', attention_with_barcode: false, front_image_fingerprint: an_instance_of(String), back_image_fingerprint: an_instance_of(String), classification_info: {}
      },
      'IdV: doc auth document_capture submitted' => {
        success: true, errors: {}, flow_path: 'standard', step: 'document_capture', redo_document_capture: nil, skip_hybrid_handoff: nil, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, analytics_id: 'Doc Auth', irs_reproofing: false
      },
      :idv_selfie_image_file_uploaded => {
        acuant_sdk_upgrade_a_b_testing_enabled: 'false', acuant_version: anything, attempt: 1, failedImageResubmission: nil, fingerprint: 'aIzxkX_iMtoxFOURZr55qkshs53emQKUOr7VfTf6G1Q', flow_path: 'standard', height: 38, mimeType: 'image/png', size: 3694, source: 'upload', use_alternate_sdk: anything, width: 284
      },
      'IdV: doc auth ssn visited' => {
        flow_path: 'standard', step: 'ssn', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, analytics_id: 'Doc Auth', irs_reproofing: false
      },
      'IdV: doc auth ssn submitted' => {
        success: true, errors: {}, flow_path: 'standard', step: 'ssn', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, analytics_id: 'Doc Auth', irs_reproofing: false
      },
      'IdV: doc auth verify visited' => {
        flow_path: 'standard', step: 'verify', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, analytics_id: 'Doc Auth', irs_reproofing: false
      },
      'IdV: doc auth verify submitted' => {
        flow_path: 'standard', step: 'verify', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, analytics_id: 'Doc Auth', irs_reproofing: false
      },
      'IdV: doc auth verify proofing results' => {
        success: true, errors: {}, flow_path: 'standard', address_edited: false, address_line2_present: false, analytics_id: 'Doc Auth', ssn_is_unique: true, step: 'verify', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, irs_reproofing: false, skip_hybrid_handoff: nil,
        proofing_results: { exception: nil, timed_out: false, threatmetrix_review_status: 'pass', context: { device_profiling_adjudication_reason: 'device_profiling_result_pass', resolution_adjudication_reason: 'pass_resolution_and_state_id', should_proof_state_id: true, stages: { resolution: { success: true, errors: {}, exception: nil, timed_out: false, transaction_id: 'resolution-mock-transaction-id-123', reference: 'aaa-bbb-ccc', can_pass_with_additional_verification: false, attributes_requiring_additional_verification: [], vendor_name: 'ResolutionMock', vendor_workflow: nil }, residential_address: { attributes_requiring_additional_verification: [], can_pass_with_additional_verification: false, errors: {}, exception: nil, reference: '', success: true, timed_out: false, transaction_id: '', vendor_name: 'ResidentialAddressNotRequired', vendor_workflow: nil }, state_id: { success: true, errors: {}, exception: nil, mva_exception: nil, timed_out: false, transaction_id: 'state-id-mock-transaction-id-456', vendor_name: 'StateIdMock', verified_attributes: [], state: 'MT', state_id_jurisdiction: 'ND', state_id_number: '#############' }, threatmetrix: threatmetrix_response } } }
      },
      'IdV: phone of record visited' => {
        acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass' }
      },
      'IdV: phone confirmation form' => {
        success: true, errors: {}, phone_type: :mobile, types: [:fixed_or_mobile], carrier: 'Test Mobile Carrier', country_code: 'US', area_code: '202', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, otp_delivery_preference: 'sms',
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass' }
      },
      'IdV: phone confirmation vendor' => {
        success: true, errors: {}, vendor: { exception: nil, vendor_name: 'AddressMock', transaction_id: 'address-mock-transaction-id-123', timed_out: false, reference: '' }, new_phone_added: false, hybrid_handoff_phone_used: false, area_code: '202', country_code: 'US', phone_fingerprint: anything,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      'IdV: phone confirmation otp sent' => {
        success: true, otp_delivery_preference: :sms, country_code: 'US', area_code: '202', adapter: :test, errors: {}, phone_fingerprint: anything, rate_limit_exceeded: false, telephony_response: anything,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      'IdV: phone confirmation otp visited' => {
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' },
      },
      'IdV: phone confirmation otp submitted' => {
        success: true, code_expired: false, code_matches: true, second_factor_attempts_count: 0, second_factor_locked_at: nil, errors: {},
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      :idv_enter_password_visited => {
        address_verification_method: 'phone', acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      :idv_enter_password_submitted => {
        success: true, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: false, in_person_verification_pending: false, deactivation_reason: nil,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      'IdV: final resolution' => {
        success: true, acuant_sdk_upgrade_ab_test_bucket: :default, lexisnexis_instant_verify_workflow_ab_test_bucket: :default, skip_hybrid_handoff: nil, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: false, in_person_verification_pending: false, deactivation_reason: nil,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      'IdV: personal key visited' => {
        address_verification_method: 'phone', in_person_verification_pending: false,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
      'IdV: personal key acknowledgment toggled' => {
        checked: true,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' },
      },
      'IdV: personal key submitted' => {
        address_verification_method: 'phone', fraud_review_pending: false, fraud_rejection: false, in_person_verification_pending: false, deactivation_reason: nil,
        proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }
      },
    }
  end
  # rubocop:enable Layout/LineLength
  # rubocop:enable Layout/MultilineHashKeyLineBreaks

  # Needed for enqueued_at in RequestLetter
  around do |ex|
    freeze_time { ex.run }
  end

  before do
    allow(IdentityConfig.store).to receive(:proofing_device_profiling).
      and_return(proofing_device_profiling)
    allow_any_instance_of(ApplicationController).to receive(:analytics) do |controller|
      fake_analytics.user = controller.analytics_user
      fake_analytics
    end
    allow(IdentityConfig.store).to receive(:idv_acuant_sdk_upgrade_a_b_testing_enabled).
      and_return(false)
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
      let(:threatmetrix_response) do
        { client: 'tmx_disabled',
          success: true,
          errors: {},
          exception: nil,
          timed_out: false,
          transaction_id: nil,
          review_status: 'pass',
          response_body: { error: 'TMx response body was empty' } }
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
      let(:threatmetrix_response) do
        { client: 'tmx_disabled',
          success: true,
          errors: {},
          exception: nil,
          timed_out: false,
          transaction_id: nil,
          review_status: 'pass',
          response_body: { error: 'TMx response body was empty' } }
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
      gpo_path_events.each do |event, attributes|
        expect(fake_analytics).to have_logged_event(event, attributes)
      end
    end

    context 'proofing_device_profiling disabled' do
      let(:proofing_device_profiling) { :disabled }
      let(:threatmetrix) { false }
      let(:threatmetrix_response) do
        { client: 'tmx_disabled',
          success: true,
          errors: {},
          exception: nil,
          timed_out: false,
          transaction_id: nil,
          review_status: 'pass',
          response_body: { error: 'TMx response body was empty' } }
      end

      it 'records all of the events' do
        gpo_path_events.each do |event, attributes|
          expect(fake_analytics).to have_logged_event(event, attributes)
        end
      end
    end
  end

  context 'in person path' do
    let(:return_sp_url) { 'https://example.com/some/idv/ipp/url' }

    before do
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled).and_return(false)
      allow(Idv::InPersonConfig).to receive(:enabled_for_issuer?).and_return(true)
      allow_any_instance_of(Idv::InPerson::ReadyToVerifyPresenter).
        to receive(:service_provider_homepage_url).and_return(return_sp_url)
      allow_any_instance_of(Idv::InPerson::ReadyToVerifyPresenter).
        to receive(:sp_name).and_return(sp_friendly_name)

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
      let(:threatmetrix) { false }
      let(:threatmetrix_response) do
        { client: 'tmx_disabled',
          success: true,
          errors: {},
          exception: nil,
          timed_out: false,
          transaction_id: nil,
          review_status: 'pass',
          response_body: { error: 'TMx response body was empty' } }
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

  context 'Happy selfie path' do
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_selfie_capture_enabled).and_return(true)

      mobile_device = Browser.new(mobile_user_agent)
      allow(BrowserCache).to receive(:parse).and_return(mobile_device)

      perform_in_browser(:mobile) do
        sign_in_and_2fa_user(user)
        visit_idp_from_sp_with_ial2(:oidc)
        complete_doc_auth_steps_before_document_capture_step

        attach_images
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
      happy_selfie_path_events.each do |event, attributes|
        expect(fake_analytics).to have_logged_event(event, attributes)
      end
    end

    context 'proofing_device_profiling disabled' do
      let(:proofing_device_profiling) { :disabled }
      let(:threatmetrix) { false }
      let(:threatmetrix_response) do
        { client: 'tmx_disabled',
          success: true,
          errors: {},
          exception: nil,
          timed_out: false,
          transaction_id: nil,
          review_status: 'pass',
          response_body: { error: 'TMx response body was empty' } }
      end

      it 'records all of the events' do
        aggregate_failures 'analytics events' do
          happy_selfie_path_events.each do |event, attributes|
            expect(fake_analytics).to have_logged_event(event, attributes)
          end
        end
      end
    end
  end
end
