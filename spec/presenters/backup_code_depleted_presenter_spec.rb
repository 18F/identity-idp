require 'rails_helper'

describe BackupCodeDepletedPresenter do
  include Rails.application.routes.url_helpers

  subject(:presenter) { BackupCodeDepletedPresenter.new }

  describe '#title' do
    it 'uses localization' do
      expect(presenter.title).to eq t('forms.backup_code.depleted_title')
    end
  end

  describe '#description' do
    it 'uses localization' do
      expect(presenter.description).to eq t('forms.backup_code.depleted_desc')
    end
  end

  describe '#other_option_display' do
    it 'is false for depleted' do
      expect(presenter.other_option_display).to be_falsey
    end
  end

  describe '#other_option_title' do
    it 'is nil for depleted' do
      expect(presenter.other_option_title).to eq nil
    end
  end

  describe '#other_option_path' do
    it 'is the correct path for two_factor_options' do
      expect(presenter.other_option_path).to eq two_factor_options_path
    end
  end

  describe '#continue_bttn_prologue' do
    it 'uses localization' do
      expect(presenter.continue_bttn_prologue).to eq nil
    end
  end

  describe '#continue_bttn_title' do
    it 'uses localization' do
      expect(presenter.continue_bttn_title).to eq t('forms.buttons.continue')
    end
  end

  describe '#continue_bttn_class' do
    it 'displays button to continue' do
      expect(presenter.continue_bttn_class).to eq 'btn btn-primary btn-wide'
    end
  end
end
