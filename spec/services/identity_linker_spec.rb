require 'rails_helper'

describe IdentityLinker do
  describe '#link_identity' do
    let(:user) { create(:user) }
    let(:service_provider) { build(:service_provider, issuer: 'test.host') }

    it "updates user's last authenticated identity" do
      IdentityLinker.new(user, service_provider).link_identity
      user.reload

      last_identity = user.last_identity

      new_attributes = {
        service_provider: service_provider.issuer,
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

    it 'does not write last_authenticated_at when :include_identity_session_attributes is false' do
      identity = IdentityLinker.new(user, service_provider).
        link_identity(include_identity_session_attributes: false)

      aggregate_failures do
        expect(identity.last_authenticated_at).to be_nil
        expect(identity.session_uuid).to be_nil
        expect(identity.access_token).to be_nil
        expect(identity.last_ial1_authenticated_at).to be_nil
        expect(identity.last_ial2_authenticated_at).to be_nil
        expect(identity.verified_at).to be_nil
      end
    end

    it 'can take an additional optional attributes' do
      rails_session_id = SecureRandom.hex
      nonce = SecureRandom.hex
      ial = 3
      scope = 'openid profile email'
      code_challenge = SecureRandom.hex

      IdentityLinker.new(user, service_provider).link_identity(
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

    context 'identity.last_consented_at' do
      let(:now) { Time.zone.now }
      let(:six_months_ago) { 6.months.ago }

      it 'does override a previous last_consented_at by default' do
        IdentityLinker.new(user, service_provider).
          link_identity(last_consented_at: six_months_ago)
        last_identity = user.reload.last_identity
        expect(last_identity.last_consented_at.to_i).to eq(six_months_ago.to_i)

        IdentityLinker.new(user, service_provider).link_identity
        last_identity = user.reload.last_identity
        expect(last_identity.last_consented_at.to_i).to eq(six_months_ago.to_i)
      end

      it 'updates last_consented_at when present' do
        IdentityLinker.new(user, service_provider).
          link_identity(last_consented_at: now)

        last_identity = user.reload.last_identity
        expect(last_identity.last_consented_at.to_i).to eq(now.to_i)
      end
    end

    context 'clear_deleted_at' do
      let(:yesterday) { 1.day.ago }

      before do
        IdentityLinker.new(user, service_provider).link_identity
        last_identity = user.reload.last_identity
        last_identity.update!(deleted_at: yesterday)
      end

      subject(:link_identity) do
        IdentityLinker.new(user, service_provider).
          link_identity(clear_deleted_at: clear_deleted_at)
      end

      context 'clear_deleted_at is nil' do
        let(:clear_deleted_at) { nil }

        it 'nulls out deleted_at' do
          expect { link_identity }.
            to_not change { user.reload.last_identity.deleted_at&.to_i }.
            from(yesterday.to_i)
        end
      end

      context 'clear_deleted_at is true' do
        let(:clear_deleted_at) { true }

        it 'nulls out deleted_at' do
          expect { link_identity }.
            to change { user.reload.last_identity.deleted_at&.to_i }.
            from(yesterday.to_i).to(nil)
        end
      end
    end

    it 'rejects bad attributes names' do
      expect { IdentityLinker.new(user, service_provider).link_identity(foobar: true) }.
        to raise_error(ArgumentError)
    end

    it 'does not link to an identity record if the provider is nil' do
      linker = IdentityLinker.new(user, nil)
      expect(linker.link_identity).to eq(nil)
    end

    it 'can link two different clients to the same rails_session_id' do
      rails_session_id = SecureRandom.uuid
      service_provider1 = build(:service_provider, issuer: 'client1')
      service_provider2 = build(:service_provider, issuer: 'client2')

      IdentityLinker.new(user, service_provider1).link_identity(rails_session_id: rails_session_id)
      IdentityLinker.new(user, service_provider2).link_identity(rails_session_id: rails_session_id)
    end
  end
end
