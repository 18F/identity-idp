require 'rails_helper'
require 'data_uri'

describe 'users/backup_code_setup/create.html.erb' do
  let(:user) { build(:user, :signed_up) }

  around do |ex|
    # data_uri depends on URI.decode which was removed in Ruby 3.0 :sob:
    module URI
      def self.decode(value)
        CGI.unescape(value)
      end
    end

    ex.run

    URI.singleton_class.undef_method(:decode)
  end

  before do
    allow(view).to receive(:current_user).and_return(user)
    @codes = BackupCodeGenerator.new(user).create
  end

  it 'displays download link with plain text content equal to the users backup codes' do
    render

    doc = Nokogiri::HTML(rendered)
    download_link = doc.at_css('a[download]')
    data_uri = URI::Data.new(download_link[:href])

    expect(rendered).to have_content((t('forms.backup_code.download')))
    expect(data_uri.content_type).to eq('text/plain')
    expect(data_uri.data).to eq(@codes.join("\n"))
  end
end
