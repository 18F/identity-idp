require 'rails_helper'

RSpec.describe AccountRecoveryRequest do
  it { is_expected.to belong_to(:user) }

  let(:user) { create(:user, :fully_registered) }

  describe 'state predicates' do
    it 'reports active states as active and not terminal' do
      AccountRecoveryRequest::ACTIVE_STATES.each do |state|
        request = build(:account_recovery_request, state: state)

        expect(request.active?).to eq(true), "expected #{state} to be active"
        expect(request.terminal?).to eq(false), "expected #{state} not to be terminal"
      end
    end

    it 'reports terminal states as terminal and not active' do
      AccountRecoveryRequest::TERMINAL_STATES.each do |state|
        request = build(:account_recovery_request, state: state)

        expect(request.terminal?).to eq(true), "expected #{state} to be terminal"
        expect(request.active?).to eq(false), "expected #{state} not to be active"
      end
    end
  end

  describe '.active_for_user' do
    it 'returns the active request for the user' do
      request = create(:account_recovery_request, :waiting, user: user)

      expect(described_class.active_for_user(user)).to eq(request)
    end

    it 'ignores terminal requests' do
      create(:account_recovery_request, :cancelled, user: user)

      expect(described_class.active_for_user(user)).to be_nil
    end

    it 'ignores requests belonging to other users' do
      create(:account_recovery_request, :waiting, user: create(:user))

      expect(described_class.active_for_user(user)).to be_nil
    end
  end

  describe '#transition_to!' do
    it 'raises for an unknown state' do
      request = create(:account_recovery_request, user: user)

      expect { request.transition_to!('not_a_state') }.to raise_error(ArgumentError)
    end

    it 'applies an allowed transition and stamps the state timestamp' do
      request = create(:account_recovery_request, :granted, user: user)

      expect(request.transition_to!(AccountRecoveryRequest::LINK_VERIFIED)).to eq(true)

      request.reload
      expect(request.state).to eq(AccountRecoveryRequest::LINK_VERIFIED)
      expect(request.link_verified_at).to be_present
    end

    it 'refuses a disallowed transition without mutating the record' do
      request = create(:account_recovery_request, user: user)

      expect(request.transition_to!(AccountRecoveryRequest::COMPLETED)).to eq(false)

      request.reload
      expect(request.state).to eq(AccountRecoveryRequest::REQUESTED)
      expect(request.completed_at).to be_nil
    end

    it 'refuses every transition out of a terminal state' do
      AccountRecoveryRequest::TERMINAL_STATES.each do |terminal_state|
        request = create(
          :account_recovery_request,
          user: create(:user),
          state: terminal_state,
        )

        AccountRecoveryRequest::STATES.each do |next_state|
          expect(request.transition_to!(next_state)).to eq(false),
                                                        "#{terminal_state} -> #{next_state}"
        end

        expect(request.reload.state).to eq(terminal_state)
      end
    end

    it 'only permits the transitions listed in the state machine' do
      AccountRecoveryRequest::TRANSITIONS.each do |from_state, allowed_states|
        AccountRecoveryRequest::STATES.each do |to_state|
          request = build(:account_recovery_request, state: from_state)

          expect(request.can_transition_to?(to_state)).to eq(allowed_states.include?(to_state)),
                                                          "#{from_state} -> #{to_state}"
        end
      end
    end
  end

  describe '#wait!' do
    it 'moves a requested record to waiting' do
      request = create(:account_recovery_request, user: user)

      expect(request.wait!).to eq(true)
      expect(request.reload.state).to eq(AccountRecoveryRequest::WAITING)
    end
  end

  describe '#cancel!' do
    it 'records the reason and clears the token' do
      request = create(:account_recovery_request, :granted, user: user)

      expect(request.cancel!(reason: 'mfa_used')).to eq(true)

      request.reload
      expect(request.state).to eq(AccountRecoveryRequest::CANCELLED)
      expect(request.cancel_reason).to eq('mfa_used')
      expect(request.cancelled_at).to be_present
      expect(request.token_fingerprint).to be_nil
      expect(request.token_expires_at).to be_nil
    end
  end

  describe '#expire!' do
    it 'marks the record expired with a failure reason' do
      request = create(:account_recovery_request, :granted, user: user)

      expect(request.expire!(reason: 'token_ttl_elapsed')).to eq(true)

      request.reload
      expect(request.state).to eq(AccountRecoveryRequest::EXPIRED)
      expect(request.failure_reason).to eq('token_ttl_elapsed')
      expect(request.expired_at).to be_present
      expect(request.token_fingerprint).to be_nil
    end
  end

  describe '#token_valid?' do
    it 'is false without a fingerprint' do
      request = build(
        :account_recovery_request,
        token_fingerprint: nil,
        token_expires_at: Time.zone.now + 1.hour,
      )

      expect(request.token_valid?).to eq(false)
    end

    it 'is false when the token has expired' do
      request = build(
        :account_recovery_request,
        token_fingerprint: 'abc',
        token_expires_at: Time.zone.now - 1.second,
      )

      expect(request.token_valid?).to eq(false)
    end

    it 'is false when no expiration is recorded' do
      request = build(
        :account_recovery_request,
        token_fingerprint: 'abc',
        token_expires_at: nil,
      )

      expect(request.token_valid?).to eq(false)
    end

    it 'is true for an unexpired fingerprinted token' do
      request = build(
        :account_recovery_request,
        token_fingerprint: 'abc',
        token_expires_at: Time.zone.now + 1.hour,
      )

      expect(request.token_valid?).to eq(true)
    end
  end

  describe '#awaiting_link_redemption?' do
    it 'is true before the emailed link is redeemed' do
      [
        AccountRecoveryRequest::REQUESTED,
        AccountRecoveryRequest::WAITING,
        AccountRecoveryRequest::GRANTED,
      ].each do |state|
        request = build(:account_recovery_request, state: state)

        expect(request.awaiting_link_redemption?).to eq(true), "expected #{state} to be awaiting"
      end
    end

    # Once the link is redeemed the request sticks until replacement MFA is
    # added, so normal MFA use and token expiry must not act on it.
    it 'is false once the link has been redeemed' do
      [
        AccountRecoveryRequest::LINK_VERIFIED,
        AccountRecoveryRequest::PASSWORD_VERIFIED,
        AccountRecoveryRequest::REPLACEMENT_MFA_PENDING,
      ].each do |state|
        request = build(:account_recovery_request, state: state)

        expect(request.awaiting_link_redemption?).to eq(false),
                                                     "expected #{state} not to be awaiting"
      end
    end
  end

  describe '.active_for_token_fingerprint' do
    it 'finds an active request by recovery token fingerprint' do
      request = create(:account_recovery_request, :granted, user: user)

      expect(
        described_class.active_for_token_fingerprint(request.token_fingerprint),
      ).to eq(request)
    end

    it 'ignores terminal requests' do
      request = create(:account_recovery_request, :granted, user: user)
      fingerprint = request.token_fingerprint
      request.update!(state: AccountRecoveryRequest::CANCELLED, cancelled_at: Time.zone.now)

      expect(described_class.active_for_token_fingerprint(fingerprint)).to be_nil
    end

    it 'returns nil for a blank fingerprint' do
      create(:account_recovery_request, :granted, user: user)

      expect(described_class.active_for_token_fingerprint(nil)).to be_nil
      expect(described_class.active_for_token_fingerprint('')).to be_nil
    end
  end

  describe 'one active request per user' do
    it 'rejects a second active request at the database level' do
      create(:account_recovery_request, :waiting, user: user)

      expect do
        create(:account_recovery_request, :waiting, user: user)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows a new active request once the prior one is terminal' do
      create(:account_recovery_request, :cancelled, user: user)

      expect { create(:account_recovery_request, :waiting, user: user) }.to_not raise_error
    end
  end

  describe 'validations' do
    it 'rejects an unknown state' do
      request = build(:account_recovery_request, state: 'nonsense')

      expect(request).to_not be_valid
      expect(request.errors[:state]).to be_present
    end

    it 'does not expose removed recovery metadata' do
      expect(described_class.column_names).not_to include('flow_variant', 'requesting_issuer')
      expect(described_class.reflect_on_association(:requesting_service_provider)).to be_nil
    end
  end
end
