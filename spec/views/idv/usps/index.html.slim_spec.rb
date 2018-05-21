require 'rails_helper'

describe 'idv/usps/index.html.slim' do
  it 'calls UspsDecorator#title and #button' do
    user = build_stubbed(:user, :signed_up)
    usps_mail_service = Idv::UspsMail.new(user)

    usps_decorator = instance_double(UspsDecorator)
    allow(UspsDecorator).to receive(:new).with(usps_mail_service).
      and_return(usps_decorator)
    @decorated_usps = usps_decorator

    expect(usps_decorator).to receive(:title)
    expect(usps_decorator).to receive(:button)

    render
  end
end
