require 'rails_helper'

RSpec.describe Idv::Job do
  let(:idv_session) do
    Idv::Session.
      new(current_user: build(:user), issuer: nil, user_session: {}).
      tap { |session| session.params = applicant }
  end

  let(:applicant) { { first_name: 'Greatest', dob: '01/01/1985' } }
  let(:result_id) { 'abcdef' }
  let(:stages) { %i[resolution] }

  describe '#submit' do
    it 'generates a UUID and enqueues a Idv::ProoferJob and saves the UUID in the session' do
      expect(Idv::ProoferJob).to receive(:perform_later).
        with(
          result_id: result_id,
          applicant_json: idv_session.vendor_params.to_json,
          stages: stages.to_json
        )

      expect(idv_session.async_result_id).to eq(nil)
      expect(idv_session.async_result_started_at).to eq(nil)

      expect(SecureRandom).to receive(:uuid).and_return(result_id).once

      Idv::Job.submit(idv_session, stages)

      expect(idv_session.async_result_id).to eq(result_id)
      expect(idv_session.async_result_started_at).to be_within(1).of(Time.zone.now.to_i)
    end
  end
end
