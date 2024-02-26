require 'rails_helper'

RSpec.describe 'users/backup_code_setup/index.html.erb' do
  let(:user) { build(:user, :fully_registered) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:in_account_creation_flow?).and_return(false)
    @codes = BackupCodeGenerator.new(user).create
  end

  it 'has a localized title' do
    expect(view).to receive(:title=).with(t('forms.backup_code.title'))

    render
  end

  it 'displays download link with plain text content equal to the users backup codes' do
    render

    doc = Nokogiri::HTML(rendered)
    download_link = doc.at_css('a[download]')
    data_uri = Idv::DataUrlImage.new(download_link[:href])

    expect(rendered).to have_content(t('components.download_button.label'))
    expect(data_uri.content_type).to include('text/plain')
    expect(data_uri.read).to eq(@codes.join("\n"))
  end

  it 'displays alert for backup code usage' do
    render

    expect(rendered).to have_selector(
      '.usa-alert',
      text: t('forms.backup_code.caution_codes'),
    )
  end

  it 'displays save backup codes checkbox' do
    render

    expect(rendered).to have_selector('lg-validated-field')
    expect(rendered).to have_selector('input[type=checkbox]')
  end

  it 'contains form post to backup_code_continue_path' do
    render

    expect(rendered).
      to have_xpath("//form[@action='#{backup_code_continue_path}']")
    expect(rendered).
      to have_xpath("//form[@method='post']")
  end

  it 'has continue button' do
    render

    expect(rendered).to have_button t('forms.buttons.continue')
  end

  context 'during account creation' do
    before do
      allow(view).to receive(:current_user).and_return(user)
      allow(view).to receive(:in_account_creation_flow?).and_return(true)
      @codes = BackupCodeGenerator.new(user).create
    end

    it 'shows a link to add another authentication method' do
      render

      expect(rendered).to have_link t(
        'two_factor_authentication.backup_codes.add_another_authentication_option',
      )
    end

    it 'shows a link to cancel account creation' do
      render

      expect(rendered).to have_button t(
        'links.cancel'
      )
    end
  end
end
