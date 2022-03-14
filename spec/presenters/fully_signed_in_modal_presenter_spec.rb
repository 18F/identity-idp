require 'rails_helper'

describe FullySignedInModalPresenter do
  include ActionView::Helpers::SanitizeHelper

  let(:expiration) { Time.zone.now + 1.minute + 1.second }
  let(:view_context) { ActionController::Base.new }
  subject(:presenter) do
    FullySignedInModalPresenter.new(view_context: view_context, expiration: expiration)
  end

  around do |ex|
    freeze_time { ex.run }
  end

  describe '#message' do
    it 'returns the fully signed in message' do
      expect(strip_tags(presenter.message)).to eq t(
        'notices.timeout_warning.signed_in.message_html',
        time_left_in_session: "1 minute and 1 second\n",
      )
    end
  end

  describe '#sr_message' do
    it 'returns the fully signed in message for screen readers' do
      expect(strip_tags(presenter.sr_message)).to eq t(
        'notices.timeout_warning.signed_in.sr_message_html',
        time_left_in_session: "1 minute and 1 second\n",
      )
    end
  end

  describe '#continue' do
    it 'uses the fully signed in localization' do
      expect(presenter.continue).to eq t('notices.timeout_warning.signed_in.continue')
    end
  end

  describe '#sign_out' do
    it 'uses the fully signed in localization' do
      expect(presenter.sign_out).to eq t('notices.timeout_warning.signed_in.sign_out')
    end
  end
end
