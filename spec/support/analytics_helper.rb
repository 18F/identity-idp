module AnalyticsHelper
  def stub_analytics(user = nil)
    @analytics = instance_double(Analytics)
    ahoy = instance_double(NullAhoyTracker)

    allow_any_instance_of(ActionDispatch::Request).to receive(:remote_ip).
      and_return('127.0.0.1')
    allow_any_instance_of(ActionDispatch::Request).to receive(:user_agent).
      and_return('special_agent')

    request_attributes = {
      user_agent: 'special_agent',
      user_ip: '127.0.0.1'
    }

    expect(NullAhoyTracker).to receive(:new).at_least(:once).and_return(ahoy)
    expect(ahoy).to receive(:set_visitor_cookie).at_least(:once)
    expect(ahoy).to receive(:set_visit_cookie).at_least(:once)
    expect(ahoy).to receive(:new_visit?).at_least(:once)

    expect(Analytics).to receive(:new).at_least(:once).with(user, request_attributes, ahoy).
      and_return(@analytics)
  end
end
