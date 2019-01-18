require 'rails_helper'

describe IdentityLinker do
  describe '#link_identity' do
    let(:user) { create(:user) }

    it "updates user's last authenticated identity" do
      IdentityLinker.new(user, 'test.host').link_identity
      user.reload

      last_identity = user.last_identity

      new_attributes = {
        service_provider: 'test.host',
        user_id: user.id,
        uuid: last_identity.uuid,
      }

      identity_attributes = last_identity.attributes.symbolize_keys.
                            except(:created_at, :updated_at, :id, :session_uuid,
                                   :last_authenticated_at, :nonce)

      expect(last_identity.session_uuid).to match(/.{8}-.{4}-.{4}-.{4}-.{12}/)
      expect(last_identity.last_authenticated_at).to be_present
      expect(identity_attributes).to include new_attributes
    end

    it 'can take an additional optional attributes' do
      rails_session_id = SecureRandom.hex
      nonce = SecureRandom.hex
      ial = 3
      scope = 'openid profile email'
      code_challenge = SecureRandom.hex

      IdentityLinker.new(user, 'test.host').link_identity(
        rails_session_id: rails_session_id,
        nonce: nonce,
        ial: ial,
        scope: scope,
        code_challenge: code_challenge,
      )
      user.reload

      last_identity = user.last_identity
      expect(last_identity.nonce).to eq(nonce)
      expect(last_identity.rails_session_id).to eq(rails_session_id)
      expect(last_identity.ial).to eq(ial)
      expect(last_identity.scope).to eq(scope)
      expect(last_identity.code_challenge).to eq(code_challenge)
    end

    it 'rejects bad attributes names' do
      expect { IdentityLinker.new(user, 'test.host').link_identity(foobar: true) }.
        to raise_error(ArgumentError)
    end

    it 'fails when given a nil provider' do
      linker = IdentityLinker.new(user, nil)
      expect { linker.link_identity }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'can link two different clients to the same rails_session_id' do
      rails_session_id = SecureRandom.uuid

      IdentityLinker.new(user, 'client1').link_identity(rails_session_id: rails_session_id)
      IdentityLinker.new(user, 'client2').link_identity(rails_session_id: rails_session_id)
    end
  end

  describe '#already_linked?' do
    let(:user) { create(:user) }
    let(:provider) { 'test.host' }

    subject(:identity_linker) { IdentityLinker.new(user, provider) }

    it 'is false before an identity has been linked' do
      expect(identity_linker.already_linked?).to eq(false)
    end

    it 'is true after an identity has been linked' do
      expect { identity_linker.link_identity }.
        to change { identity_linker.already_linked? }.from(false).to(true)
    end
  end
end
