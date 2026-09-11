require 'rails_helper'

RSpec.describe NDS::OfficialBannerComponent, type: :component do
  subject(:rendered) { render_inline(NDS::OfficialBannerComponent.new) }

  before { allow(FeatureManagement).to receive(:show_no_pii_banner?).and_return(false) }

  it 'renders the .official-banner section with flag and how button' do
    expect(rendered).to have_css('section.official-banner[aria-label]')
    expect(rendered).to have_css('.official-banner__content .official-banner__flag .usa-icon')
    expect(rendered).to have_css('.official-banner__text', text: t('shared.banner.official_site'))
    expect(rendered).to have_css(
      'button.link.official-banner__how[data-nds-modal-open]' \
      '[aria-controls="official-banner-modal"]',
      text: t('shared.banner.how'),
    )
  end

  it 'renders the explainer through NDS::ModalComponent as .modal' do
    # ModalComponent resolves nds_bucket?; force nds so it emits .modal.
    allow_any_instance_of(ModalComponent).to receive(:nds_bucket?).and_return(true)
    rendered = render_inline(NDS::OfficialBannerComponent.new)

    expect(rendered).to have_css('dialog.modal#official-banner-modal', visible: :all)
    expect(rendered).to have_css(
      '.modal__title',
      text: t('shared.banner.modal_title'),
      visible: :all,
    )
    expect(rendered).to have_css(
      '.official-banner-modal__item .official-banner-modal__heading',
      text: t('shared.banner.gov_heading'),
      visible: :all,
    )
    expect(rendered).to have_css(
      '.official-banner-modal__description',
      text: t('shared.banner.gov_description'),
      visible: :all,
    )
    expect(rendered).to have_css('hr.official-banner-modal__rule', visible: :all)
    expect(rendered).to have_css(
      '.official-banner-modal__heading',
      text: t('shared.banner.secure_heading'),
      visible: :all,
    )
  end

  it 'points the how button at the explainer dialog id' do
    button_controls = rendered.css('.official-banner__how').first['aria-controls']
    expect(button_controls).to eq('official-banner-modal')
  end

  it 'renders the test-notice only when show_no_pii_banner?' do
    expect(rendered).not_to have_css('.official-banner__test-notice')

    allow(FeatureManagement).to receive(:show_no_pii_banner?).and_return(true)
    with_notice = render_inline(NDS::OfficialBannerComponent.new)
    expect(with_notice).to have_css('.official-banner__test-notice')
  end
end
