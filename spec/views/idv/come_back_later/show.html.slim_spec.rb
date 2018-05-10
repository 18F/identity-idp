require 'rails_helper'

describe 'idv/come_back_later/show.html.slim' do
  let(:sp_return_url) { 'https://www.example.com' }
  let(:sp_name) { '🔒🌐💻' }

  before do
    @decorated_session = instance_double(ServiceProviderSessionDecorator)
    allow(@decorated_session).to receive(:sp_return_url).and_return(sp_return_url)
    allow(@decorated_session).to receive(:sp_name).and_return(sp_name)
    allow(view).to receive(:decorated_session).and_return(@decorated_session)
  end

  context 'with an SP with a return url' do
    it 'renders a return to SP button' do
      render
      expect(rendered).to have_link(
        t('idv.buttons.continue_plain'),
        href: sp_return_url
      )
    end

    it 'renders return to SP message' do
      render
      expect(rendered).to have_content(
        strip_tags(t(
          'idv.messages.come_back_later_sp_html',
          sp: @decorated_session.sp_name
        ))
      )
    end
  end

  context 'with an SP without a return url' do
    let(:sp_return_url) { nil }

    it 'renders a return to account button' do
      render
      expect(rendered).to have_link(
        t('idv.buttons.continue_plain', sp: sp_name),
        href: account_path
      )
    end
  end

  context 'without an SP' do
    let(:sp_return_url) { nil }
    let(:sp_name) { nil }

    it 'renders a return to account button' do
      render
      expect(rendered).to have_link(
        t('idv.buttons.continue_plain', sp: sp_name),
        href: account_path
      )
    end

    it 'renders return to account message' do
      render
      expect(rendered).to have_content(
        strip_tags(t(
          'idv.messages.come_back_later_no_sp_html',
          app: APP_NAME
        ))
      )
    end
  end
end
