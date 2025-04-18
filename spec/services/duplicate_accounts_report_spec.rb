require 'rails_helper'
RSpec.describe DuplicateAccountsReport do
  let(:issuer) { 'test_saml_sp_requesting_signed_response_message' }

  def create_user_with_ssn_signature(ssn_signature)
    create(
      :user,
      :fully_registered,
      profiles: [build(:profile, :active, :verified, ssn_signature: ssn_signature)],
    )
  end

  def create_service_provider_identity(user, last_authenticated_at)
    create(
      :service_provider_identity,
      ial: 2,
      service_provider: issuer,
      user: user,
      last_authenticated_at: last_authenticated_at,
    )
  end

  describe '#call' do
    context 'when no records exist' do
      it 'creates an empty results array' do
        results = DuplicateAccountsReport.call(issuer)
        expect(results.count).to eq(0)
      end
    end

    context 'when no ssn_signatures match' do
      it 'creates empty results' do
        freeze_time do
          user = create_user_with_ssn_signature('hashedssnsignaturekeytwo')
          user2 = create_user_with_ssn_signature('hashedssnsignaturekeyzero')
          create_service_provider_identity(user, Date.yesterday.middle_of_day)
          create_service_provider_identity(user2, Date.yesterday.middle_of_day)

          results = DuplicateAccountsReport.call(issuer)
          expect(results.count).to eq(0)
        end
      end
    end

    context 'when duplicate accounts exist' do
      it 'creates a results array with one record when two users have same SSN signature' do
        freeze_time do
          user1 = create_user_with_ssn_signature('hashedssnsignaturekeyone')
          user2 = create_user_with_ssn_signature('hashedssnsignaturekeyone')

          create_service_provider_identity(user2, Time.zone.today)
          create_service_provider_identity(user1, Date.yesterday.middle_of_day)

          results = DuplicateAccountsReport.call(issuer)
          expect(results.count).to eq(1)
        end
      end

      it 'creates a results array with three records when multiple users have same SSN signature' do
        freeze_time do
          user1 = create_user_with_ssn_signature('hashedssnsignaturekeytwo')
          user2 = create_user_with_ssn_signature('hashedssnsignaturekeyone')
          user3 = create_user_with_ssn_signature('hashedssnsignaturekeyone')
          user4 = create_user_with_ssn_signature('hashedssnsignaturekeyone')

          create_service_provider_identity(user1, Date.yesterday.middle_of_day)
          create_service_provider_identity(user2, Date.yesterday.middle_of_day)
          create_service_provider_identity(user3, Date.yesterday.middle_of_day)
          create_service_provider_identity(user4, Date.yesterday.middle_of_day)

          results = DuplicateAccountsReport.call(issuer)
          expect(results.count).to eq(3)
        end
      end
    end
  end
end
