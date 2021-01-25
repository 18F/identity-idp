require 'rails_helper'

describe 'idv/usps/index.html.erb' do
  it 'calls UspsPresenter#title, #button, and #cancel_path' do
    user = build_stubbed(:user, :signed_up)
    usps_mail_service = Idv::UspsMail.new(user)

    usps_presenter = instance_double(Idv::UspsPresenter)
    allow(Idv::UspsPresenter).to receive(:new).with(usps_mail_service).
      and_return(usps_presenter)
    @presenter = usps_presenter

    expect(usps_presenter).to receive(:title)
    expect(usps_presenter).to receive(:button)
    expect(usps_presenter).to receive(:cancel_path)
    expect(usps_presenter).to receive(:byline)
    expect(usps_presenter).to receive(:usps_mail_bounced?)

    render
  end
end
