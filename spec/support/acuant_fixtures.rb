module AcuantFixtures
  def self.create_document_response
    load_response_fixture('create_document_response.json')
  end

  def self.get_results_response_success
    load_response_fixture('get_results_response_success.json')
  end

  def self.get_results_response_failure
    load_response_fixture('get_results_response_failure.json')
  end

  def self.get_results_response_expired
    load_response_fixture('get_results_response_expired.json')
  end

  def self.get_face_image_response
    load_response_fixture('get_face_image_response.jpg')
  end

  def self.facial_match_response_success
    load_response_fixture('facial_match_response_success.json')
  end

  def self.facial_match_response_failure
    load_response_fixture('facial_match_response_failure.json')
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
