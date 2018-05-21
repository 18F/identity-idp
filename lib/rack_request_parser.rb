class RackRequestParser
  attr_reader :request

  def initialize(request)
    @request = request
  end

  def values_to_check
    param_values + ahoy_headers + ahoy_cookies
  end

  private

  def param_values
    all_values(request.params)
  end

  def all_values(hash)
    hash.values.flat_map { |value| value.is_a?(Hash) ? all_values(value) : [value] }
  end

  def ahoy_headers
    [ahoy_visit_header, ahoy_visitor_header]
  end

  def ahoy_visit_header
    request.fetch_header('HTTP_AHOY_VISIT') { '' }
  end

  def ahoy_visitor_header
    request.fetch_header('HTTP_AHOY_VISITOR') { '' }
  end

  def ahoy_cookies
    [ahoy_visit_cookie, ahoy_visitor_cookie]
  end

  def ahoy_visit_cookie
    request.cookies['ahoy_visit']
  end

  def ahoy_visitor_cookie
    request.cookies['ahoy_visitor']
  end
end
