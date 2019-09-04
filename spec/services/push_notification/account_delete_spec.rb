require 'rails_helper'

describe PushNotification::AccountDelete do
  include PushNotificationsHelper

  let(:subject) { described_class.new }
  let(:push_notification_url) { 'http://localhost/push_notifications' }
  let(:push_notification_url2) { 'http://localhost:9292/push_notifications' }
  let(:user_id) { 1 }

  before do
    AgencyIdentity.create(user_id: user_id, agency_id: 1, uuid: '1234')
  end

  it 'sends updates to one subscriber' do
    request = stub_push_notification_request(
      sp_push_notification_endpoint: push_notification_url,
      topic: 'account_delete',
      payload: {
        'subject' => {
          'subject_type' => 'iss-sub',
          'iss' => 'urn:gov:gsa:openidconnect:test',
          'sub' => '1234',
        },
      },
    )

    subject.call(user_id)

    expect(request).to have_been_requested
  end

  it 'sends updates to two subscribers of the same agency' do
    sp = ServiceProvider.from_issuer('urn:gov:gsa:openidconnect:test:loa1')
    sp.push_notification_url = push_notification_url2
    sp.save!

    request = stub_push_notification_request(
      sp_push_notification_endpoint: push_notification_url,
      topic: 'account_delete',
      payload: {
        'subject' => {
          'subject_type' => 'iss-sub',
          'iss' => 'urn:gov:gsa:openidconnect:test',
          'sub' => '1234',
        },
      },
    )

    request2 = stub_push_notification_request(
      sp_push_notification_endpoint: push_notification_url2,
      topic: 'account_delete',
      payload: {
        'subject' => {
          'subject_type' => 'iss-sub',
          'iss' => 'urn:gov:gsa:openidconnect:test:loa1',
          'sub' => '1234',
        },
      },
    )

    subject.call(user_id)

    expect(request).to have_been_requested
    expect(request2).to have_been_requested
  end

  it 'sends updates to two subscribers for two different agencies' do
    AgencyIdentity.create(user_id: user_id, agency_id: 2, uuid: '4567')

    sp = ServiceProvider.from_issuer('urn:gov:gsa:openidconnect:test:loa1')
    sp.push_notification_url = push_notification_url2
    sp.agency_id = 2
    sp.save!

    request = stub_push_notification_request(
      sp_push_notification_endpoint: push_notification_url,
      topic: 'account_delete',
      payload: {
        'subject' => {
          'subject_type' => 'iss-sub',
          'iss' => 'urn:gov:gsa:openidconnect:test',
          'sub' => '1234',
        },
      },
    )

    request2 = stub_push_notification_request(
      sp_push_notification_endpoint: push_notification_url2,
      topic: 'account_delete',
      payload: {
        'subject' => {
          'subject_type' => 'iss-sub',
          'iss' => 'urn:gov:gsa:openidconnect:test:loa1',
          'sub' => '4567',
        },
      },
    )

    subject.call(user_id)

    expect(request).to have_been_requested
    expect(request2).to have_been_requested
  end

  it 'writes failures to the retry table on connection errors' do
    allow_any_instance_of(PushNotification::AccountDelete).
      to receive(:post_to_push_notification_url).and_raise(Faraday::ConnectionFailed.new('error'))

    subject.call(user_id)

    expect(PushAccountDelete.count).to eq(1)
    push_account_delete = PushAccountDelete.first
    expect(push_account_delete.uuid).to eq('1234')
    expect(push_account_delete.agency_id).to eq(1)
    expect(push_account_delete.created_at).to be_present
  end

  it 'writes failures to the retry table on bad status' do
    allow_any_instance_of(PushNotification::AccountDelete).
      to receive(:post_to_push_notification_url).and_return(Faraday::Response.new(status: 400))

    subject.call(user_id)

    expect(PushAccountDelete.count).to eq(1)
    push_account_delete = PushAccountDelete.first
    expect(push_account_delete.uuid).to eq('1234')
    expect(push_account_delete.agency_id).to eq(1)
    expect(push_account_delete.created_at).to be_present
  end

  it 'writes to NewRelic on bad status' do
    allow_any_instance_of(PushNotification::AccountDelete).
      to receive(:post_to_push_notification_url).and_return(Faraday::Response.new(status: 400))

    expect(NewRelic::Agent).to receive(:notice_error).
      with(instance_of(PushNotification::PushNotificationError))
    subject.call(user_id)
  end

  it 'writes to NewRelic on conection errors' do
    error = Faraday::ConnectionFailed.new('error')
    allow_any_instance_of(PushNotification::AccountDelete).
      to receive(:post_to_push_notification_url).and_raise(error)

    expect(NewRelic::Agent).to receive(:notice_error).with(error)
    subject.call(user_id)
  end
end
