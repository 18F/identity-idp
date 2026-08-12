RSpec.shared_examples 'a mailer preview' do
  let(:mailer_class) { described_class.class_name.gsub(/Preview$/, '').constantize }

  it 'has a preview method for each mailer method' do
    # Rails 8.1 compiles callback runners (e.g. `_run_process_action_callbacks`)
    # directly onto the mailer class, so they show up in `instance_methods(false)`.
    # These are framework internals, not mailer actions, so exclude them.
    mailer_methods = mailer_class.instance_methods(false).reject do |method|
      method.start_with?('_')
    end
    preview_methods = described_class.instance_methods(false)
    expect(mailer_methods - preview_methods).to eql([])
  end

  described_class.instance_methods(false).each do |mailer_method|
    describe "##{mailer_method}" do
      subject(:mail) { described_class.new.public_send(mailer_method) }
      let(:body) { mail.parts.find { |part| part.content_type.start_with?('text/') }.body }

      it 'generates a preview without blowing up' do
        expect { body }.to_not raise_error
      end

      it 'does not include any svg images' do
        # SVGs are typically the preferred format for their high-quality and small file size, but
        # they are not well-supported in email clients. Instead, store a rasterized version of the
        # image in `app/assets/images/email` for use in mailer content.
        expect(body).not_to have_selector("img[src$='.svg']")
      end
    end
  end
end
