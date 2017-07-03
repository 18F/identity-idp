require 'rails_helper'

RSpec.describe SubmitIdvJob do
  subject(:service) do
    SubmitIdvJob.new(
      vendor_validator_class: vendor_validator_class,
      idv_session: idv_session,
      vendor_params: vendor_params
    )
  end

  let(:idv_session) do
    Idv::Session.new(
      current_user: user,
      issuer: nil,
      user_session: {
        idv: {
          applicant: applicant,
          vendor_session_id: vendor_session_id,
          vendor: :mock,
        },
      }
    )
  end

  let(:user) { build(:user) }
  let(:applicant) { Proofer::Applicant.new(first_name: 'Greatest') }
  let(:vendor_session_id) { '12345' }
  let(:result_id) { 'abcdef' }
  let(:vendor_params) { '+1 (888) 123-4567' }
  let(:vendor_validator_class) { 'Idv::PhoneValidator' }

  describe '#call' do
    subject(:call) { service.call }

    it 'generates a UUID and enqueues a job, and saves the UUID in the session' do
      expect(SecureRandom).to receive(:uuid).and_return(result_id).once

      expect(VendorValidatorJob).to receive(:perform_now).
        with(
          result_id: result_id,
          vendor_validator_class: vendor_validator_class,
          vendor: :mock,
          vendor_params: vendor_params,
          vendor_session_id: vendor_session_id,
          applicant_json: applicant.to_json
        )

      expect { call }.
        to change { idv_session.async_result_id }.from(nil).to(result_id)
    end
  end
end
