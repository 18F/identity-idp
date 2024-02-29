module AcuantFixtures
  def self.get_results_response_failure
    load_response_fixture('get_results_response_failure.json')
  end

  def self.load_response_fixture(filename)
    path = File.join(
      File.dirname(__FILE__),
      '../fixtures/acuant_responses',
      filename,
    )
    File.read(path)
  end
end
