require 'rails_helper'

describe IdentityLinker do
  describe '#set_active_identity' do
    it 'calls User#set_active_identity' do
      user = build_stubbed(:user)
      sp_data = {
        provider: 'test.host',
        authn_context: 'LOA1'
      }

      linker = IdentityLinker.new(user, true, sp_data)

      expect(user).to receive(:set_active_identity).with('test.host', 'LOA1', true)

      linker.set_active_identity
    end
  end

  describe '#update_user_and_identity_if_ial_token' do
    context 'when ial token is not present' do
      it 'does not update user or identity' do
        user = build_stubbed(:user)
        sp_data = {
          provider: 'test.host',
          authn_context: 'LOA1'
        }

        linker = IdentityLinker.new(user, true, sp_data)
        identity = linker.set_active_identity

        expect(user).to_not receive(:update)
        expect(identity).to_not receive(:update)

        linker.update_user_and_identity_if_ial_token
      end
    end

    context 'when ial token is present' do
      it "updates user's ial_token and identity's quiz_started to true" do
        user = build(:user)
        sp_data = {
          provider: 'test.host',
          authn_context: 'LOA1',
          ial_token: 'foo'
        }

        linker = IdentityLinker.new(user, true, sp_data)
        identity = linker.set_active_identity

        linker.update_user_and_identity_if_ial_token

        expect(user.ial_token).to eq 'foo'
        expect(identity.quiz_started).to eq true
      end
    end

    context 'when ial token is present' do
      it "does not update identity's quiz_started to true when ial_token is invalid" do
        create(:user, ial_token: 'foo')
        user = create(:user)
        sp_data = {
          provider: 'test.host',
          authn_context: 'LOA1',
          ial_token: 'foo'
        }

        linker = IdentityLinker.new(user, true, sp_data)
        identity = linker.set_active_identity

        linker.update_user_and_identity_if_ial_token

        expect(identity.quiz_started).to eq false
      end
    end
  end
end
