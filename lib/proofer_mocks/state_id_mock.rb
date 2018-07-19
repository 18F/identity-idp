class StateIdMock < Proofer::Base
  SUPPORTED_STATES = %w[
    AR AZ CO DC DE FL IA ID IL IN KY MA MD ME MI MS MT ND NE NJ NM PA SD TX VA WA WI WY
  ].freeze

  SUPPORTED_STATE_ID_TYPES = %w[
    drivers_license drivers_permit state_id_card
  ].freeze

  attributes :state_id_number, :state_id_type, :state_id_jurisdiction

  stage :state_id

  proof do |applicant, result|
    if state_not_supported?(applicant[:state_id_jurisdiction])
      result.add_error(:state_id_jurisdiction, 'The jurisdiction could not be verified')

    elsif invalid_state_id_number?(applicant[:state_id_number])
      result.add_error(:state_id_number, 'The state ID number could not be verified')

    elsif invalid_state_id_type?(applicant[:state_id_type])
      result.add_error(:state_id_type, 'The state ID type could not be verified')
    end
  end

  private

  def state_not_supported?(state_id_jurisdiction)
    !SUPPORTED_STATES.include? state_id_jurisdiction
  end

  def invalid_state_id_number?(state_id_number)
    state_id_number =~ /\A0*\z/
  end

  def invalid_state_id_type?(state_id_type)
    !SUPPORTED_STATE_ID_TYPES.include?(state_id_type) ||
      state_id_type.nil?
  end
end
