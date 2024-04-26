require 'rails_helper'

RSpec.describe BillableEventTrackable do
  let(:fake_controller_class) do
    Data.define(
      :ial_context,
      :current_sp,
      :current_user,
      :request_id,
      :user_session,
      :sp_session,
      :resolved_authn_context_result,
      :session,
    ) do
      include BillableEventTrackable
    end
  end

  let(:current_user) { create(:user) }
  let(:current_sp) { create(:service_provider) }
  let(:ial_context) { IalContext.new(ial: 1, service_provider: current_sp) }
  let(:request_id) { SecureRandom.hex }
  let(:session_started_at) { 5.minutes.ago }
  let(:active_profile) do
    create(
      :profile,
      :active,
      :verified,
      user: current_user,
      initiating_service_provider: current_sp,
    )
  end

  around do |ex|
    freeze_time { ex.run }
  end

  subject(:instance) do
    fake_controller_class.new(
      ial_context:,
      current_sp:,
      current_user:,
      request_id:,
      user_session: {},
      resolved_authn_context_result: double(identity_proofing?: false),
      sp_session: {
        issuer: current_sp.issuer,
      },
      session: {
        session_started_at:,
      },
    )
  end

  describe '#track_billing_events' do
    let(:ial_context) { IalContext.new(ial: 2, service_provider: current_sp) }
    it 'does not fail if SpReturnLog row already exists and ial 2' do
      # binding.pry
      SpReturnLog.create(
        request_id: request_id,
        user_id: current_user.id,
        billable: true,
        ial: ial_context.ial,
        issuer: current_sp.issuer,
        requested_at: session_started_at,
        returned_at: Time.zone.now,
        profile_id: active_profile.id,
        profile_verified_at: active_profile.verified_at,
        profile_requested_issuer: active_profile.initiating_service_provider.issuer,
      )

      expect do
        instance.track_billing_events
      end.to_not(change { SpReturnLog.count }.from(1))
      sp_return_log = SpReturnLog.last
      expect(sp_return_log.profile_id).to eq active_profile.id
      expect(sp_return_log.profile_verified_at).to eq active_profile.verified_at
      expect(sp_return_log.profile_requested_issuer).
        to eq active_profile.initiating_service_provider.issuer
    end

    let(:ial_context) { IalContext.new(ial: 1, service_provider: current_sp) }
    it 'does not fail if SpReturnLog row already exists and ial 1' do
      SpReturnLog.create(
        request_id: request_id,
        user_id: current_user.id,
        billable: true,
        ial: ial_context.ial,
        issuer: current_sp.issuer,
        requested_at: session_started_at,
        returned_at: Time.zone.now,
        profile_id: nil,
        profile_verified_at: nil,
        profile_requested_issuer: nil,
      )

      expect do
        instance.track_billing_events
      end.to_not(change { SpReturnLog.count }.from(1))
      sp_return_log = SpReturnLog.last
      expect(sp_return_log.profile_id).to be_nil
      expect(sp_return_log.profile_verified_at).to be_nil
      expect(sp_return_log.profile_requested_issuer).to be_nil
    end
  end
end
