require 'rails_helper'

RSpec.describe Idv::Engine::ProfileEngine do
  let(:user) { create(:user) }

  let(:idv_session) { nil }

  subject { described_class.new(user: user, idv_session: idv_session) }

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

  [:idv_started, :idv_consented].each do |method|
    describe(method.to_s) do
      it 'is a no-op' do
        subject.send(method)
        expect(user.profiles).to be_empty
      end
    end
  end

  describe('#idv_ssn_entered_by_user') do
    context('no idv_session') do
      it 'raises' do
        expect { subject.idv_ssn_entered_by_user(ssn: '123-45-6789') }.to raise_error
      end
    end

    context('idv_session present') do
      let(:idv_session) { {} }
      it 'sets pii[:ssn]' do
        subject.idv_ssn_entered_by_user(
          Idv::Engine::Events::IdvSsnEnteredByUserParams.new(
            ssn: '123-45-6789',
          ),
        )
        expect(idv_session[:pii_from_doc]).to be
        expect(idv_session[:pii_from_doc][:ssn]).to eql('123-45-6789')
      end
    end
  end
end
