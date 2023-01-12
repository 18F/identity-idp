require 'rails_helper'

RSpec.describe CountdownComponent, type: :component do
  let(:expiration) { Time.zone.now + 1.minute + 1.second }

  around do |ex|
    freeze_time { ex.run }
  end

  it 'renders element with expected attributes and initial expiration time' do
    rendered = render_inline CountdownComponent.new(expiration:)

    element = rendered.css('lg-countdown', text: '1 minute and 1 second').first
    expect(element).to be_present
    expect(element.attr('data-expiration')).to eq(expiration.iso8601)
    expect(element.attr('data-update-interval')).to eq('1000')
    expect(element.attr('data-start-immediately')).to eq('true')
  end

  context 'with tag options' do
    it 'renders with attributes' do
      rendered = render_inline CountdownComponent.new(
        expiration:,
        data: { foo: 'bar' },
      )

      expect(rendered).to have_css('lg-countdown[data-expiration][data-foo="bar"]')
    end
  end

  context 'with custom update interval' do
    it 'assigns update interval in milliseconds' do
      rendered = render_inline CountdownComponent.new(
        expiration:,
        update_interval: 30.seconds,
      )

      expect(rendered).to have_css('lg-countdown[data-update-interval="30000"]')
    end
  end

  context 'with controlled start immediately' do
    it 'assigns attribute to start immediately' do
      rendered = render_inline CountdownComponent.new(
        expiration:,
        start_immediately: false,
      )

      expect(rendered).to have_css('lg-countdown[data-start-immediately="false"]')
    end
  end
end
