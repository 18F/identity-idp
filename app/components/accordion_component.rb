class AccordionComponent < BaseComponent
  renders_script
  renders_one :header

  def initialize
    @target_id = "accordion-#{SecureRandom.hex(4)}"
  end
end
