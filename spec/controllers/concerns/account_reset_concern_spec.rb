require 'rails_helper'

RSpec.describe AccountResetConcern do
  include ActionView::Helpers::DateHelper
  let(:test_class) do
    Class.new do
      include AccountResetConcern

      attr_reader :current_user

      def initialize(current_user:)
        @current_user = current_user
      end
    end
  end
  let(:user) { build(:user) }
  let(:instance) { test_class.new(current_user: user) }

  describe '#account_reset_deletion_period_interval' do
    context 'non fraud user' do
      it 'should return regular wait time' do
        current_time = Time.zone.now
        time_in_hours = distance_of_time_in_words(
          current_time,
          current_time + IdentityConfig.store.account_reset_wait_period_days.days,
          true,
          accumulate_on: :hours,
        )
        expect(instance.account_reset_deletion_period_interval(user))
          .to eq(time_in_hours)
      end
    end

    context 'fraud user' do
      let(:user) { create(:user, :fraud_review_pending) }
      it 'should return fraud wait time' do
        current_time = Time.zone.now
        time_in_hours = distance_of_time_in_words(
          current_time,
          current_time + IdentityConfig.store.account_reset_fraud_user_wait_period_days.days,
          true,
          accumulate_on: :days,
        )
        expect(instance.account_reset_deletion_period_interval(user))
          .to eq(time_in_hours)
      end

      context 'when account_reset_fraud_user_wait_period_days is nil' do
        before do
          allow(IdentityConfig.store).to receive(:account_reset_fraud_user_wait_period_days)
            .and_return(nil)
        end

        it 'should return standard reset wait time' do
          current_time = Time.zone.now
          time_in_hours = distance_of_time_in_words(
            current_time,
            current_time + IdentityConfig.store.account_reset_wait_period_days.days,
            true,
            accumulate_on: :hours,
          )
          expect(instance.account_reset_deletion_period_interval(user))
            .to eq(time_in_hours)
        end
      end
    end
  end
end
