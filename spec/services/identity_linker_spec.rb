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
      expect(identity_attributes).to include new_attributes
    end

    it 'can take an optional nonce, session_uuid, ial, and scope to specify attributes' do
      session_uuid = SecureRandom.hex
      nonce = SecureRandom.hex
      ial = 3
      scope = 'openid profile email'

      IdentityLinker.new(user, 'test.host').link_identity(
        session_uuid: session_uuid,
        nonce: nonce,
        ial: ial,
        scope: scope
      )
      user.reload

      last_identity = user.last_identity
      expect(last_identity.nonce).to eq(nonce)
      expect(last_identity.session_uuid).to eq(session_uuid)
      expect(last_identity.ial).to eq(ial)
      expect(last_identity.scope).to eq(scope)
    end

    it 'rejects bad attributes names' do
      expect { IdentityLinker.new(user, 'test.host').link_identity(foobar: true) }.
        to raise_error(ArgumentError)
    end

    it 'fails when given a nil provider' do
      linker = IdentityLinker.new(user, nil)
      expect { linker.link_identity }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
