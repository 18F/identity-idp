require 'rails_helper'

RSpec.describe Idv::SubmitIdvJob do
  subject(:service) do
    Idv::SubmitIdvJob.new(
      idv_session: idv_session,
      vendor_params: vendor_params,
      stages: stages
    )
  end

  let(:idv_session) do
    Idv::Session.new(
      current_user: user,
      issuer: nil,
      user_session: {
        idv: {
          applicant: applicant,
        },
      }
    )
  end

  let(:user) { build(:user) }
  let(:applicant) { { first_name: 'Greatest' } }
  let(:result_id) { 'abcdef' }
  let(:vendor_params) { { dob: '01/01/1985' } }
  let(:stages) { %i[profile] }

  describe '#submit' do
    it 'generates a UUID and enqueues a Idv::ProoferJob and saves the UUID in the session' do
      expect(Idv::ProoferJob).to receive(:perform_later).
        with(
          result_id: result_id,
          applicant_json: applicant.merge(vendor_params).to_json,
          stages: stages.to_json
        )

      expect(idv_session.async_result_id).to eq(nil)
      expect(idv_session.async_result_started_at).to eq(nil)

      expect(SecureRandom).to receive(:uuid).and_return(result_id).once

      service.submit

      expect(idv_session.async_result_id).to eq(result_id)
      expect(idv_session.async_result_started_at).to be_within(1).of(Time.zone.now.to_i)
    end
  end
end
