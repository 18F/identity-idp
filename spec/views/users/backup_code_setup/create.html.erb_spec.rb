require 'rails_helper'

RSpec.describe 'users/backup_code_setup/create.html.erb' do
  let(:user) { build(:user, :fully_registered) }

  before do
    allow(view).to receive(:current_user).and_return(user)
    @codes = BackupCodeGenerator.new(user).create
  end

  it 'displays download link with plain text content equal to the users backup codes' do
    render

    doc = Nokogiri::HTML(rendered)
    download_link = doc.at_css('a[download]')
    data_uri = Idv::DataUrlImage.new(download_link[:href])

    expect(rendered).to have_content((t('components.download_button.label')))
    expect(data_uri.content_type).to include('text/plain')
    expect(data_uri.read).to eq(@codes.join("\n"))
  end
end
