require 'rails_helper'

RSpec.describe SecondMfaReminderConcern do
  let(:test_class) do
    Class.new do
      include SecondMfaReminderConcern

      attr_reader :current_user

      def initialize(current_user:)
        @current_user = current_user
      end
    end
  end
  let(:user) { build(:user) }
  let(:instance) { test_class.new(current_user: user) }

  describe '#user_needs_second_mfa_reminder?' do
    subject(:user_needs_second_mfa_reminder) { instance.user_needs_second_mfa_reminder? }

    context 'user has already dismissed second mfa reminder' do
      let(:user) { build(:user, second_mfa_reminder_dismissed_at: Time.zone.now) }

      it { expect(user_needs_second_mfa_reminder).to eq(false) }
    end

    context 'user has multiple mfas configured' do
      let(:user) { build(:user, :with_phone, :with_piv_or_cac) }

      it { expect(user_needs_second_mfa_reminder).to eq(false) }
    end

    context 'user has single mfa configured' do
      let(:user) { build(:user, :with_phone) }

      it { expect(user_needs_second_mfa_reminder).to eq(false) }

      context 'user has signed in more times than the threshold for reminder' do
        let(:user) do
          user = create(:user, :with_phone)
          2.times { user.events.create(event_type: :sign_in_before_2fa, created_at: Time.zone.now) }
          user
        end

        before do
          allow(IdentityConfig.store).to receive(:second_mfa_reminder_sign_in_count).and_return(2)
        end

        it { expect(user_needs_second_mfa_reminder).to eq(true) }
      end

      context 'user has exceeded account age threshold for reminder' do
        let(:user) { build(:user, :with_phone, created_at: 11.days.ago) }

        before do
          allow(IdentityConfig.store).to receive(:second_mfa_reminder_account_age_in_days).
            and_return(10)
        end

        it { expect(user_needs_second_mfa_reminder).to eq(true) }
      end

      context 'user meets threshold but feature is disabled' do
        let(:user) { build(:user, :with_phone, created_at: 11.days.ago) }

        before do
          allow(IdentityConfig.store).to receive(:second_mfa_reminder_account_age_in_days).
            and_return(10)
          allow(IdentityConfig.store).to receive(:second_mfa_reminder_enabled).and_return(false)
        end

        it { expect(user_needs_second_mfa_reminder).to eq(false) }
      end
    end
  end
end
