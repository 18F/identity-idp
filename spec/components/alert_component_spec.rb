require 'rails_helper'

RSpec.describe AlertComponent, type: :component do
  it 'renders message from locals' do
    rendered = render_inline AlertComponent.new(message: 'FYI')

    expect(rendered).to have_content('FYI')
  end

  it 'renders message from block' do
    rendered = render_inline(AlertComponent.new) { 'FYI' }

    expect(rendered).to have_content('FYI')
  end

  it 'prefers message from constructor arg' do
    rendered = render_inline(AlertComponent.new(message: 'locals')) { 'block' }

    expect(rendered).to have_content('locals')
  end

  it 'renders without modifier classes by default' do
    rendered = render_inline AlertComponent.new(message: 'FYI')

    expect(rendered).to have_selector('.usa-alert:not([class*=usa-alert--])')
  end

  it 'accepts alert type param' do
    rendered = render_inline AlertComponent.new(type: :success, message: 'Hooray!')

    expect(rendered).to have_selector('.usa-alert.usa-alert--success')
  end

  it 'defaults to <p> tag for text' do
    rendered = render_inline AlertComponent.new(type: :success, message: 'Hooray!')

    expect(rendered).to have_selector('p.usa-alert__text')
  end

  it 'accepts text_tag param' do
    rendered = render_inline AlertComponent.new(type: :success, message: 'Hooray!', text_tag: 'div')

    expect(rendered).to have_selector('div.usa-alert__text')
    expect(rendered).to_not have_selector('p.usa-alert__text')
  end

  it 'accepts custom class names' do
    rendered = render_inline AlertComponent.new(message: 'FYI', class: 'my-custom-class')

    expect(rendered).to have_selector('.usa-alert.my-custom-class')
  end

  it 'accepts arbitrary tag options' do
    rendered = render_inline AlertComponent.new(message: 'FYI', data: { foo: 'bar' })

    expect(rendered).to have_selector('.usa-alert[data-foo="bar"]')
  end

  it 'assigns role="status"' do
    rendered = render_inline AlertComponent.new(message: 'FYI')

    expect(rendered).to have_selector('.usa-alert[role="status"]')
  end

  it 'assigns role="alert" for error type' do
    rendered = render_inline AlertComponent.new(type: :error, message: 'Attention!')

    expect(rendered).to have_selector('.usa-alert[role="alert"]')
  end

  it 'validates type' do
    expect do
      render_inline AlertComponent.new(type: 'alert', message: 'Attention!')
    end.to raise_error(ActiveModel::ValidationError)
  end

  # Safety invariant: in the legacy bucket, adding the new kwargs
  # (title:/dismissible:/action:) must not change the rendered output.
  describe 'legacy bucket ignores new kwargs (migration safety invariant)' do
    before do
      allow_any_instance_of(AlertComponent).to receive(:nds_bucket?).and_return(false)
    end

    def html(**options)
      render_inline(AlertComponent.new(message: 'FYI', **options)).to_html
    end

    it 'renders identical output whether or not title/dismissible/action are passed' do
      %i[info success warning error emergency].each do |type|
        baseline = html(type:)
        expect(html(type:, title: 'A title')).to eq(baseline)
        expect(html(type:, dismissible: true)).to eq(baseline)
        expect(html(type:, dismissible: false)).to eq(baseline)
        expect(html(type:, action: { label: 'Go', url: '/go' })).to eq(baseline)
        expect(
          html(type:, title: 'T', dismissible: true, action: { label: 'Go', url: '/go' }),
        ).to eq(baseline)
      end
    end

    it 'renders no action/close buttons and no mount wrapper' do
      rendered = render_inline(
        AlertComponent.new(
          type: :error, message: 'FYI', title: 'T', dismissible: true,
          action: { label: 'Go', url: '/go' }
        ),
      )
      expect(rendered).not_to have_css('lg-alert')
      expect(rendered).not_to have_css('.usa-alert__close')
      expect(rendered).not_to have_css('.usa-alert__action')
      expect(rendered).not_to have_css('.usa-alert__heading')
      expect(rendered)
        .to have_css('.usa-alert.usa-alert--error > .usa-alert__body > p.usa-alert__text')
    end
  end

  describe 'nds bucket' do
    before do
      # Flip both the alert and the nested action/close ButtonComponents into
      # the nds bucket (each resolves its own bucket at render time).
      allow_any_instance_of(AlertComponent).to receive(:nds_bucket?).and_return(true)
      allow_any_instance_of(ButtonComponent).to receive(:nds_bucket?).and_return(true)
    end

    it 'maps neutral (and nil default) to .usa-alert--info' do
      expect(render_inline(AlertComponent.new(type: :neutral, message: 'x')))
        .to have_css('.usa-alert.usa-alert--info')
      expect(render_inline(AlertComponent.new(message: 'x')))
        .to have_css('.usa-alert.usa-alert--info')
    end

    it 'always wraps text in .usa-alert__body' do
      expect(render_inline(AlertComponent.new(type: :success, message: 'x', dismissible: false)))
        .to have_css('.usa-alert__body > p.usa-alert__text', text: 'x')
    end

    it 'renders .usa-alert__heading when a title is given' do
      rendered = render_inline(
        AlertComponent.new(type: :warning, title: 'Heads up', message: 'x', dismissible: false),
      )
      expect(rendered).to have_css('.usa-alert__body > p.usa-alert__heading', text: 'Heads up')
      expect(rendered).to have_css('.usa-alert__body > p.usa-alert__text', text: 'x')
    end

    it 'omits the heading when no title' do
      expect(render_inline(AlertComponent.new(type: :warning, message: 'x', dismissible: false)))
        .not_to have_css('.usa-alert__heading')
    end

    it 'renders a dismissible mount wrapper + close button when dismissible: true' do
      rendered = render_inline(AlertComponent.new(type: :info, message: 'x', dismissible: true))
      expect(rendered)
        .to have_css('lg-alert.usa-alert-mount[data-open="false"] > .usa-alert-mount__inner')
      expect(rendered).to have_css('.usa-alert__close')
      expect(rendered).to have_css('.usa-button--quaternary.usa-alert__close')
    end

    it 'is non-dismissible by default: no mount wrapper or close button' do
      rendered = render_inline(AlertComponent.new(type: :info, message: 'x'))
      expect(rendered).not_to have_css('lg-alert')
      expect(rendered).not_to have_css('.usa-alert__close')
    end

    it 'omits the mount wrapper + close button when dismissible: false' do
      rendered = render_inline(AlertComponent.new(type: :info, message: 'x', dismissible: false))
      expect(rendered).not_to have_css('lg-alert')
      expect(rendered).not_to have_css('.usa-alert__close')
    end

    it 'renders an action button (tertiary) + --with-action modifier' do
      rendered = render_inline(
        AlertComponent.new(
          type: :info, message: 'x',
          action: { label: 'Do it', url: '/do' }
        ),
      )
      expect(rendered).to have_css('.usa-alert.usa-alert--with-action')
      expect(rendered).to have_css('a.usa-button--tertiary.usa-alert__action', text: 'Do it')
    end

    it 'validates action requires both label and url' do
      expect do
        render_inline(
          AlertComponent.new(type: :info, message: 'x', action: { label: 'Only label' }),
        )
      end.to raise_error(ActiveModel::ValidationError)
    end
  end
end
