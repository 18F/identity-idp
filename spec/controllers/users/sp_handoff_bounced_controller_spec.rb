require 'rails_helper'

RSpec.describe Users::SpHandoffBouncedController do
  describe '#bounced' do
    render_views

    before do
      request.env['devise.mapping'] = Devise.mappings[:user]
    end

    context 'with a service provider' do
      let(:sp_name) { '<b>Agency</b>' }
      let(:return_to_sp_url) { 'https://sp.example.com/return' }
      let(:service_provider) do
        create(:service_provider, friendly_name: sp_name, return_to_sp_url:)
      end

      before do
        session[:sp] = { issuer: service_provider.issuer }
      end

      it 'links to the service provider and escapes its name' do
        get :bounced

        expect(response.body).to have_link(sp_name, href: return_to_sp_url)
        expect(response.body).not_to have_css('p b')
        expect(response.body).not_to include('&lt;a href=')
      end
    end

    context 'without a service provider' do
      it 'names the service provider without a link' do
        get :bounced

        expect(response.body).to have_css(
          'p',
          text: t('instructions.sp_handoff_bounced_with_no_sp'),
        )
        expect(response.body).not_to have_css('p a')
      end
    end
  end
end
