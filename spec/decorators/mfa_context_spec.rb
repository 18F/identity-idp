require 'rails_helper'

describe MfaContext do
  let(:mfa) { MfaContext.new(user) }

  context 'with no user' do
    let(:user) {}

    describe '#auth_app_configurations' do
      it 'is empty' do
        expect(mfa.auth_app_configurations).to be_empty
      end
    end

    describe '#phone_configurations' do
      it 'is empty' do
        expect(mfa.phone_configurations).to be_empty
      end
    end

    describe '#webauthn_configurations' do
      it 'is empty' do
        expect(mfa.webauthn_configurations).to be_empty
      end
    end

    describe '#backup_code_configurations' do
      it 'is empty' do
        expect(mfa.backup_code_configurations).to be_empty
      end
    end
  end

  context 'with a user' do
    let(:user) { create(:user) }

    describe '#auth_app_configurations' do
      it 'mirrors the user relationship' do
        expect(mfa.auth_app_configurations).to be_empty
      end
    end

    describe '#piv_cac_configurations' do
      it 'mirrors the user relationship' do
        expect(mfa.piv_cac_configurations).to be_empty
      end
    end

    describe '#phone_configurations' do
      it 'mirrors the user relationship' do
        expect(mfa.phone_configurations).to eq user.phone_configurations
      end
    end

    describe '#webauthn_configurations' do
      context 'with no user' do
        it 'mirrors the user relationship' do
          expect(mfa.webauthn_configurations).to be_empty
        end
      end
    end

    describe '#backup_code_configurations' do
      it 'is empty if the user does not have backup codes' do
        expect(mfa.backup_code_configurations).to be_empty
      end

      it 'returns does not return unused backup codes' do
        create_list(:backup_code_configuration, 5, user: user)
        create_list(:backup_code_configuration, 5, user: user, used_at: 1.day.ago)
        user.reload

        expect(mfa.backup_code_configurations.length).to eq(5)
      end
    end
  end

  describe '#enabled_two_factor_configuration_counts_hash' do
    let(:count_hash) { MfaContext.new(user).enabled_two_factor_configuration_counts_hash }

    context 'no 2FA configurations' do
      let(:user) { build(:user) }

      it 'returns an empty hash' do
        hash = {}

        expect(count_hash).to eq hash
      end
    end

    context 'with phone configuration' do
      let(:user) { build(:user, :with_phone) }

      it 'returns 1 for phone' do
        hash = { phone: 1 }

        expect(count_hash).to eq hash
      end
    end

    context 'with PIV/CAC configuration' do
      let(:user) { build(:user, :with_piv_or_cac) }

      it 'returns 1 for piv_cac' do
        hash = { piv_cac: 1 }

        expect(count_hash).to eq hash
      end
    end

    context 'with authentication app configuration' do
      let(:user) { build(:user, :with_authentication_app) }

      it 'returns 1 for auth_app' do
        hash = { auth_app: 1 }

        expect(count_hash).to eq hash
      end
    end

    context 'with webauthn configuration' do
      let(:user) { create(:user, :with_webauthn) }

      it 'returns 1 for webauthn' do
        hash = { webauthn: 1 }

        expect(count_hash).to eq hash
      end
    end

    context 'with authentication app and webauthn configurations' do
      let(:user) { build(:user, :with_authentication_app, :with_webauthn) }

      it 'returns 1 for each' do
        hash = { auth_app: 1, webauthn: 1 }

        expect(count_hash).to eq hash
      end
    end

    context 'with authentication app and phone configurations' do
      let(:user) { build(:user, :with_authentication_app, :with_phone) }

      it 'returns 1 for each' do
        hash = { phone: 1, auth_app: 1 }

        expect(count_hash).to eq hash
      end
    end

    context 'with PIV/CAC and phone configurations' do
      let(:user) { build(:user, :with_piv_or_cac, :with_phone) }

      it 'returns 1 for each' do
        hash = { phone: 1, piv_cac: 1 }

        expect(count_hash).to eq hash
      end
    end

    context 'with 1 phone and 2 webauthn configurations' do
      let(:user) { create(:user, :with_phone) }

      it 'returns 1 for phone and 2 for webauthn' do
        create_list(:webauthn_configuration, 2, user: user)
        hash = { phone: 1, webauthn: 2 }

        expect(count_hash).to eq hash
      end
    end

    context 'with 2 phones and 2 webauthn configurations' do
      it 'returns 2 for each' do
        user = create(:user, :with_phone)
        create(:phone_configuration, user: user, phone: '+1 703-555-1213')
        create_list(:webauthn_configuration, 2, user: user)
        count_hash = MfaContext.new(user.reload).enabled_two_factor_configuration_counts_hash
        hash = { phone: 2, webauthn: 2 }

        expect(count_hash).to eq hash
      end
    end

    context 'with 1 phone and 10 backups codes' do
      it 'returns 1 for phone and 10 for backup codes' do
        user = create(:user, :with_phone)
        create_list(:backup_code_configuration, 10, user: user)
        count_hash = MfaContext.new(user.reload).enabled_two_factor_configuration_counts_hash
        hash = { phone: 1, backup_codes: 10 }

        expect(count_hash).to eq hash
      end
    end

    context 'with 1 phone and 10 used backup codes' do
      it 'returns 1 for phone and no backup codes' do
        user = create(:user, :with_phone)
        create_list(:backup_code_configuration, 10, user: user, used_at: 1.day.ago)
        count_hash = MfaContext.new(user.reload).enabled_two_factor_configuration_counts_hash
        hash = { phone: 1 }

        expect(count_hash).to eq hash
      end
    end
  end

  describe '#enabled_mfa_methods_count' do
    context 'with 2 phones' do
      it 'returns 2' do
        user = create(:user, :with_phone)
        create(:phone_configuration, user: user, phone: '+1 703-555-1213')
        subject = described_class.new(user.reload)

        expect(subject.enabled_mfa_methods_count).to eq(2)
      end
    end

    context 'with 2 webauthn tokens' do
      it 'returns 2' do
        user = create(:user)
        create_list(:webauthn_configuration, 2, user: user)
        subject = described_class.new(user.reload)

        expect(subject.enabled_mfa_methods_count).to eq(2)
      end
    end

    context 'with 1 webauthn roaming authenticator and one platform authenticator' do
      it 'returns 2' do
        user = create(:user)
        create(:webauthn_configuration, user: user)
        create(:webauthn_configuration, platform_authenticator: true, user: user)
        subject = described_class.new(user.reload)

        expect(subject.enabled_mfa_methods_count).to eq(2)
      end
    end

    context 'with a phone and a webauthn token' do
      it 'returns 2' do
        user = create(:user, :with_phone)
        create(:webauthn_configuration, user: user)
        subject = described_class.new(user.reload)

        expect(subject.enabled_mfa_methods_count).to eq(2)
      end
    end

    context 'with a phone and 10 backup codes' do
      it 'returns 2' do
        user = create(:user, :with_phone)
        create_list(:backup_code_configuration, 10, user: user)
        subject = described_class.new(user.reload)

        expect(subject.enabled_mfa_methods_count).to eq(2)
      end
    end

    context 'with a phone and 10 used backup codes' do
      it 'returns 1' do
        user = create(:user, :with_phone)
        create_list(:backup_code_configuration, 10, user: user, used_at: 1.day.ago)
        subject = described_class.new(user.reload)

        expect(subject.enabled_mfa_methods_count).to eq(1)
      end
    end

    context 'with a phone and a PIV/CAC' do
      it 'returns 2' do
        user = create(:user, :with_phone, :with_piv_or_cac)
        subject = described_class.new(user.reload)

        expect(subject.enabled_mfa_methods_count).to eq(2)
      end
    end

    context 'with a phone and an auth app' do
      it 'returns 2' do
        user = create(:user, :with_phone, :with_authentication_app)
        subject = described_class.new(user.reload)

        expect(subject.enabled_mfa_methods_count).to eq(2)
      end
    end

    context 'with a phone and a personal key' do
      it 'returns 2' do
        user = create(:user, :with_phone, :with_personal_key)
        subject = described_class.new(user.reload)

        expect(subject.enabled_mfa_methods_count).to eq(1)
      end
    end
  end

  describe '#phishable_configuration_count' do
    context 'without any phishable configs' do
      it 'returns 0' do
        user = create(:user, :with_piv_or_cac, :with_webauthn)
        subject = described_class.new(user.reload)
        expect(subject.phishable_configuration_count).to eq(0)
      end
    end

    context 'with some phishable configs' do
      it 'returns 2' do
        user = create(:user, :with_phone, :with_authentication_app)
        subject = described_class.new(user.reload)
        expect(subject.phishable_configuration_count).to eq(2)
      end
    end
  end

  describe '#unphishable_configuration_count' do
    context 'with PIV/CAC and webauthn configurations' do
      it 'returns 2' do
        user = create(:user, :with_piv_or_cac, :with_webauthn)
        subject = described_class.new(user.reload)
        expect(subject.unphishable_configuration_count).to eq(2)
      end
    end

    context 'with no phishable configs' do
      it 'returns 0' do
        user = create(:user, :with_phone, :with_authentication_app)
        subject = described_class.new(user.reload)
        expect(subject.unphishable_configuration_count).to eq(0)
      end
    end
  end
end
