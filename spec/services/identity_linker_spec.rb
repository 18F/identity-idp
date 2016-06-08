require 'rails_helper'

describe IdentityLinker do
  describe '#link_identity' do
    it "updates user's last authenticated identity" do
      user = create(:user)

      IdentityLinker.new(user, 'test.host', 'LOA1').link_identity
      user.reload

      last_identity = user.last_identity

      new_attributes = {
        service_provider: 'test.host',
        authn_context: 'LOA1',
        session_index: 1,
        user_id: user.id,
        ial: 1
      }

      identity_attributes = last_identity.attributes.symbolize_keys.
                            except(:created_at, :updated_at, :id, :quiz_started, :session_uuid,
                                   :last_authenticated_at)

      expect(last_identity.session_uuid).to match(/.{8}-.{4}-.{4}-.{4}-.{12}/)
      expect(last_identity.last_authenticated_at).to be_present
      expect(identity_attributes).to eq new_attributes
    end
  end
end
