require 'rails_helper'

describe PartiallySignedInModalPresenter do
  include ActionView::Helpers::SanitizeHelper

  let(:expiration) { Time.zone.now + 1.minute + 1.second }
  let(:lookup_context) { ActionView::LookupContext.new(ActionController::Base.view_paths) }
  let(:view_context) { ActionView::Base.new(lookup_context, {}, nil) }
  subject(:presenter) do
    PartiallySignedInModalPresenter.new(view_context: view_context, expiration: expiration)
  end

  around do |ex|
    freeze_time { ex.run }
  end

  describe '#message' do
    it 'returns the partially signed in message' do
      expect(strip_tags(presenter.message)).to eq t(
        'notices.timeout_warning.partially_signed_in.message_html',
        time_left_in_session: '1 minute and 1 second',
      )
    end
  end

  describe '#sr_message' do
    it 'returns the partially signed in message for screen readers' do
      expect(strip_tags(presenter.sr_message)).to eq t(
        'notices.timeout_warning.partially_signed_in.sr_message_html',
        time_left_in_session: '1 minute and 1 second',
      )
    end
  end

  describe '#continue' do
    it 'uses the partially signed in localization' do
      expect(presenter.continue).to eq t('notices.timeout_warning.partially_signed_in.continue')
    end
  end

  describe '#sign_out' do
    it 'uses the partially signed in localization' do
      expect(presenter.sign_out).to eq t('notices.timeout_warning.partially_signed_in.sign_out')
    end
  end
end
