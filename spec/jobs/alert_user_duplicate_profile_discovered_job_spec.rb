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

        subject.perform(user: user, agency: agency, type: :account_created)
      end
    end

    context 'when type is :sign_in_attempted' do
      it 'sends dupe_profile_sign_in_attempted email for each confirmed email address' do
        expect_any_instance_of(UserMailer).to receive(:dupe_profile_sign_in_attempted)
          .with(agency_name: agency)
          .and_call_original

        subject.perform(user: user, agency: agency, type: :sign_in_attempted)
      end
    end

    context 'when type is invalid' do
      let(:invalid_type) { :invalid_type }

      it 'calls analytics duplicate_profile_email_type_not_found' do
        allow(subject).to receive(:analytics).with(user: user).and_return(job_analytics)
        expect(job_analytics)
          .to receive(:duplicate_profile_email_type_not_found)
          .with(type: invalid_type)

        subject.perform(user: user, agency: agency, type: invalid_type)
      end
    end
  end
end
