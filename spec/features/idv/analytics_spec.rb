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
  let(:happy_path_events) do
    {
      'IdV: intro visited' => {},
      'IdV: doc auth welcome visited' => { step: 'welcome', analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth welcome submitted' => { step: 'welcome', analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth agreement visited' => { step: 'agreement', analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: consent checkbox toggled' => { checked: true },
      'IdV: doc auth agreement submitted' => { success: true, errors: {}, step: 'agreement', analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth hybrid handoff visited' => { step: 'hybrid_handoff', acuant_sdk_upgrade_ab_test_bucket: :default, analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth hybrid handoff submitted' => { success: true, errors: {}, destination: :document_capture, flow_path: 'standard', step: 'hybrid_handoff', acuant_sdk_upgrade_ab_test_bucket: :default, analytics_id: 'Doc Auth', irs_reproofing: false, skip_upload_step: false },
      'IdV: doc auth document_capture visited' => { flow_path: 'standard', step: 'document_capture', acuant_sdk_upgrade_ab_test_bucket: :default, analytics_id: 'Doc Auth', irs_reproofing: false },
      'Frontend: IdV: front image added' => { 'width' => 284, 'height' => 38, 'mimeType' => 'image/png', 'source' => 'upload', 'size' => 3694, 'attempt' => 1, 'flow_path' => 'standard', 'acuant_sdk_upgrade_a_b_testing_enabled' => 'false', 'use_alternate_sdk' => anything, 'acuant_version' => anything },
      'Frontend: IdV: back image added' => { 'width' => 284, 'height' => 38, 'mimeType' => 'image/png', 'source' => 'upload', 'size' => 3694, 'attempt' => 1, 'flow_path' => 'standard', 'acuant_sdk_upgrade_a_b_testing_enabled' => 'false', 'use_alternate_sdk' => anything, 'acuant_version' => anything },
      'IdV: doc auth image upload form submitted' => { success: true, errors: {}, attempts: 1, remaining_attempts: 3, user_id: user.uuid, flow_path: 'standard', front_image_fingerprint: an_instance_of(String), back_image_fingerprint: an_instance_of(String) },
      'IdV: doc auth image upload vendor pii validation' => { success: true, errors: {}, user_id: user.uuid, attempts: 1, remaining_attempts: 3, flow_path: 'standard', attention_with_barcode: false, front_image_fingerprint: an_instance_of(String), back_image_fingerprint: an_instance_of(String) },
      'IdV: doc auth document_capture submitted' => { success: true, errors: {}, flow_path: 'standard', step: 'document_capture', acuant_sdk_upgrade_ab_test_bucket: :default, analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth ssn visited' => { flow_path: 'standard', step: 'ssn', acuant_sdk_upgrade_ab_test_bucket: :default, analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth ssn submitted' => { success: true, errors: {}, flow_path: 'standard', step: 'ssn', acuant_sdk_upgrade_ab_test_bucket: :default, analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth verify visited' => { flow_path: 'standard', step: 'verify', acuant_sdk_upgrade_ab_test_bucket: :default, analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth verify submitted' => { flow_path: 'standard', step: 'verify', acuant_sdk_upgrade_ab_test_bucket: :default, analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth verify proofing results' => { success: true, errors: {}, address_edited: false, address_line2_present: false, ssn_is_unique: true, proofing_results: { exception: nil, timed_out: false, threatmetrix_review_status: 'pass', context: { device_profiling_adjudication_reason: 'device_profiling_result_pass', double_address_verification: false, resolution_adjudication_reason: 'pass_resolution_and_state_id', should_proof_state_id: true, stages: { resolution: { success: true, errors: {}, exception: nil, timed_out: false, transaction_id: 'resolution-mock-transaction-id-123', reference: 'aaa-bbb-ccc', can_pass_with_additional_verification: false, attributes_requiring_additional_verification: [], vendor_name: 'ResolutionMock', vendor_workflow: nil }, residential_address: { errors: {}, exception: nil, reference: '', success: true, timed_out: false, transaction_id: '', vendor_name: 'ResidentialAddressNotRequired' }, state_id: { success: true, errors: {}, exception: nil, mva_exception: nil, timed_out: false, transaction_id: 'state-id-mock-transaction-id-456', vendor_name: 'StateIdMock', verified_attributes: [], state: 'MT', state_id_jurisdiction: 'ND', state_id_number: '#############' }, threatmetrix: threatmetrix_response } } } },
      'IdV: phone of record visited' => { proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass' } },
      'IdV: phone confirmation form' => { success: true, errors: {}, phone_type: :mobile, types: [:fixed_or_mobile], carrier: 'Test Mobile Carrier', country_code: 'US', area_code: '202', proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass' }, otp_delivery_preference: 'sms' },
      'IdV: phone confirmation vendor' => { success: true, errors: {}, vendor: { exception: nil, vendor_name: 'AddressMock', transaction_id: 'address-mock-transaction-id-123', timed_out: false, reference: '' }, new_phone_added: false, proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }, area_code: '202', country_code: 'US', phone_fingerprint: anything },
      'IdV: phone confirmation otp sent' => { success: true, otp_delivery_preference: :sms, country_code: 'US', area_code: '202', proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }, adapter: :test, errors: {}, phone_fingerprint: anything, rate_limit_exceeded: false, telephony_response: anything },
      'IdV: phone confirmation otp visited' => { proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' } },
      'IdV: phone confirmation otp submitted' => { success: true, code_expired: false, code_matches: true, second_factor_attempts_count: 0, second_factor_locked_at: nil, proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }, errors: {} },
      'IdV: review info visited' => { address_verification_method: 'phone', proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' } },
      'IdV: review complete' => { success: true, proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: false, deactivation_reason: nil },
      'IdV: final resolution' => { success: true, proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: false, deactivation_reason: nil },
      'IdV: personal key visited' => { address_verification_method: 'phone', proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' } },
      'IdV: personal key acknowledgment toggled' => { checked: true, proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' } },
      'IdV: personal key submitted' => { address_verification_method: 'phone', proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }, fraud_review_pending: false, fraud_rejection: false, deactivation_reason: nil },
    }
  end

  let(:gpo_path_events) do
    {
      'IdV: intro visited' => {},
      'IdV: doc auth welcome visited' => { step: 'welcome', analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth welcome submitted' => { step: 'welcome', analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth agreement visited' => { step: 'agreement', analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth agreement submitted' => { success: true, errors: {}, step: 'agreement', analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth hybrid handoff visited' => { step: 'hybrid_handoff', acuant_sdk_upgrade_ab_test_bucket: :default, analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth hybrid handoff submitted' => { success: true, errors: {}, destination: :document_capture, flow_path: 'standard', step: 'hybrid_handoff', acuant_sdk_upgrade_ab_test_bucket: :default, analytics_id: 'Doc Auth', irs_reproofing: false, skip_upload_step: false },
      'IdV: doc auth document_capture visited' => { flow_path: 'standard', step: 'document_capture', acuant_sdk_upgrade_ab_test_bucket: :default, analytics_id: 'Doc Auth', irs_reproofing: false },
      'Frontend: IdV: front image added' => { 'width' => 284, 'height' => 38, 'mimeType' => 'image/png', 'source' => 'upload', 'size' => 3694, 'attempt' => 1, 'flow_path' => 'standard', 'acuant_sdk_upgrade_a_b_testing_enabled' => 'false', 'use_alternate_sdk' => anything, 'acuant_version' => anything },
      'Frontend: IdV: back image added' => { 'width' => 284, 'height' => 38, 'mimeType' => 'image/png', 'source' => 'upload', 'size' => 3694, 'attempt' => 1, 'flow_path' => 'standard', 'acuant_sdk_upgrade_a_b_testing_enabled' => 'false', 'use_alternate_sdk' => anything, 'acuant_version' => anything },
      'IdV: doc auth image upload form submitted' => { success: true, errors: {}, attempts: 1, remaining_attempts: 3, user_id: user.uuid, flow_path: 'standard', front_image_fingerprint: an_instance_of(String), back_image_fingerprint: an_instance_of(String) },
      'IdV: doc auth image upload vendor pii validation' => { success: true, errors: {}, user_id: user.uuid, attempts: 1, remaining_attempts: 3, flow_path: 'standard', attention_with_barcode: false, front_image_fingerprint: an_instance_of(String), back_image_fingerprint: an_instance_of(String) },
      'IdV: doc auth document_capture submitted' => { success: true, errors: {}, flow_path: 'standard', step: 'document_capture', acuant_sdk_upgrade_ab_test_bucket: :default, analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth ssn visited' => { flow_path: 'standard', step: 'ssn', acuant_sdk_upgrade_ab_test_bucket: :default, analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth ssn submitted' => { success: true, errors: {}, flow_path: 'standard', step: 'ssn', acuant_sdk_upgrade_ab_test_bucket: :default, analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth verify visited' => { flow_path: 'standard', step: 'verify', acuant_sdk_upgrade_ab_test_bucket: :default, analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth verify submitted' => { flow_path: 'standard', step: 'verify', acuant_sdk_upgrade_ab_test_bucket: :default, analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth verify proofing results' => { success: true, errors: {}, address_edited: false, address_line2_present: false, ssn_is_unique: true, proofing_results: { exception: nil, timed_out: false, threatmetrix_review_status: 'pass', context: { device_profiling_adjudication_reason: 'device_profiling_result_pass', resolution_adjudication_reason: 'pass_resolution_and_state_id', double_address_verification: false, should_proof_state_id: true, stages: { resolution: { success: true, errors: {}, exception: nil, timed_out: false, transaction_id: 'resolution-mock-transaction-id-123', reference: 'aaa-bbb-ccc', can_pass_with_additional_verification: false, attributes_requiring_additional_verification: [], vendor_name: 'ResolutionMock', vendor_workflow: nil }, residential_address: { errors: {}, exception: nil, reference: '', success: true, timed_out: false, transaction_id: '', vendor_name: 'ResidentialAddressNotRequired' }, state_id: { success: true, errors: {}, exception: nil, mva_exception: nil, timed_out: false, transaction_id: 'state-id-mock-transaction-id-456', vendor_name: 'StateIdMock', verified_attributes: [], state: 'MT', state_id_jurisdiction: 'ND', state_id_number: '#############' }, threatmetrix: threatmetrix_response } } } },
      'IdV: phone of record visited' => { proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass' } },
      'IdV: USPS address letter requested' => { resend: false, proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass' } },
      'IdV: review info visited' => { address_verification_method: 'gpo', proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'gpo_letter' } },
      'IdV: USPS address letter enqueued' => { enqueued_at: Time.zone.now.utc, resend: false, proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'gpo_letter' } },
      'IdV: review complete' => { success: true, proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'gpo_letter' }, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: true, deactivation_reason: nil },
      'IdV: final resolution' => { success: true, proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'gpo_letter' }, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: true, deactivation_reason: nil },
      'IdV: come back later visited' => { proofing_components: { document_check: 'mock', document_type: 'state_id', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'gpo_letter' } },
    }
  end

  let(:in_person_path_events) do
    {
      'IdV: doc auth welcome visited' => { step: 'welcome', analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth welcome submitted' => { step: 'welcome', analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth agreement visited' => { step: 'agreement', analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth agreement submitted' => { success: true, errors: {}, step: 'agreement', analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth hybrid handoff visited' => { step: 'hybrid_handoff', acuant_sdk_upgrade_ab_test_bucket: :default, analytics_id: 'Doc Auth', irs_reproofing: false },
      'IdV: doc auth hybrid handoff submitted' => { success: true, errors: {}, destination: :document_capture, flow_path: 'standard', step: 'hybrid_handoff', acuant_sdk_upgrade_ab_test_bucket: :default, analytics_id: 'Doc Auth', irs_reproofing: false, skip_upload_step: false },
      'IdV: doc auth document_capture visited' => { flow_path: 'standard', step: 'document_capture', acuant_sdk_upgrade_ab_test_bucket: :default, analytics_id: 'Doc Auth', irs_reproofing: false },
      'Frontend: IdV: front image added' => { 'width' => 284, 'height' => 38, 'mimeType' => 'image/png', 'source' => 'upload', 'size' => 3694, 'attempt' => 1, 'flow_path' => 'standard', 'acuant_sdk_upgrade_a_b_testing_enabled' => 'false', 'use_alternate_sdk' => anything, 'acuant_version' => anything },
      'Frontend: IdV: back image added' => { 'width' => 284, 'height' => 38, 'mimeType' => 'image/png', 'source' => 'upload', 'size' => 3694, 'attempt' => 1, 'flow_path' => 'standard', 'acuant_sdk_upgrade_a_b_testing_enabled' => 'false', 'use_alternate_sdk' => anything, 'acuant_version' => anything },
      'IdV: doc auth image upload form submitted' => { success: true, errors: {}, attempts: 1, remaining_attempts: 3, user_id: user.uuid, flow_path: 'standard', front_image_fingerprint: an_instance_of(String), back_image_fingerprint: an_instance_of(String) },
      'IdV: doc auth image upload vendor submitted' => hash_including(success: true, flow_path: 'standard', attention_with_barcode: true, doc_auth_result: 'Attention'),
      'IdV: verify in person troubleshooting option clicked' => { flow_path: 'standard' },
      'IdV: in person proofing location visited' => { flow_path: 'standard' },
      'IdV: in person proofing location submitted' => { flow_path: 'standard', selected_location: '606 E JUNEAU AVE, MILWAUKEE, WI, 53202-9998' },
      'IdV: in person proofing prepare visited' => { flow_path: 'standard' },
      'IdV: in person proofing prepare submitted' => { flow_path: 'standard' },
      'IdV: in person proofing state_id visited' => { step: 'state_id', flow_path: 'standard', step_count: 1, analytics_id: 'In Person Proofing', irs_reproofing: false },
      'IdV: in person proofing state_id submitted' => { success: true, flow_path: 'standard', step: 'state_id', step_count: 1, analytics_id: 'In Person Proofing', irs_reproofing: false, errors: {}, same_address_as_id: nil },
      'IdV: in person proofing address visited' => { step: 'address', flow_path: 'standard', step_count: 1, analytics_id: 'In Person Proofing', irs_reproofing: false },
      'IdV: in person proofing address submitted' => { success: true, step: 'address', flow_path: 'standard', step_count: 1, analytics_id: 'In Person Proofing', irs_reproofing: false, errors: {}, same_address_as_id: true },
      'IdV: doc auth ssn visited' => { analytics_id: 'In Person Proofing', step: 'ssn', flow_path: 'standard', step_count: 1, irs_reproofing: false, same_address_as_id: true },
      'IdV: doc auth ssn submitted' => { analytics_id: 'In Person Proofing', success: true, step: 'ssn', flow_path: 'standard', step_count: 1, irs_reproofing: false, errors: {}, same_address_as_id: true },
      'IdV: doc auth verify visited' => { analytics_id: 'In Person Proofing', step: 'verify', flow_path: 'standard', irs_reproofing: false, same_address_as_id: true },
      'IdV: doc auth verify submitted' => { analytics_id: 'In Person Proofing', step: 'verify', flow_path: 'standard', irs_reproofing: false, same_address_as_id: true },
      'IdV: doc auth verify proofing results' => { success: true, errors: {}, address_edited: false, address_line2_present: false, ssn_is_unique: true, proofing_results: { exception: nil, timed_out: false, threatmetrix_review_status: 'pass', context: { device_profiling_adjudication_reason: 'device_profiling_result_pass', double_address_verification: false, resolution_adjudication_reason: 'pass_resolution_and_state_id', should_proof_state_id: true, stages: { resolution: { success: true, errors: {}, exception: nil, timed_out: false, transaction_id: 'resolution-mock-transaction-id-123', reference: 'aaa-bbb-ccc', can_pass_with_additional_verification: false, attributes_requiring_additional_verification: [], vendor_name: 'ResolutionMock', vendor_workflow: nil }, residential_address: { errors: {}, exception: nil, reference: '', success: true, timed_out: false, transaction_id: '', vendor_name: 'ResidentialAddressNotRequired' }, state_id: { success: true, errors: {}, exception: nil, mva_exception: nil, timed_out: false, transaction_id: 'state-id-mock-transaction-id-456', vendor_name: 'StateIdMock', verified_attributes: [], state: 'MT', state_id_jurisdiction: 'ND', state_id_number: '#############' }, threatmetrix: threatmetrix_response } } } },
      'IdV: phone confirmation form' => { success: true, errors: {}, phone_type: :mobile, types: [:fixed_or_mobile], carrier: 'Test Mobile Carrier', country_code: 'US', area_code: '202', proofing_components: { document_check: 'usps', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', source_check: 'aamva' }, otp_delivery_preference: 'sms' },
      'IdV: phone confirmation vendor' => { success: true, errors: {}, vendor: { exception: nil, vendor_name: 'AddressMock', transaction_id: 'address-mock-transaction-id-123', timed_out: false, reference: '' }, new_phone_added: false, proofing_components: { address_check: 'lexis_nexis_address', document_check: 'usps', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', source_check: 'aamva' }, area_code: '202', country_code: 'US', phone_fingerprint: anything },
      'IdV: phone confirmation otp sent' => { success: true, otp_delivery_preference: :sms, country_code: 'US', area_code: '202', proofing_components: { address_check: 'lexis_nexis_address', document_check: 'usps', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', source_check: 'aamva' }, adapter: :test, errors: {}, phone_fingerprint: anything, rate_limit_exceeded: false, telephony_response: anything },
      'IdV: phone confirmation otp visited' => { proofing_components: { address_check: 'lexis_nexis_address', document_check: 'usps', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', source_check: 'aamva' } },
      'IdV: phone confirmation otp submitted' => { success: true, code_expired: false, code_matches: true, second_factor_attempts_count: 0, second_factor_locked_at: nil, proofing_components: { document_check: 'usps', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }, errors: {} },
      'IdV: review info visited' => { proofing_components: { document_check: 'usps', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }, address_verification_method: 'phone' },
      'IdV: review complete' => { success: true, proofing_components: { document_check: 'usps', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: false, deactivation_reason: 'in_person_verification_pending' },
      'IdV: final resolution' => { success: true, proofing_components: { document_check: 'usps', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }, fraud_review_pending: false, fraud_rejection: false, gpo_verification_pending: false, deactivation_reason: 'in_person_verification_pending' },
      'IdV: personal key visited' => { proofing_components: { document_check: 'usps', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }, address_verification_method: 'phone' },
      'IdV: personal key acknowledgment toggled' => { checked: true, proofing_components: { document_check: 'usps', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' } },
      'IdV: personal key submitted' => { proofing_components: { document_check: 'usps', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' }, address_verification_method: 'phone', fraud_review_pending: false, fraud_rejection: false, deactivation_reason: 'in_person_verification_pending' },
      'IdV: in person ready to verify visited' => { proofing_components: { document_check: 'usps', source_check: 'aamva', resolution_check: 'lexis_nexis', threatmetrix: threatmetrix, threatmetrix_review_status: 'pass', address_check: 'lexis_nexis_address' } },
      'IdV: user clicked what to bring link on ready to verify page' => {},
      'IdV: user clicked sp link on ready to verify page' => {},
    }
  end
  # rubocop:enable Layout/LineLength

  # Needed for enqueued_at in gpo_step
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
      complete_review_step(user)
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
      gpo_step
      complete_review_step(user)
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
      allow(IdentityConfig.store).to receive(:in_person_capture_secondary_id_enabled).
        and_return(false)
      allow(Idv::InPersonConfig).to receive(:enabled_for_issuer?).and_return(true)
      allow_any_instance_of(Idv::InPerson::ReadyToVerifyPresenter).
        to receive(:service_provider_homepage_url).and_return(return_sp_url)
      allow_any_instance_of(Idv::InPerson::ReadyToVerifyPresenter).
        to receive(:sp_name).and_return(sp_friendly_name)

      start_idv_from_sp(:saml)
      sign_in_and_2fa_user(user)
      begin_in_person_proofing(user)
      complete_all_in_person_proofing_steps(user)
      complete_phone_step(user)
      complete_review_step(user)
      acknowledge_and_confirm_personal_key
      visit_help_center
      visit_sp
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
end
