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
end
