class PhoneInputComponentPreview < BaseComponentPreview
  # @!group Preview
  # @display form true
  def default
    render(PhoneInputComponent.new(form: form_builder))
  end

  def limited_country_selection
    render(PhoneInputComponent.new(form: form_builder, allowed_countries: ['US', 'CA', 'FR']))
  end

  def single_country_selection
    render(PhoneInputComponent.new(form: form_builder, allowed_countries: ['US']))
  end
  # @!endgroup

  # @display form true
  # @param allowed_countries text
  def workbench(allowed_countries: 'US,CA,FR')
    render(
      PhoneInputComponent.new(
        form: form_builder,
        allowed_countries: allowed_countries.split(','),
      ),
    )
  end

  private

  def form_instance
    Class.new do
      def international_code; end

      def phone; end
    end.new
  end
end
