require 'rails_helper'

describe BackupCodeCreatePresenter do
  include Rails.application.routes.url_helpers

  subject(:presenter) { BackupCodeCreatePresenter.new }

  describe '#title' do
    it 'uses localization' do
      expect(presenter.title).to eq t('forms.backup_code.are_you_sure_title')
    end
  end

  describe '#description' do
    it 'uses localization' do
      expect(presenter.description).to eq t('forms.backup_code.are_you_sure_desc')
    end
  end

  describe '#other_option_display' do
    it 'is true for create' do
      expect(presenter.other_option_display).to be_truthy
    end
  end

  describe '#other_option_title' do
    it 'uses localization' do
      expect(presenter.other_option_title).to eq t('forms.backup_code.are_you_sure_other_option')
    end
  end

  describe '#continue_bttn_prologue' do
    it 'uses localization' do
      expect(presenter.continue_bttn_prologue).
        to eq t('forms.backup_code.are_you_sure_continue_prologue')
    end
  end
end
