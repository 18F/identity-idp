module AnalyticsHelper
  def stub_analytics(user = nil)
    @analytics = instance_double(Analytics)

    allow_any_instance_of(ActionDispatch::Request).to receive(:remote_ip).
      and_return('127.0.0.1')
    allow_any_instance_of(ActionDispatch::Request).to receive(:user_agent).
      and_return('special_agent')

    request_attributes = {
      user_agent: 'special_agent',
      user_ip: '127.0.0.1'
    }

    expect(Analytics).to receive(:new).with(user, request_attributes).and_return(@analytics)
  end
end
