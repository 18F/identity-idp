require 'rails_helper'

RSpec.describe Idv::Engine::ProfileEngine do
  let(:user) { create(:user) }
  let(:user_session) { {} }
  let(:idv_session) do
    Idv::Session.new(
      user_session: user_session,
      current_user: user,
      service_provider: nil,
    )
  end

  subject { described_class.new(user: user, idv_session: idv_session, user_session: user_session) }

  describe('#initialize') do
    it 'accepts user' do
      described_class.new(user: user)
    end

    it 'raises for nil user' do
      expect { described_class.new(user: nil) }.to raise_error
    end
  end

  describe('#verification') do
    context 'user has no profile' do
      it 'returns a invalid verification' do
        expect(subject.verification).to be
        expect(subject.verification.identity_verified?).to eql(false)
      end
    end

    context 'user has an active profile' do
      let(:user) { create(:user, :proofed) }

      it 'returns an identity-verified verification' do
        expect(subject.verification).to be
        expect(subject.verification.identity_verified?).to eql(true)
      end
    end
  end

  describe '#idv_user_consented_to_share_pii' do
    it 'updates idv_session' do
      expect do
        subject.idv_user_consented_to_share_pii
      end.to change {
        idv_session.idv_consent_given
      }.to eql(true)
    end

    it 'updates verification' do
      subject.idv_user_consented_to_share_pii
      expect(subject.verification.user_has_consented_to_share_pii?).to eql(true)
    end
  end

  describe('#idv_user_started') do
    it 'updates the idv_session to note the user visited welcome' do
      expect do
        subject.idv_user_started
      end.to change {
        idv_session.welcome_visited
      }.to eql(true)
    end
  end

  describe('#auth_user_changed_password') do
    let(:params) do
      {
        password: 'hunter2',
      }
    end

    context('when user_session is not available') do
      let(:user_session) { nil }

      it 'raises' do
        expect { subject.auth_user_changed_password(params) }.
          to raise_error
      end
    end

    context 'no profile' do
      it 'is a no-op' do
        subject.auth_user_changed_password(params)
      end
    end

    context('with profile inactive due to GPO pending') do
      let(:user) { create(:user, :with_pending_gpo_profile) }
      it 'does not modify password-encrypted PII on the profile' do
        expect { subject.auth_user_changed_password(params) }.
          not_to change { user.pending_profile.encrypted_pii }
      end
    end

    context 'with active profile' do
      let(:user) { create(:user, :proofed) }
      # TODO: Figure out how to get user's pii into the session
      xit 'updates encrypted data on profile' do
        expect { subject.auth_user_changed_password(params) }.
          to change { user.active_profile.encrypted_pii }
      end
    end
  end

  describe('#auth_password_reset') do
    context 'no active profile' do
      it 'does nothing' do
        subject.auth_user_reset_password
      end
    end
    context 'with pending gpo ' do
      let(:user) { create(:user, :with_pending_gpo_profile) }

      it 'cancels the profile' do
        subject.auth_user_reset_password
        expect(user.active_profile).to eql(nil)
      end
    end
    context 'with a proofing component' do
      let!(:proofing_component) do
        ProofingComponent.create(
          user: user,
        )
      end
      it 'destroys proofing component' do
        subject.auth_user_reset_password
        expect(user.reload.proofing_component).to eql(nil)
      end
    end
  end

  describe('#idv_gpo_user_requested_letter') do
    context 'without idv_session' do
      let(:idv_session) { nil }
      it 'raises' do
        expect { subject.idv_gpo_user_requested_letter }.to raise_error
      end
    end

    context 'with idv_session' do
      it 'notes request in idv_session' do
        subject.idv_gpo_user_requested_letter
        expect(idv_session.address_verification_mechanism).to eql(:gpo)
      end
    end
  end

  describe('#idv_user_entered_ssn') do
    it 'sets pii_from_doc[:ssn]' do
      subject.idv_user_entered_ssn(ssn: '123-45-6789')

      pii = user_session['idv/doc_auth'][:pii_from_doc]

      expect(pii).to be
      expect(pii[:ssn]).to eql('123-45-6789')
    end
  end
end
