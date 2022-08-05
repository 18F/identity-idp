require 'rails_helper'

describe BackupCodeReminderPresenter do
  let(:presenter) { described_class.new }

  describe '#title' do
    subject { presenter.title }

    it { is_expected.to eq(I18n.t('forms.backup_code.title')) }
  end

  describe '#heading' do
    subject { presenter.heading }

    it { is_expected.to eq(I18n.t('forms.backup_code_reminder.heading')) }
  end

  describe '#body_info' do
    subject { presenter.body_info }

    it { is_expected.to eq(I18n.t('forms.backup_code_reminder.body_info')) }
  end

  describe '#button' do
    subject { presenter.button }

    it { is_expected.to eq(I18n.t('forms.backup_code_reminder.have_codes')) }
  end

  describe '#need_new_codes_link_text' do
    subject { presenter.need_new_codes_link_text }

    it { is_expected.to eq(I18n.t('forms.backup_code_reminder.need_new_codes')) }
  end
end
