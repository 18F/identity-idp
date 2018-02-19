require 'rails_helper'

describe 'sign_up/completions/show.html.slim' do
  before do
    @user = User.new
    @view_model = SignUpCompletionsShow.new(
      current_user: @user,
      loa3_requested: false,
      decorated_session: SessionDecorator.new
    )
  end

  it 'lists the users multiple sps' do
    identities = create_identities(@user, 3)
    render
    identities.each do |identity|
      expect(rendered).to have_content(identity.agency_name)
    end
    expect(rendered).to have_content(t('idv.messages.agencies_login'))
  end

  it 'shows the users service_provider' do
    identity = create_identities(@user).first
    render
    content = strip_tags(
      t('idv.messages.agency_login_html', sp: identity.display_name)
    )
    expect(rendered).to have_content(content)
  end

  private

  def create_identities(user, count = 0)
    (0..count).map do |index|
      sp = create(
        :service_provider,
        friendly_name: "SP app #{index}",
        agency: "Agency #{index}"
      )
      create(:identity, service_provider: sp.issuer, user: user)
    end
  end
end
