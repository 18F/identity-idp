require 'rails_helper'

RSpec.describe TwoFactorAuthentication::PivCacConfigurationManager do
  let(:subject) { described_class.new(user) }

  context 'with a piv/cac configured' do
    let(:user) { build(:user, :with_piv_or_cac) }

    it 'is enabled' do
      expect(subject.enabled?).to eq true
    end

    it 'is configured' do
      expect(subject.configured?).to eq true
    end

    it 'is available' do
      expect(subject.available?).to eq true
    end

    it 'is not configurable' do
      expect(subject.configurable?).to eq false
    end

    describe '#x509_dn_uuid' do
      it 'returns the configured piv/cac cert uuid' do
        expect(subject.x509_dn_uuid).to eq user.x509_dn_uuid
      end
    end

    describe '#authenticate' do
      it 'returns true for the right value' do
        expect(subject.authenticate(subject.x509_dn_uuid)).to eq true
      end

      it 'returns false for everything else' do
        expect(subject.authenticate(nil)).to eq false
        expect(subject.authenticate(subject.x509_dn_uuid + 'X')).to eq false
      end
    end

    describe '#remove_configuration' do
      before(:each) do
        user.save!
      end

      it 'removes the uuid' do
        subject.remove_configuration
        expect(user.reload.x509_dn_uuid).to be_nil
      end

      it 'creates an event' do
        expect(Event).to receive(:create).with(user_id: user.id, event_type: :piv_cac_disabled)
        subject.remove_configuration
      end
    end

    describe '#associated?' do
      it 'returns true' do
        user.save!
        expect(subject.associated?).to eq true
      end
    end
  end

  context 'with no piv/cac configured and no identities with a piv/cac SP' do
    let(:user) { build(:user) }

    it 'is not enabled' do
      expect(subject.enabled?).to eq false
    end

    it 'is not configured' do
      expect(subject.configured?).to eq false
    end

    it 'is not available' do
      expect(subject.available?).to eq false
    end

    it 'is not configurable' do
      expect(subject.configurable?).to eq false
    end

    describe '#x509_dn_uuid' do
      it 'returns nothing' do
        expect(subject.x509_dn_uuid).to be nil
      end
    end

    describe '#authenticate' do
      it 'returns false for everything' do
        expect(subject.authenticate(nil)).to eq false
        expect(subject.authenticate('foo')).to eq false
        expect(subject.authenticate(subject.x509_dn_uuid)).to eq false
      end
    end

    describe '#remove_configuration' do
      before(:each) do
        user.save!
      end

      it 'creates no event' do
        expect(Event).to_not receive(:create)
        subject.remove_configuration
      end
    end

    describe '#save_configuration' do
      let(:user) { create(:user) }
      let(:x509_dn_uuid) { 'the uuid for a piv/cac' }

      it 'saves the configuration' do
        subject.x509_dn_uuid = x509_dn_uuid
        subject.save_configuration
        expect(user.reload.x509_dn_uuid).to eq x509_dn_uuid
      end

      it 'creates an event' do
        expect(Event).to receive(:create).with(user_id: user.id, event_type: :piv_cac_enabled)
        subject.x509_dn_uuid = x509_dn_uuid
        subject.save_configuration
      end
    end

    describe '#associated?' do
      let(:x509_dn_uuid) { 'the uuid for a piv/cac' }

      it 'returns false' do
        subject.x509_dn_uuid = x509_dn_uuid
        expect(subject.associated?).to eq false
      end
    end
  end

  context 'with no piv/cac configured but identities with a piv/cac SP' do
    let(:identity) do
      ident = build(:identity)
      allow(ident).to receive(:piv_cac_available?).and_return(true)
      ident
    end
    let(:user) { build(:user, identities: [identity]) }

    it 'is not enabled' do
      expect(subject.enabled?).to eq false
    end

    it 'is not configured' do
      expect(subject.configured?).to eq false
    end

    it 'is available' do
      expect(subject.available?).to eq true
    end

    it 'is configurable' do
      expect(subject.configurable?).to eq true
    end
  end
end
