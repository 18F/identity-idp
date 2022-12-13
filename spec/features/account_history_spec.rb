require 'rails_helper'

describe 'Account history' do
  let(:user) { create(:user, :signed_up, created_at: Time.zone.now - 100.days) }
  let(:account_created_event) { create(:event, user: user, created_at: Time.zone.now - 98.days) }
  let(:gpo_mail_sent_event) do
    create(:event, user: user, event_type: :gpo_mail_sent, created_at: Time.zone.now - 90.days)
  end
  let(:identity_with_link) do
    create(
      :service_provider_identity,
      :active,
      user: user,
      last_authenticated_at: Time.zone.now - 80.days,
      service_provider: 'http://localhost:3000',
    )
  end
  let(:gpo_mail_sent_again_event) do
    create(:event, user: user, event_type: :gpo_mail_sent, created_at: Time.zone.now - 60.days)
  end
  let(:identity_without_link) do
    create(
      :service_provider_identity,
      :active,
      user: user,
      last_authenticated_at: Time.zone.now - 50.days,
      service_provider: 'https://rp2.serviceprovider.com/auth/saml/metadata',
    )
  end
  let(:account_created_timestamp) { account_created_event.decorate.happened_at_in_words }
  let(:gpo_mail_sent_timestamp) { gpo_mail_sent_event.decorate.happened_at_in_words }
  let(:identity_with_link_timestamp) do
    identity_with_link.happened_at.strftime(t('time.formats.event_timestamp'))
  end
  let(:gpo_mail_sent_again_timestamp) { gpo_mail_sent_again_event.decorate.happened_at_in_words }
  let(:identity_without_link_timestamp) do
    identity_without_link.happened_at.strftime(t('time.formats.event_timestamp'))
  end
  let(:new_personal_key_event) do
    create(
      :event,
      event_type: :new_personal_key,
      user: user,
      created_at: Time.zone.now - 40.days,
    )
  end
  let(:password_changed_event) do
    create(
      :event,
      event_type: :password_changed,
      user: user,
      created_at: Time.zone.now - 30.days,
    )
  end

  before do
    sign_in_and_2fa_user(user)
    build_account_history
    visit account_history_path
  end

  scenario 'viewing account history' do
    events = [
      account_created_event,
      gpo_mail_sent_event,
      gpo_mail_sent_again_event,
      new_personal_key_event,
      password_changed_event,
    ]
    events.each do |event|
      decorated_event = event.decorate
      expect(page).to have_content(decorated_event.event_type)
      expect(page).to have_content(decorated_event.happened_at_in_words)
    end

    expect(page).to have_content(
      t('event_types.authenticated_at', service_provider: identity_without_link.display_name),
    )
    expect(page).to_not have_link(identity_without_link.display_name)

    expect(page).to have_content(
      t(
        'event_types.authenticated_at_html',
        service_provider_link: identity_with_link.display_name,
      ),
    )
    expect(page).to have_link(
      identity_with_link.display_name, href: 'http://localhost:3000'
    )

    expect(identity_without_link_timestamp).to appear_before(gpo_mail_sent_again_timestamp)
    expect(gpo_mail_sent_again_timestamp).to appear_before(identity_with_link_timestamp)
    expect(identity_with_link_timestamp).to appear_before(gpo_mail_sent_timestamp)
    expect(gpo_mail_sent_timestamp).to appear_before(account_created_timestamp)
  end

  def build_account_history
    account_created_event
    gpo_mail_sent_event
    gpo_mail_sent_again_event
    identity_with_link
    identity_without_link
    new_personal_key_event
    password_changed_event
  end
end
