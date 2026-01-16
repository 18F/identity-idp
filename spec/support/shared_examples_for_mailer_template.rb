RSpec.shared_examples 'a barcode email' do |service_provider_name|
  context 'when the partner agency logo is a png' do
    let(:logo) { 'gsa.png' }
    let(:logo_url) { '/assets/sp-logos/gsa.png' }

    it 'displays the partner agency logo' do
      expect(rendered).to have_css("img[src*='gsa.png']")
    end
  end

  context 'when the partner agency logo is a svg' do
    let(:logo) { 'generic.svg' }
    let(:logo_url) { nil }

    it 'displays the partner agency name' do
      expect(rendered).to have_content(service_provider_name)
    end
  end

  context 'when there is no partner agency logo' do
    let(:logo) { nil }
    let(:logo_url) { nil }

    it 'displays the partner agency name' do
      expect(rendered).to have_content(service_provider_name)
    end
  end
end
