module AcuantFixtures
  def self.create_document_response
    load_response_fixture('create_document_response.json')
  end

  # rubocop:disable Naming/AccessorMethodName
  def self.get_results_response_success
    load_response_fixture('get_results_response_success.json')
  end
  # rubocop:enable Naming/AccessorMethodName

  # rubocop:disable Naming/AccessorMethodName
  def self.get_results_response_failure
    load_response_fixture('get_results_response_failure.json')
  end
  # rubocop:enable Naming/AccessorMethodName

  def self.load_response_fixture(filename)
    path = File.join(
      File.dirname(__FILE__),
      '../fixtures/acuant_responses',
      filename,
    )
    File.read(path)
  end
end
