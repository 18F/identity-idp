require 'rails_helper'

describe MfaConfirmationPresenter do
  let(:user) { create(:user, :with_phone) }
  let(:presenter) { described_class.new(user) }
  let(:non_restriced_user) { create(:user, :with_authentication_app) }
  let(:non_restriced_presenter) { described_class.new(non_restriced_user) }

  before do
    allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return(true)
  end

  describe '#enforce_second_mfa?' do
    it 'checks the multi mfa feature flag and whether the user has a non restriced mfa' do
      expect(presenter.enforce_second_mfa?).to be true
      expect(non_restriced_presenter.enforce_second_mfa?).to be false
    end
  end

  describe '#heading?' do
    it 'supplies a message depending on #enforce_second_mfa?' do
      expect(presenter.heading).
        to eq(t('mfa.non_restricted.heading'))
      expect(non_restriced_presenter.heading).
        to eq(t('titles.mfa_setup.suggest_second_mfa'))
    end
  end

  describe '#info?' do
    it 'supplies a message depending on #enforce_second_mfa?' do
      expect(presenter.info).
        to eq(
          t(
            'mfa.non_restricted.info',
          ),
        )
      expect(non_restriced_presenter.info).
        to eq(t('mfa.account_info'))
    end
  end

  describe '#button?' do
    it 'supplies a message depending on #enforce_second_mfa?' do
      expect(presenter.button).
        to eq(t('mfa.non_restricted.button'))
      expect(non_restriced_presenter.button).
        to eq(t('mfa.add'))
    end
  end

  describe '#learn_more' do
    it 'supplies href for a link' do
      expect(presenter.learn_more).to eq(
        MarketingSite.help_center_article_url(
          category: 'get-started',
          article: 'authentication-options',
        ),
      )
    end
  end
end
