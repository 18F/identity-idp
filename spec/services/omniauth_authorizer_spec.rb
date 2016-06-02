require 'rails_helper'

describe OmniauthAuthorizer do
  let(:authorizer) { OmniauthAuthorizer.new(auth_hash, session) }

  let(:auth_hash) do
    OmniAuth::AuthHash.new(
      provider: 'saml',
      uid: '1234',
      info: {
        email: 'email@example.com'
      },
      extra: {
        raw_info: {
          email: 'email@example.com',
          uuid: '1234'
        }
      }
    )
  end

  let(:session) { {} }

  shared_examples 'valid authorization' do
    it 'updates the session' do
      authorizer.perform

      expect(session[:omniauthed]).to eq true
    end

    specify do
      authorizer.perform
      expect { |b| authorizer.perform(&b) }.
        to yield_with_args(auth.user, :process_valid_authorization)
    end
  end

  describe '#perform' do
    context 'when the authorization is valid' do
      context 'and one already exists with the uid in the auth_hash' do
        let!(:auth) { create(:authorization, user_id: user.id) }
        let!(:user) { create(:user) }

        it 'does not create a new authorization' do
          expect { authorizer.perform }.to_not change { Authorization.count }
        end

        it 'updates the authorization authorized_at timestamp' do
          old_timestamp = auth.authorized_at
          authorizer.perform
          auth.reload

          expect(auth.authorized_at).to_not eq old_timestamp
        end

        it_behaves_like 'valid authorization'
      end

      context 'and one does not exist with the uid in the auth_hash' do
        let(:auth) { Authorization.where(uid: '1234').first }

        it 'creates a new authorization' do
          expect { authorizer.perform }.to change { Authorization.count }
          expect(auth.uid).to eq('1234')
          expect(auth.provider).to eq('saml')
        end

        it 'updates the authorization authorized_at timestamp' do
          authorizer.perform

          expect(auth.authorized_at).to be_present
        end

        it_behaves_like 'valid authorization'

        context 'user matching auth_hash email does not exist' do
          it 'creates a new User' do
            expect { authorizer.perform }.to change { User.count }
            expect(auth.user.email).to eq('email@example.com')
            expect(auth.user.confirmed_at).to be_present
            expect(auth.user.role).to eq 'user'
          end
        end

        context 'user matching auth_hash email exists' do
          let!(:user) { create(:user, email: 'email@example.com') }

          it 'does not create a new User' do
            expect { authorizer.perform }.to_not change { User.count }
          end

          it 'creates a new authorization associated with the existing user' do
            authorizer.perform

            expect(auth.user.email).to eq('email@example.com')
            expect(auth.user.confirmed_at).to be_present
          end

          it 'does not update the user confirmed_at' do
            expect { authorizer.perform }.to_not change { user.reload.confirmed_at }
          end
        end
      end
    end

    context 'when the authorization sends an invalid email' do
      let(:auth_hash) do
        OmniAuth::AuthHash.new(
          provider: 'saml',
          extra: {
            raw_info: {
              email: 'email@foo',
              uuid: '1234'
            }
          }
        )
      end

      it 'does not create a new User' do
        expect { authorizer.perform }.to_not change { User.count }
      end

      it 'does not update the session' do
        authorizer.perform

        expect(session[:omniauthed]).to be_nil
      end

      it 'does not update the authorization authorized_at timestamp' do
        authorizer.perform

        expect(authorizer.auth.authorized_at).to be_nil
      end
    end
  end
end
