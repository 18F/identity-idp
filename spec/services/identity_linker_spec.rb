require 'rails_helper'

describe IdentityLinker do
  describe '#link_identity' do
    let(:user) { create(:user) }

    it "updates user's last authenticated identity" do
      IdentityLinker.new(user, 'test.host', 'foo').link_identity
      user.reload

      last_identity = user.last_identity

      expect(last_identity).to be_a Identity

      new_attributes = {
        service_provider: 'test.host',
        user_id: user.id,
        uuid: last_identity.uuid
      }

      identity_attributes = last_identity.attributes.symbolize_keys.
                            except(:created_at, :updated_at, :id, :last_authenticated_at)

      expect(last_identity.last_authenticated_at).to be_present
      expect(identity_attributes).to eq new_attributes
    end

    it 'sets session_id on child Session' do
      IdentityLinker.new(user, 'test.host', 'foo').link_identity
      user.reload

      last_identity = user.last_identity

      expect(last_identity.sessions.first.session_id).to eq 'foo'
    end

    it 'fails when given a nil provider' do
      linker = IdentityLinker.new(user, nil, 'foo')
      expect { linker.link_identity }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
