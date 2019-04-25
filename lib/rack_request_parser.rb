class RackRequestParser
  attr_reader :request

  def initialize(request)
    @request = request
  end

  def values_to_check
    param_values + header_values + cookie_values
  end

  private

  def param_values
    all_values(request.params)
  end

  def header_values
    header_values = []
    request.env.each do |key, value|
      header_values.push(value) if key.start_with? 'HTTP_'
    end
    header_values
  end

  def cookie_values
    request.cookies.values
  end

  def all_values(hash)
    hash.values.flat_map { |value| value.is_a?(Hash) ? all_values(value) : [value] }
  end
end
