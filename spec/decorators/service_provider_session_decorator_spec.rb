require 'rails_helper'

RSpec.describe ServiceProviderSessionDecorator do
  let(:view_context) { ActionController::Base.new.view_context }
  subject { ServiceProviderSessionDecorator.new(sp: sp, view_context: view_context) }
  let(:sp) { build_stubbed(:service_provider) }
  let(:sp_name) { subject.sp_name }

  it 'has the same public API as SessionDecorator' do
    SessionDecorator.public_instance_methods.each do |method|
      expect(
        described_class.public_method_defined?(method)
      ).to be(true), "expected #{described_class} to have ##{method}"
    end
  end

  describe '#return_to_service_provider_partial' do
    it 'returns the correct partial' do
      expect(subject.return_to_service_provider_partial).to eq(
        'devise/sessions/return_to_service_provider'
      )
    end
  end

  describe '#nav_partial' do
    it 'returns the correct partial' do
      expect(subject.nav_partial).to eq 'shared/nav_branded'
    end
  end

  describe '#new_session_heading' do
    it 'returns the correct string' do
      expect(subject.new_session_heading).to eq I18n.t('headings.sign_in_with_sp', sp: sp_name)
    end
  end

  describe '#registration_heading' do
    it 'returns the correct string' do
      expect(subject.registration_heading).to eq(
        I18n.t('headings.create_account_with_sp', sp: "<strong>#{sp_name}</strong>")
      )
    end
  end

  describe '#idv_hardfail4_partial' do
    it 'returns the correct partial' do
      expect(subject.idv_hardfail4_partial).to eq 'verify/hardfail4'
    end
  end

  describe '#logo_partial' do
    context 'logo present' do
      it 'returns branded logo partial' do
        sp_with_logo = build_stubbed(:service_provider, logo: 'foo')
        decorator = ServiceProviderSessionDecorator.new(
          sp: sp_with_logo, view_context: view_context
        )

        expect(decorator.logo_partial).to eq 'shared/nav_branded_logo'
      end
    end

    context 'logo not present' do
      it 'is null' do
        decorator = ServiceProviderSessionDecorator.new(
          sp: sp, view_context: view_context
        )

        expect(decorator.logo_partial).to eq 'shared/null'
      end
    end
  end

  describe '#timeout_flash_text' do
    it 'returns the correct string' do
      expect(subject.timeout_flash_text).
        to eq t('notices.session_cleared_with_sp',
                link: view_context.link_to(sp_name, sp.return_to_sp_url),
                minutes: Figaro.env.session_timeout_in_minutes,
                sp: sp_name)
    end
  end

  describe '#sp_name' do
    it 'returns the SP friendly name if present' do
      expect(subject.sp_name).to eq sp.friendly_name
      expect(subject.sp_name).to_not be_nil
    end

    it 'returns the agency name if friendly name is not present' do
      sp = build_stubbed(:service_provider, friendly_name: nil)
      subject = ServiceProviderSessionDecorator.new(sp: sp, view_context: view_context)
      expect(subject.sp_name).to eq sp.agency
      expect(subject.sp_name).to_not be_nil
    end
  end
end
