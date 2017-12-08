require 'rails_helper'

RSpec.describe Idv::SubmitIdvJob do
  subject(:service) do
    Idv::SubmitIdvJob.new(
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
        },
      }
    )
  end

  let(:user) { build(:user) }
  let(:applicant) { Proofer::Applicant.new(first_name: 'Greatest') }
  let(:vendor_session_id) { '12345' }
  let(:result_id) { 'abcdef' }
  let(:vendor_params) { { dob: '01/01/1985' } }

  describe '#submit_profile_job' do
    it 'generates a UUID and enqueues a Idv::ProfileJob and saves the UUID in the session' do
      expect(Idv::ProfileJob).to receive(:perform_later).
        with(
          result_id: result_id,
          vendor_params: vendor_params,
          vendor_session_id: vendor_session_id,
          applicant_json: applicant.to_json
        )

      expect(idv_session.async_result_id).to eq(nil)
      expect(idv_session.async_result_started_at).to eq(nil)

      expect(SecureRandom).to receive(:uuid).and_return(result_id).once

      service.submit_profile_job

      expect(idv_session.async_result_id).to eq(result_id)
      expect(idv_session.async_result_started_at).to be_within(1).of(Time.zone.now.to_i)
    end
  end

  describe '#submit_phone_job' do
    let(:vendor_params) { '5555550000' }

    it 'generates a UUID and enqueues a Idv::PhoneJob and saves the UUID in the session' do
      expect(Idv::PhoneJob).to receive(:perform_later).
        with(
          result_id: result_id,
          vendor_params: vendor_params,
          vendor_session_id: vendor_session_id,
          applicant_json: applicant.to_json
        )

      expect(idv_session.async_result_id).to eq(nil)
      expect(idv_session.async_result_started_at).to eq(nil)

      expect(SecureRandom).to receive(:uuid).and_return(result_id).once

      service.submit_phone_job

      expect(idv_session.async_result_id).to eq(result_id)
      expect(idv_session.async_result_started_at).to be_within(1).of(Time.zone.now.to_i)
    end
  end
end
