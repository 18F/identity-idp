require 'rails_helper'

describe Db::SpReturnLog do
  describe '#create_return' do
    # Can be removed after deploy of RC 185
    it 'updates return log if it already exists' do
      sp_return_log = SpReturnLog.create(
        request_id: SecureRandom.uuid,
        user_id: 1,
        billable: true,
        ial: 1,
        issuer: 'example.com',
        requested_at: Time.zone.now,
      )
      Db::SpReturnLog.create_return(
        request_id: sp_return_log.request_id,
        user_id: sp_return_log.user_id,
        billable: sp_return_log.billable,
        ial: sp_return_log.ial,
        issuer: sp_return_log.issuer,
        requested_at: sp_return_log.requested_at,
      )
      expect(sp_return_log.reload.returned_at).to_not be_nil
    end
  end
end
