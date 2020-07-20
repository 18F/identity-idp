require 'rails_helper'

describe TwoFactorAuthentication::PivCacPolicy do
  let(:subject) { described_class.new(user) }

  describe '#configured?' do
    context 'without a piv configured' do
      let(:user) { build(:user) }

      it { expect(subject.configured?).to be_falsey }
    end

    context 'with a piv configured' do
      let(:user) { build(:user, :with_piv_or_cac) }

      it { expect(subject.configured?).to be_truthy }
    end
  end

  describe '#enabled?' do
    context 'without a piv configured' do
      let(:user) { build(:user) }

      it { expect(subject.configured?).to be_falsey }
    end

    context 'with a piv configured' do
      let(:user) { build(:user, :with_piv_or_cac) }

      it { expect(subject.configured?).to be_truthy }
    end
  end

  describe '#visible?' do
    let(:user) { build(:user) }

    context 'when enabled' do
      before(:each) do
        allow(subject).to receive(:enabled?).and_return(true)
      end

      it { expect(subject.visible?).to be_truthy }
    end

    context 'when available' do
      before(:each) do
        allow(subject).to receive(:available?).and_return(true)
      end

      it { expect(subject.visible?).to be_truthy }
    end

    context 'when neither enabled nor available' do
      before(:each) do
        allow(subject).to receive(:enabled?).and_return(false)
        allow(subject).to receive(:available?).and_return(false)
      end

      it { expect(subject.visible?).to be_falsey }
    end
  end

  describe '#required?' do
    let(:user) { build(:user) }

    context 'when allow_piv_cac_required is true' do
      before(:each) do
        allow(Figaro.env).to receive(:allow_piv_cac_required).and_return('true')
      end

      it 'returns false if the session is nil' do
        expect(subject.required?(nil)).to be_falsey
      end

      it 'returns false if the session has no sp session' do
        expect(subject.required?({})).to be_falsey
      end

      it 'returns false if the session has an empty sp session' do
        expect(subject.required?(sp: {})).to be_falsey
      end

      it 'returns false if x509_presented is not a requested attribute' do
        expect(subject.required?(sp: { requested_attributes: ['foo'] })).to be_falsey
      end

      it 'returns true if x509_presented is a requested attribute' do
        expect(subject.required?(sp: { requested_attributes: ['x509_presented'] })).to be_truthy
      end
    end

    context 'when allow_piv_cac_required is false' do
      before(:each) do
        allow(Figaro.env).to receive(:allow_piv_cac_required).and_return('false')
      end

      it 'returns false if the session is nil' do
        expect(subject.required?(nil)).to be_falsey
      end

      it 'returns false if the session has no sp session' do
        expect(subject.required?({})).to be_falsey
      end

      it 'returns false if the session has an empty sp session' do
        expect(subject.required?(sp: {})).to be_falsey
      end

      it 'returns false if x509_presented is not a requested attribute' do
        expect(subject.required?(sp: { requested_attributes: ['foo'] })).to be_falsey
      end

      it 'returns false if x509_presented is a requested attribute' do
        expect(subject.required?(sp: { requested_attributes: ['x509_presented'] })).to be_falsey
      end
    end
  end

  describe '#setup_required?' do
    let(:user) { build(:user) }

    context 'when the user already has a piv/cac configured' do
      before(:each) do
        allow(subject).to receive(:enabled?).and_return(true)
      end

      it 'returns false if piv/cac is required' do
        allow(subject).to receive(:required?).and_return(false)

        expect(subject.setup_required?(:foo)).to be_falsey
      end

      it 'returns false if piv/cac is not required' do
        allow(subject).to receive(:required?).and_return(false)

        expect(subject.setup_required?(:foo)).to be_falsey
      end
    end

    context 'when the user has no piv/cac configured' do
      before(:each) do
        allow(subject).to receive(:enabled?).and_return(false)
      end

      it 'returns true if piv/cac is required' do
        allow(subject).to receive(:required?).and_return(true)

        expect(subject.setup_required?(:foo)).to be_truthy
      end

      it 'returns false if piv/cac is not required' do
        allow(subject).to receive(:required?).and_return(false)

        expect(subject.setup_required?(:foo)).to be_falsey
      end
    end
  end
end
