require 'rails_helper'

RSpec.describe OpenidConnectUserInfoPresenter do
  include Rails.application.routes.url_helpers

  let(:session_uuid) { SecureRandom.uuid }
  let(:identity) { build(:identity, session_uuid: session_uuid, user: build(:user)) }

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
      let(:session_data) do
        {
          'warden.user.user.session' => {
            decrypted_pii: {
              first_name: 'John',
              middle_name: 'Jones',
              last_name: 'Smith',
              dob: '1970-01-01',
              zipcode: '12345'
            }.to_json
          }
        }
      end

      before do
        presenter.send(:session_store).
          send(:set_session, {}, session_uuid, session_data, expire_after: 5.minutes.to_i)
      end

      it 'returns loa3 attributes' do
        aggregate_failures do
          expect(user_info[:given_name]).to eq('John')
          expect(user_info[:middle_name]).to eq('Jones')
          expect(user_info[:family_name]).to eq('Smith')
          expect(user_info[:birthdate]).to eq('1970-01-01')
          expect(user_info[:postal_code]).to eq('12345')
        end
      end

      context 'when the identity only has loa1 access' do
        it 'does not return loa3 attributes' do
          pending 'loa1/loa3 access controls'

          aggregate_failures do
            expect(user_info[:given_name]).to eq(nil)
            expect(user_info[:family_name]).to eq(nil)
            expect(user_info[:middle_name]).to eq(nil)
            expect(user_info[:birthdate]).to eq(nil)
            expect(user_info[:postal_code]).to eq(nil)
          end
        end
      end
    end
  end
end
