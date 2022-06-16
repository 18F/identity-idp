require 'rails_helper'

RSpec.describe UserSeeder do
  let(:valid_fixture) { 'spec/fixtures/valid_user_csv.csv' }

  describe '.new' do
    it 'raises the appropriate error with missing CSV file' do
      opts = { csv_file: 'does_not_exist.csv', email_domain: 'foo.com' }

      expect { described_class.new(**opts) }.to \
        raise_error(ArgumentError, /does not exist/)
    end

    it 'raises the appropriate error with invalid CSV file' do
      opts = {
        csv_file: 'spec/fixtures/invalid_user_csv.csv',
        email_domain: 'foo.com',
      }

      expect { described_class.new(**opts) }.to \
        raise_error(ArgumentError, /must be a CSV file with headers/)
    end

    it 'raises the appropriate error with invalid email domain' do
      opts = { csv_file: valid_fixture, email_domain: 'foo_com' }

      expect { described_class.new(**opts) }.to \
        raise_error(ArgumentError, /is not a valid hostname/)
    end
  end

  describe '.run' do
    it 'raises the appropriate error when running in prod' do
      opts = { csv_file: valid_fixture, email_domain: 'foo.com', deploy_env: 'prod' }

      expect { described_class.run(**opts) }.to \
        raise_error(StandardError, /This cannot be run in staging or production/)
    end

    it 'raises the appropriate error when running in staging' do
      opts = { csv_file: valid_fixture, email_domain: 'foo.com', deploy_env: 'staging' }

      expect { described_class.run(**opts) }.to \
        raise_error(StandardError, /This cannot be run in staging or production/)
    end

    it 'defaults to the value in Identity::Hostdata.env' do
      opts = { csv_file: valid_fixture, email_domain: 'foo.com' }
      allow(Identity::Hostdata).to receive(:env).and_return('prod')

      expect { described_class.run(**opts) }.to \
        raise_error(StandardError, /This cannot be run in staging or production/)
    end

    context 'when an email address is already taken' do
      let(:taken_email) { 'user1@foo.com' }
      let(:opts) { { csv_file: valid_fixture, email_domain: 'foo.com' } }

      before { create_user_with_email(taken_email) }

      it 'raises the appropriate error' do
        expect { described_class.run(**opts) }.to \
          raise_error(ArgumentError, /invalid - would overwrite existing users/)
      end

      it 'does not persist any users' do
        described_class.run(**opts)
      rescue ArgumentError
        expect(User.count).to eq(1)
      end

      def create_user_with_email(email)
        user = User.create!
        EmailAddress.create!(user: user, email: email, confirmed_at: Time.zone.now)
        user.reset_password('S00per Seekret', 'S00per Seekret')
      end
    end

    context 'with valid inputs' do
      let(:opts) { { csv_file: valid_fixture, email_domain: 'foo.com' } }
      let(:output_file) { valid_fixture.gsub('.csv', '-updated.csv') }

      after { File.delete(output_file) }

      it 'creates the right number of users' do
        expect { described_class.run(**opts) }.to change { User.count }.by(2)
      end

      it 'returns the number of users created' do
        expect(described_class.run(**opts)).to eq(2)
      end

      it 'creates verified users' do
        described_class.run(**opts)

        expect(User.all.all? { |u| u.active_profile.present? }).to be_truthy
      end

      it 'saves the credentials to a CSV' do
        described_class.run(**opts)

        expect(File.read(output_file)).to \
          match(/email_address,password,codes,personal_key\n/)
      end
    end
  end
end
