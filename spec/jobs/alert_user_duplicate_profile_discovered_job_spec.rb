require 'rails_helper'

RSpec.describe AlertUserDuplicateProfileDiscoveredJob do
  let(:user) { create(:user) }
  let(:agency) { 'Test Agency' }
  let(:email1) { user.email_addresses.first }
  let(:job_analytics) { FakeAnalytics.new }

  before do
    allow(user).to receive(:confirmed_email_addresses).and_return([email1])
  end

  describe '#perform' do
    context 'when type is :account_created' do
      it 'sends dupe_profile_created email for each confirmed email address' do
        expect_any_instance_of(UserMailer).to receive(:dupe_profile_created)
          .with(agency_name: agency)
          .and_call_original

        subject.perform(user: user, agency: agency, type: :account_verified)
      end

      context 'when phone is present' do
        let(:user) { create(:user, :with_phone) }

        it 'sends a dupe profile created SMS' do
          user_phone = user.phone_configurations.first.phone
          expect(Telephony).to receive(:send_dupe_profile_created_notice)
            .with(to: user_phone, country_code: 'US')

          subject.perform(user: user, agency: agency, type: :account_verified)
        end
      end

      context 'with multiple emails' do
        let(:user) { create(:user, :with_multiple_emails, :with_phone) }

        it 'sends dupe_profile_created email for each confirmed email address' do
          user.confirmed_email_addresses.each do |_email|
            expect_any_instance_of(UserMailer).to receive(:dupe_profile_created)
              .with(agency_name: agency)
              .and_call_original
          end

          subject.perform(user: user, agency: agency, type: :account_verified)
        end

        it 'only sends one text per user' do
          expect(Telephony).to receive(:send_dupe_profile_created_notice)
            .with(to: user.phone_configurations.first.phone, country_code: 'US')
            .once

          subject.perform(user: user, agency: agency, type: :account_verified)
        end
      end
    end

    context 'when type is :sign_in_attempted' do
      it 'sends dupe_profile_sign_in_attempted email for each confirmed email address' do
        expect_any_instance_of(UserMailer).to receive(:dupe_profile_sign_in_attempted)
          .with(agency_name: agency)
          .and_call_original

        subject.perform(user: user, agency: agency, type: :sign_in)
      end

      context 'when phone is present' do
        let(:user) { create(:user, :with_phone) }

        it 'sends a dupe profile sign in attempted SMS' do
          user_phone = user.phone_configurations.first.phone
          expect(Telephony).to receive(:send_dupe_profile_sign_in_attempted_notice)
            .with(to: user_phone, country_code: 'US')

          subject.perform(user: user, agency: agency, type: :sign_in)
        end
      end

      context 'with multiple emails' do
        let(:user) { create(:user, :with_multiple_emails, :with_phone) }

        it 'sends dupe_profile_sign_in_attempted email for each confirmed email address' do
          user.confirmed_email_addresses.each do |_email|
            expect_any_instance_of(UserMailer).to receive(:dupe_profile_sign_in_attempted)
              .with(agency_name: agency)
              .and_call_original
          end

          subject.perform(user: user, agency: agency, type: :sign_in)
        end

        it 'only sends one text per user' do
          expect(Telephony).to receive(:send_dupe_profile_sign_in_attempted_notice)
            .with(to: user.phone_configurations.first.phone, country_code: 'US')
            .once

          subject.perform(user: user, agency: agency, type: :sign_in)
        end
      end
    end
  end
end
