module DocAuthImageFixtures
  def self.document_front_image
    load_image_fixture('id-front.png')
  end

  def self.document_back_image
    load_image_fixture('id-back.png')
  end

  def self.document_face_image
    load_image_fixture('id-face.jpg')
  end

  def self.selfie_image
    load_image_fixture('selfie.jpg')
  end

  def self.load_image_fixture(filename)
    path = File.join(
      File.dirname(__FILE__),
      '../fixtures/doc_auth_images',
      filename,
    )
    File.read(path)
  end
end
