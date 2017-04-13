class Reauthn
  def initialize(params)
    @params = params
  end

  def call
    reauthn == 'true'
  end

  private

  attr_reader :params

  def reauthn
    params[:reauthn]
  end
end
