require 'rails_helper'

describe PushNotification::AccountDelete do
  include PushNotificationsHelper

  let(:subject) { described_class.new }
  let(:push_notification_url) { 'http://localhost/push_notifications' }
  let(:push_notification_url2) { 'http://localhost:9292/push_notifications' }
  let(:user_id) { 1 }
  let(:payload) { { uuid: '1234' } }
  let(:payload2) { { uuid: '4567' } }

  before do
    AgencyIdentity.create(user_id: user_id, agency_id: 1, uuid: '1234')
  end

  it 'sends updates to one subscriber' do
    Timecop.freeze(Time.zone.now) do
      request = stub_request(:post, push_notification_url).
                with(headers: headers(push_notification_url, payload)).
                with(body: '').
                to_return(body: '')

      subject.call(user_id)

      expect(request).to have_been_requested
    end
  end

  it 'sends updates to two subscribers of the same agency' do
    sp = ServiceProvider.from_issuer('urn:gov:gsa:openidconnect:test:loa1')
    sp.push_notification_url = push_notification_url2
    sp.save!

    Timecop.freeze(Time.zone.now) do
      request = stub_request(:post, push_notification_url).
                with(headers: headers(push_notification_url, payload)).
                with(body: '').
                to_return(body: '')

      request2 = stub_request(:post, push_notification_url2).
                 with(headers: headers(push_notification_url2, payload)).
                 with(body: '').
                 to_return(body: '')

      subject.call(user_id)

      expect(request).to have_been_requested
      expect(request2).to have_been_requested
    end
  end

  it 'sends updates to two subscribers for two different agencies' do
    AgencyIdentity.create(user_id: user_id, agency_id: 2, uuid: '4567')

    sp = ServiceProvider.from_issuer('urn:gov:gsa:openidconnect:test:loa1')
    sp.push_notification_url = push_notification_url2
    sp.agency_id = 2
    sp.save!

    Timecop.freeze(Time.zone.now) do
      request = stub_request(:post, push_notification_url).
                with(headers: headers(push_notification_url, payload)).
                with(body: '').
                to_return(body: '')

      request2 = stub_request(:post, push_notification_url2).
                 with(headers: headers(push_notification_url2, payload2)).
                 with(body: '').
                 to_return(body: '')

      subject.call(user_id)

      expect(request).to have_been_requested
      expect(request2).to have_been_requested
    end
  end

  it 'writes failures to the retry table' do
    allow_any_instance_of(PushNotification::AccountDelete).
      to receive(:post_to_push_notification_url).and_raise(Faraday::ConnectionFailed.new('error'))

    subject.call(user_id)

    expect(PushAccountDelete.count).to eq(1)
    push_account_delete = PushAccountDelete.first
    expect(push_account_delete.uuid).to eq('1234')
    expect(push_account_delete.agency_id).to eq(1)
    expect(push_account_delete.created_at).to be_present
  end
end
