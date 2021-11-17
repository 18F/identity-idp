require 'rails_helper'

describe 'vendor_outage/show.html.erb' do
  let(:show_gpo_option) { false }

  subject(:rendered) { render }

  before do
    @show_gpo_option = show_gpo_option
  end

  it 'does not render gpo option' do
    expect(rendered).not_to have_link(t('idv.troubleshooting.options.verify_by_mail'))
  end

  context 'gpo option shown' do
    let(:show_gpo_option) { true }

    it 'renders gpo option' do
      expect(rendered).to have_link(t('idv.troubleshooting.options.verify_by_mail'))
    end
  end
end
