# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReviewAppUserSeeder do
  describe '#run' do
    subject(:run) { described_class.new.run }

    context 'when KUBERNETES_REVIEW_APP is not set' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('KUBERNETES_REVIEW_APP').and_return(nil)
      end

      it 'does not create any users' do
        expect { run }.to_not change(User, :count)
      end
    end

    context 'when KUBERNETES_REVIEW_APP is set to true' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('KUBERNETES_REVIEW_APP').and_return('true')
      end

      it 'creates users for each role' do
        expect { run }.to change(User, :count).by(5)
      end

      it 'creates users with correct emails' do
        run

        ReviewAppUserSeeder::REVIEW_APP_USERS.each do |email|
          expect(User.find_with_email(email)).to be_present
        end
      end

      it 'sets up password for each user' do
        run

        ReviewAppUserSeeder::REVIEW_APP_USERS.each do |email|
          user = User.find_with_email(email)
          expect(user.valid_password?(ReviewAppUserSeeder::DEFAULT_PASSWORD)).to be(true)
        end
      end

      it 'sets up phone MFA for each user' do
        run

        ReviewAppUserSeeder::REVIEW_APP_USERS.each do |email|
          user = User.find_with_email(email)
          expect(MfaContext.new(user).phone_configurations.count).to eq(1)
        end
      end
    end
  end
end
