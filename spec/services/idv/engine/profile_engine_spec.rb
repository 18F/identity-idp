require 'rails_helper'

RSpec.describe Idv::Engine::ProfileEngine do
  let(:user) { create(:user) }
  let(:idv_session) { nil }
  let(:user_session) { nil }

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
        expect(subject.verification.valid?).to eql(false)
      end
    end

    context 'user has an active profile' do
      let(:user) { create(:user, :proofed) }

      it 'returns a valid verification' do
        expect(subject.verification).to be
        expect(subject.verification.valid?).to eql(true)
      end
    end
  end

  [:idv_user_started, :idv_user_consented].each do |method|
    describe("##{method}") do
      it 'is a no-op' do
        subject.send(method)
        expect(user.profiles).to be_empty
      end
    end
  end

  describe('#auth_user_changed_password') do
    let(:params) do
      Idv::Engine::Events::AuthUserChangedPasswordParams.new(
        password: 'hunter2',
      )
    end

    let(:user_session) do
      {}
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
      it 'raises' do
        expect { subject.idv_gpo_user_requested_letter }.to raise_error
      end
    end

    context 'with idv_session' do
      let(:idv_session) { {} }

      it 'notes request in idv_session' do
        subject.idv_gpo_user_requested_letter
        expect(idv_session[:address_verification_mechanism]).to eql(:gpo)
      end
    end
  end

  describe('#idv_user_entered_ssn') do
    context('no idv_session') do
      it 'raises' do
        expect { subject.idv_user_entered_ssn(ssn: '123-45-6789') }.to raise_error
      end
    end

    context('idv_session present') do
      let(:idv_session) { {} }
      it 'sets pii[:ssn]' do
        subject.idv_user_entered_ssn(
          Idv::Engine::Events::IdvUserEnteredSsnParams.new(
            ssn: '123-45-6789',
          ),
        )
        expect(idv_session[:pii_from_doc]).to be
        expect(idv_session[:pii_from_doc][:ssn]).to eql('123-45-6789')
      end
    end
  end
end
