require 'rails_helper'

RSpec.describe VendorOutageAlertComponent, type: :component do
  let(:vendors) { [:sms, :voice] }
  let(:context) { 'default' }
  let(:only_if_all) { false }

  subject(:rendered) do
    render_inline VendorOutageAlertComponent.new(
      vendors: vendors,
      context: context,
      only_if_all: only_if_all,
    )
  end

  context 'with no outage' do
    before do
      allow_any_instance_of(VendorStatus).to receive(:vendor_outage?).and_return(false)
    end

    it 'renders nothing' do
      expect(rendered.to_s).to be_empty
    end
  end

  context 'with outage' do
    before do
      allow_any_instance_of(VendorStatus).to receive(:vendor_outage?).with(:sms).and_return(true)
      allow_any_instance_of(VendorStatus).to receive(:vendor_outage?).with(:voice).and_return(false)
    end

    it 'renders error alert with status page url' do
      expect(rendered).to have_content(t('vendor_outage.alerts.sms.default'))
      expect(rendered).to have_link(t('vendor_outage.get_updates'), href: StatusPage.base_url)
    end

    context 'with contextual message' do
      subject(:context) { :idv }

      it 'renders error alert with contextualized message' do
        expect(rendered).to have_content(t('vendor_outage.alerts.sms.idv'))
      end

      context 'with unknown contextual message' do
        subject(:context) { :unknown }

        it 'renders error alert with default message' do
          expect(rendered).to have_content(t('vendor_outage.alerts.sms.default'))
        end
      end
    end

    context 'constrained to only_if_all' do
      let(:only_if_all) { true }
      let(:all_outage) { false }

      before do
        allow_any_instance_of(VendorStatus).to receive(:all_vendor_outage?).and_return(all_outage)
      end

      it 'renders nothing' do
        expect(rendered.to_s).to be_empty
      end

      context 'with all outage' do
        let(:all_outage) { true }

        it 'renders error alert' do
          expect(rendered).to have_content(t('vendor_outage.alerts.phone.default'))
        end
      end
    end
  end
end
