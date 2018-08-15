require 'rails_helper'

describe PivCacLoginOptionPolicy do
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

  describe '#available?' do
    let(:user) { build(:user) }

    context 'when enabled' do
      before(:each) do
        allow(subject).to receive(:enabled?).and_return(true)
      end

      it { expect(subject.available?).to be_truthy }
    end

    context 'when available for the email' do
      before(:each) do
        allow(subject).to receive(:available_for_email?).and_return(true)
      end

      it { expect(subject.available?).to be_truthy }
    end

    context 'when associated with a supported identity' do
      before(:each) do
        identity = double
        allow(identity).to receive(:piv_cac_available?).and_return(true)
        allow(user).to receive(:identities).and_return([identity])
      end

      it { expect(subject.available?).to be_truthy }
    end

    context 'when not enabled and not available for the email and not a supported identity' do
      before(:each) do
        identity = double
        allow(identity).to receive(:piv_cac_available?).and_return(false)
        allow(user).to receive(:identities).and_return([identity])
        allow(subject).to receive(:enabled?).and_return(false)
        allow(subject).to receive(:available_for_email?).and_return(false)
      end

      it { expect(subject.available?).to be_falsey }
    end
  end

  describe '#available_for_email?' do
    let(:result) { subject.send(:available_for_email?) }

    context 'with a configured parent domain' do
      before(:each) do
        allow(Figaro.env).to receive(:piv_cac_email_domains).and_return('[".example.com"]')
      end

      context 'and a supported email subdomain' do
        let(:user) { build(:user, email: 'someone@foo.example.com') }

        it { expect(result).to be_truthy }
      end

      context 'and a an email at that domain' do
        let(:user) { build(:user, email: 'someone@example.com') }

        it { expect(result).to be_falsey }
      end
    end

    context 'with a configured full domain' do
      before(:each) do
        allow(Figaro.env).to receive(:piv_cac_email_domains).and_return('["example.com"]')
      end

      context 'and an email subdomain' do
        let(:user) { build(:user, email: 'someone@foo.example.com') }

        it { expect(result).to be_falsey }
      end

      context 'and a an email at that domain' do
        let(:user) { build(:user, email: 'someone@example.com') }

        it { expect(result).to be_truthy }
      end
    end
  end
end
