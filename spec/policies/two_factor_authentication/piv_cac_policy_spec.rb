require 'rails_helper'

describe TwoFactorAuthentication::PivCacPolicy do
  let(:subject) { described_class.new(user) }

  describe '#available?' do
    context 'when not configured to be available only based on email' do
      context 'when a user has an identity' do
        let(:user) { create(:user) }

        let(:service_provider) do
          create(:service_provider)
        end

        let(:identity_with_sp) do
          Identity.create(
            user_id: user.id,
            service_provider: service_provider.issuer,
          )
        end

        before(:each) do
          user.identities << [identity_with_sp]
        end

        context 'allowing it' do
          before(:each) do
            allow_any_instance_of(ServiceProvider).to receive(:piv_cac?).and_return(true)
          end

          it 'does allow piv/cac' do
            expect(subject.available?).to be_truthy
          end
        end
      end

      context 'when a user has a piv/cac associated' do
        let(:user) { create(:user, :with_piv_or_cac) }

        it 'disallows piv/cac setup' do
          expect(subject.available?).to be_falsey
        end

        it 'allow piv/cac visibility' do
          expect(subject.visible?).to be_truthy
        end
      end
    end

    context 'when configured to be available only based on email' do
      context 'when a user has an allowed email address' do
        let(:user) { create(:user, :signed_up) }

        it 'allows piv/cac' do
          expect(subject.available?).to be_truthy
        end
      end

      context 'when a user has a piv/cac associated' do
        let(:user) { create(:user, :with_piv_or_cac) }

        it 'disallows piv/cac setup' do
          expect(subject.available?).to be_falsey
        end

        it 'allow piv/cac visibility' do
          expect(subject.visible?).to be_truthy
        end
      end
    end
  end

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
