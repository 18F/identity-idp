require 'rails_helper'

describe AdditionalMfaRequiredPresenter do
  let(:user) { create(:user, :with_phone) }
  let(:presenter) { described_class.new(current_user: user) }
  let(:enforcement_date) { Time.zone.today + 6.days }
  let(:current_date) { Time.zone.today }

  before do
    allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return(true)
    allow(IdentityConfig.store).to receive(:kantara_restriction_enforcement_date).
      and_return(enforcement_date.to_datetime)
  end

  describe '#title' do
    context 'when its before enforcement date' do
      it 'supplies proper title' do
        expect(presenter.title).
          to eq(
            t(
              'mfa.additional_mfa_required.title',
              date: I18n.l(enforcement_date.to_datetime, format: :event_date),
            ),
          )
      end
    end

    context 'when its after enforcement date' do
      let(:enforcement_date) { Time.zone.today - 6.days }
      it 'supplies proper title' do
        expect(presenter.title).
          to eq(t('mfa.additional_mfa_required.heading'))
      end
    end
  end

  describe '#info' do
    context 'when its before enforcement date' do
      it 'supplies proper info' do
        expect(presenter.info).
          to eq(
            t(
              'mfa.additional_mfa_required.info',
              date: I18n.l(enforcement_date.to_datetime, format: :event_date),
            ),
          )
      end
    end

    context 'when its after enforcement date' do
      let(:enforcement_date) { Time.zone.today - 6.days }
      it 'supplies proper info' do
        expect(presenter.info).
          to eq(t('mfa.additional_mfa_required.non_restricted_required_info'))
      end
    end
  end

  describe '#skip' do
    context 'when its before enforcement date' do
      it 'supplies proper skip text' do
        expect(presenter.skip).
          to eq(t('mfa.skip'))
      end
    end

    context 'when its after enforcement date' do
      let(:enforcement_date) { Time.zone.today - 6.days }
      it 'supplies proper skip text' do
        expect(presenter.skip).
          to eq(t('mfa.skip_once'))
      end
    end
  end

  describe '#cant_skip_anymore?' do
    context 'when its before enforcement date' do
      it 'should return false' do
        expect(presenter.cant_skip_anymore?).
          to be_falsey
      end
    end

    context 'when its after enforcement date' do
      context 'when user doesnt have attribute set' do
        let(:enforcement_date) { Time.zone.today - 6.days }

        it 'should return false' do
          expect(presenter.cant_skip_anymore?).
          to be_falsey
        end
      end

      context 'when users have attribute set' do
        let(:enforcement_date) { Time.zone.today - 6.days }
        before do
          allow(user).to receive(:non_restricted_mfa_required_prompt_skip_date).
            and_return(current_date)
        end

        it 'should return true' do
          expect(presenter.cant_skip_anymore?).
          to be_truthy
        end
      end
    end
  end
end
