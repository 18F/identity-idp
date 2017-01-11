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
        uuid: last_identity.uuid
      }

      identity_attributes = last_identity.attributes.symbolize_keys.
                            except(:created_at, :updated_at, :id, :session_uuid,
                                   :last_authenticated_at, :nonce)

      expect(last_identity.session_uuid).to match(/.{8}-.{4}-.{4}-.{4}-.{12}/)
      expect(last_identity.last_authenticated_at).to be_present
      expect(identity_attributes).to eq new_attributes
    end

    it 'can take an optional nonce and session_uuid to specify attributes' do
      session_uuid = SecureRandom.hex
      nonce = SecureRandom.hex

      IdentityLinker.new(user, 'test.host').link_identity(session_uuid: session_uuid, nonce: nonce)
      user.reload

      last_identity = user.last_identity
      expect(last_identity.nonce).to eq(nonce)
      expect(last_identity.session_uuid).to eq(session_uuid)
    end

    it 'fails when given a nil provider' do
      linker = IdentityLinker.new(user, nil)
      expect { linker.link_identity }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
