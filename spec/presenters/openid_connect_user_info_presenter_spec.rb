require 'rails_helper'

RSpec.describe OpenidConnectUserInfoPresenter do
  include Rails.application.routes.url_helpers

  let(:session_uuid) { SecureRandom.uuid }
  let(:scope) { 'openid email address phone profile' }
  let(:identity) do
    build(:identity,
          session_uuid: session_uuid,
          user: build(:user),
          scope: scope)
  end

  subject(:presenter) { OpenidConnectUserInfoPresenter.new(identity) }

  describe '#user_info' do
    subject(:user_info) { presenter.user_info }

    it 'has basic attributes' do
      aggregate_failures do
        expect(user_info[:sub]).to eq(identity.uuid)
        expect(user_info[:iss]).to eq(root_url)
        expect(user_info[:email]).to eq(identity.user.email)
        expect(user_info[:email_verified]).to eq(true)
      end
    end

    context 'when there is decrypted loa3 session data in redis' do
      let(:pii) do
        {
          first_name: 'John',
          middle_name: 'Jones',
          last_name: 'Smith',
          dob: '1970-01-01',
          address1: '123 Fake St',
          address2: 'Apt 456',
          city: 'Washington',
          state: 'DC',
          zipcode: '12345',
          phone: '+1 (555) 555-5555'
        }
      end

      before do
        Pii::SessionStore.new(session_uuid).put(pii, 5.minutes.to_i)
      end

      context 'when the identity has loa3 access' do
        before { identity.ial = 3 }

        context 'when the scope includes all attributes' do
          it 'returns loa3 attributes' do
            aggregate_failures do
              expect(user_info[:given_name]).to eq('John')
              expect(user_info[:middle_name]).to eq('Jones')
              expect(user_info[:family_name]).to eq('Smith')
              expect(user_info[:birthdate]).to eq('1970-01-01')
              expect(user_info[:phone]).to eq('+1 (555) 555-5555')
              expect(user_info[:phone_verified]).to eq(true)
              expect(user_info[:address]).to eq(
                formatted: "123 Fake St Apt 456\nWashington, DC 12345",
                street_address: '123 Fake St Apt 456',
                locality: 'Washington',
                region: 'DC',
                postal_code: '12345'
              )
            end
          end
        end

        context 'when the scope only includes minimal attributes' do
          let(:scope) { 'openid email phone' }

          it 'returns attributes allowed by the scope' do
            aggregate_failures do
              expect(user_info[:email]).to eq(identity.user.email)
              expect(user_info[:email_verified]).to eq(true)
              expect(user_info[:given_name]).to eq(nil)
              expect(user_info[:family_name]).to eq(nil)
              expect(user_info[:middle_name]).to eq(nil)
              expect(user_info[:birthdate]).to eq(nil)
              expect(user_info[:phone]).to eq('+1 (555) 555-5555')
              expect(user_info[:phone_verified]).to eq(true)
              expect(user_info[:address]).to eq(nil)
            end
          end
        end
      end

      context 'when the identity only has loa1 access' do
        before { identity.ial = 1 }

        it 'does not return loa3 attributes' do
          aggregate_failures do
            expect(user_info[:given_name]).to eq(nil)
            expect(user_info[:family_name]).to eq(nil)
            expect(user_info[:middle_name]).to eq(nil)
            expect(user_info[:birthdate]).to eq(nil)
            expect(user_info[:phone]).to eq(nil)
            expect(user_info[:phone_verified]).to eq(nil)
            expect(user_info[:address]).to eq(nil)
          end
        end
      end
    end
  end
end
