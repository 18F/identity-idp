module Idv
  module Utils
    class ImagesToTmpFiles
      def initialize(*images)
        @images = images
      end

      def call
        tmp_files = images_to_tmp_files
        yield tmp_files
      ensure
        tmp_files.each { |tmp| delete_file(tmp) }
      end

      private

      def images_to_tmp_files
        @images.map do |image|
          Tempfile.open('foo', encoding: 'ascii-8bit').tap do |tmp|
            write_file(tmp, image)
          end
        end
      end

      def write_file(tmp, image)
        tmp.write(image)
        tmp.rewind
      end

      def delete_file(tmp)
        tmp.close
        tmp.unlink
      end
    end
  end
end
