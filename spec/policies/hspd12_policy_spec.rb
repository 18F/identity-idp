require 'rails_helper'

describe Hspd12Policy do
  let(:user) { build(:user) }
  let(:subject) { described_class.new(session: session, user: user) }

  describe '#piv_cac_required?' do
    context 'when allow_piv_cac_required is true' do
      before(:each) do
        allow(Figaro.env).to receive(:allow_piv_cac_required).and_return('true')
      end

      it 'returns false if the session is nil' do
        session = nil

        expect_piv_cac_required_to(be_falsey, session)
      end

      it 'returns false if the session has no sp session' do
        session = {}

        expect_piv_cac_required_to(be_falsey, session)
      end

      it 'returns false if the session has an empty sp session' do
        session = { sp: {} }

        expect_piv_cac_required_to(be_falsey, session)
      end

      it 'returns false if x509_presented is not a requested attribute' do
        session = { sp: { requested_attributes: ['foo'] } }

        expect_piv_cac_required_to(be_falsey, session)
      end

      it 'returns true if x509_presented is a requested attribute' do
        session = { sp: { requested_attributes: ['x509_presented'] } }

        expect_piv_cac_required_to(be_truthy, session)
      end
    end

    context 'when allow_piv_cac_required is false' do
      before(:each) do
        allow(Figaro.env).to receive(:allow_piv_cac_required).and_return('false')
      end

      it 'returns false if the session is nil' do
        session = nil

        expect_piv_cac_required_to(be_falsey, session)
      end

      it 'returns false if the session has no sp session' do
        session = {}

        expect_piv_cac_required_to(be_falsey, session)
      end

      it 'returns false if the session has an empty sp session' do
        session = { sp: {} }

        expect_piv_cac_required_to(be_falsey, session)
      end

      it 'returns false if x509_presented is not a requested attribute' do
        session = { sp: { requested_attributes: ['foo'] } }

        expect_piv_cac_required_to(be_falsey, session)
      end

      it 'returns false if x509_presented is a requested attribute' do
        session = { sp: { requested_attributes: ['x509_presented'] } }

        expect_piv_cac_required_to(be_falsey, session)
      end
    end
  end

  describe '#piv_cac_setup_required?' do
    context 'when the user already has a piv/cac configured' do
      before(:each) do
        allow_any_instance_of(TwoFactorAuthentication::PivCacPolicy).to receive(:enabled?).
          and_return(true)
      end

      it 'returns false if piv/cac is required' do
        allow_any_instance_of(Hspd12Policy).to receive(:piv_cac_required?).and_return(true)

        expect_piv_cac_setup_required_to be_falsey
      end

      it 'returns false if piv/cac is not required' do
        allow_any_instance_of(Hspd12Policy).to receive(:piv_cac_required?).and_return(false)

        expect_piv_cac_setup_required_to be_falsey
      end
    end

    context 'when the user has no piv/cac configured' do
      before(:each) do
        allow_any_instance_of(TwoFactorAuthentication::PivCacPolicy).to receive(:enabled?).
          and_return(false)
      end

      it 'returns true if piv/cac is required' do
        allow_any_instance_of(Hspd12Policy).to receive(:piv_cac_required?).and_return(true)

        expect_piv_cac_setup_required_to be_truthy
      end

      it 'returns false if piv/cac is not required' do
        allow_any_instance_of(Hspd12Policy).to receive(:piv_cac_required?).and_return(false)

        expect_piv_cac_setup_required_to be_falsey
      end
    end
  end

  def expect_piv_cac_required_to(value, session)
    expect(Hspd12Policy.new(user: user, session: session).piv_cac_required?).to(value)
  end

  def expect_piv_cac_setup_required_to(value)
    expect(Hspd12Policy.new(user: user, session: :foo).piv_cac_setup_required?).to(value)
  end
end
