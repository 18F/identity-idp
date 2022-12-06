require 'rails_helper'

RSpec.describe CountdownAlertComponent, type: :component do
  let(:expiration) { Time.zone.now + 1.minute + 1.second }

  around do |ex|
    freeze_time { ex.run }
  end

  it 'renders element with expected attributes and initial expiration time' do
    rendered = render_inline CountdownAlertComponent.new(
      countdown_options: { expiration: expiration },
    )

    expect(rendered).to have_css('lg-countdown-alert', text: '1 minute and 1 second remaining')
    expect(rendered).to have_css('.usa-alert.usa-alert--info.usa-alert--info-time')
  end

  context 'with show_at_remaining' do
    it 'renders as hidden by default with expected attributes' do
      rendered = render_inline CountdownAlertComponent.new(
        show_at_remaining: 1.minute,
        countdown_options: { expiration: expiration },
      )

      expect(rendered).to have_css('lg-countdown-alert[show-at-remaining=60000].display-none')
    end

    context 'with tag options' do
      it 'renders with attributes' do
        rendered = render_inline CountdownAlertComponent.new(
          show_at_remaining: 1.minute,
          countdown_options: { expiration: expiration },
          class: 'example',
          data: { foo: 'bar' },
        )

        expect(rendered).to have_css('lg-countdown-alert.example.display-none[data-foo="bar"]')
      end
    end
  end

  context 'with tag options' do
    it 'renders with attributes' do
      rendered = render_inline CountdownAlertComponent.new(
        countdown_options: { expiration: expiration },
        class: 'example',
        data: { foo: 'bar' },
      )

      expect(rendered).to have_css('lg-countdown-alert.example[data-foo="bar"]')
    end
  end

  context 'with countdown options' do
    it 'renders countdown with attributes' do
      rendered = render_inline CountdownAlertComponent.new(
        countdown_options: { expiration: expiration, data: { foo: 'bar' } },
      )

      expect(rendered).to have_css('lg-countdown[data-expiration][data-foo="bar"]')
    end
  end

  context 'with alert options' do
    it 'renders alert with attributes' do
      rendered = render_inline CountdownAlertComponent.new(
        countdown_options: { expiration: expiration },
        alert_options: { data: { foo: 'bar' } },
      )

      expect(rendered).to have_css('.usa-alert[data-foo="bar"]')
    end
  end
end
