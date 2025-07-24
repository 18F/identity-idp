require 'rails_helper'

RSpec.describe AlertUserDuplicateProfileDiscoveredJob do
  let(:user) { create(:user) }
  let(:agency) { 'Test Agency' }
  let(:email1) { user.email_addresses.first }
  let(:job_analytics) { FakeAnalytics.new }
  let(:user_mailer) { double(UserMailer) }

  before do
    allow(user).to receive(:confirmed_email_addresses).and_return([email1])
    allow(UserMailer).to receive(:with).and_return(user_mailer)
  end

  describe '#perform' do
    context 'when type is :account_created' do
      it 'sends dupe_profile_created email for each confirmed email address' do
        expect(UserMailer).to receive(:with).with(user: user, email_address: email1)
        expect(user_mailer).to receive(:dupe_profile_created).with(agency_name: agency)

        subject.perform(user: user, agency: agency, type: :account_created)
      end
    end

    context 'when type is :sign_in_attempted' do
      it 'sends dupe_profile_sign_in_attempted email for each confirmed email address' do
        expect(UserMailer).to receive(:with).with(user: user, email_address: email1)
        expect(user_mailer).to receive(:dupe_profile_sign_in_attempted).with(agency_name: agency)

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

    context 'with multiple confirmed email addresses' do
      let(:email2) { create(:email_address, user: user) }
      let(:email_addresses) { [email1, email2] }

      before do
        allow(user).to receive(:confirmed_email_addresses).and_return(email_addresses)
      end

      it 'sends emails to all confirmed email addresses' do
        email_addresses.each do |email|
          expect(UserMailer).to receive(:with).with(user: user, email_address: email)
        end
        expect(mailer_double).to receive(:dupe_profile_created).twice.with(agency_name: agency)

        subject.perform(user: user, agency: agency, type: :account_created)
      end
    end
  end
end
