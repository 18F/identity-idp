# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `rqrcode` gem.
# Please instead update this file by running `bin/tapioca gem rqrcode`.


# source://rqrcode//lib/rqrcode.rb#3
module RQRCode; end

# source://rqrcode//lib/rqrcode/export/ansi.rb#4
module RQRCode::Export; end

# source://rqrcode//lib/rqrcode/export/ansi.rb#5
module RQRCode::Export::ANSI
  # Returns a string of the QR code as
  # characters writen with ANSI background set.
  #
  # Options:
  # light: Foreground ("\033[47m")
  # dark: Background ANSI code. ("\033[40m")
  # fill_character: The written character. ('  ')
  # quiet_zone_size: (4)
  #
  # source://rqrcode//lib/rqrcode/export/ansi.rb#16
  def as_ansi(options = T.unsafe(nil)); end
end

# source://rqrcode//lib/rqrcode/export/html.rb#5
module RQRCode::Export::HTML
  # Use this module to HTML-ify the QR code if you just want the default HTML
  #
  # source://rqrcode//lib/rqrcode/export/html.rb#8
  def as_html; end

  private

  # source://rqrcode//lib/rqrcode/export/html.rb#14
  def rows; end
end

# source://rqrcode//lib/rqrcode/export/html.rb#38
class RQRCode::Export::HTML::Cell < ::Struct
  # source://rqrcode//lib/rqrcode/export/html.rb#39
  def as_html; end

  # source://rqrcode//lib/rqrcode/export/html.rb#43
  def html_class; end
end

# source://rqrcode//lib/rqrcode/export/html.rb#28
class RQRCode::Export::HTML::Row < ::Struct
  # source://rqrcode//lib/rqrcode/export/html.rb#29
  def as_html; end

  # source://rqrcode//lib/rqrcode/export/html.rb#33
  def cells; end
end

# source://rqrcode//lib/rqrcode/export/html.rb#18
class RQRCode::Export::HTML::Rows < ::Struct
  # source://rqrcode//lib/rqrcode/export/html.rb#19
  def as_html; end

  # source://rqrcode//lib/rqrcode/export/html.rb#23
  def rows; end
end

# source://rqrcode//lib/rqrcode/export/png.rb#9
module RQRCode::Export::PNG
  # Render the PNG from the QR Code.
  #
  # Options:
  # fill  - Background ChunkyPNG::Color, defaults to 'white'
  # color - Foreground ChunkyPNG::Color, defaults to 'black'
  #
  # When option :file is supplied you can use the following ChunkyPNG constraints
  # color_mode  - The color mode to use. Use one of the ChunkyPNG::COLOR_* constants.
  #               (defaults to 'ChunkyPNG::COLOR_GRAYSCALE')
  # bit_depth   - The bit depth to use. This option is only used for indexed images.
  #               (defaults to 1 bit)
  # interlace   - Whether to use interlacing (true or false).
  #               (defaults to ChunkyPNG default)
  # compression - The compression level for Zlib. This can be a value between 0 and 9, or a
  #               Zlib constant like Zlib::BEST_COMPRESSION
  #               (defaults to ChunkyPNG default)
  #
  # There are two sizing algorithms.
  #
  # - Original that can result in blurry and hard to scan images
  # - Google's Chart API inspired sizing that resizes the module size to fit within the given image size.
  #
  # The Googleis one will be used when no options are given or when the new size option is used.
  #
  # *Google*
  # size            - Total size of PNG in pixels. The module size is calculated so it fits.
  #                   (defaults to 120)
  # border_modules  - Width of white border around in modules.
  #                   (defaults to 4).
  #
  #  -- DONT USE border_modules OPTION UNLESS YOU KNOW ABOUT THE QUIET ZONE NEEDS OF QR CODES --
  #
  # *Original*
  # module_px_size  - Image size, in pixels.
  # border          - Border thickness, in pixels
  #
  # It first creates an image where 1px = 1 module, then resizes.
  # Defaults to 120x120 pixels, customizable by option.
  #
  # source://rqrcode//lib/rqrcode/export/png.rb#49
  def as_png(options = T.unsafe(nil)); end
end

# source://rqrcode//lib/rqrcode/export/svg.rb#7
module RQRCode::Export::SVG
  # Render the SVG from the Qrcode.
  #
  # Options:
  # offset          - Padding around the QR Code in pixels
  #                   (default 0)
  # fill            - Background color e.g "ffffff"
  #                   (default none)
  # color           - Foreground color e.g "000"
  #                   (default "000")
  # module_size     - The Pixel size of each module
  #                   (defaults 11)
  # shape_rendering - SVG Attribute: auto | optimizeSpeed | crispEdges | geometricPrecision
  #                   (defaults crispEdges)
  # standalone      - Whether to make this a full SVG file, or only an svg to embed in other svg
  #                   (default true)
  # use_path        - Use <path> to render SVG rather than <rect> to significantly reduce size
  #                   and quality. This will become the default in future versions.
  #                   (default false)
  # viewbox         - replace `width` and `height` in <svg> with a viewBox, allows CSS scaling
  #                   (default false)
  # svg_attributes  - A optional hash of custom <svg> attributes. Existing attributes will remain.
  #                   (default {})
  #
  # source://rqrcode//lib/rqrcode/export/svg.rb#158
  def as_svg(options = T.unsafe(nil)); end
end

# source://rqrcode//lib/rqrcode/export/svg.rb#8
class RQRCode::Export::SVG::BaseOutputSVG
  # @return [BaseOutputSVG] a new instance of BaseOutputSVG
  #
  # source://rqrcode//lib/rqrcode/export/svg.rb#11
  def initialize(qrcode); end

  # Returns the value of attribute result.
  #
  # source://rqrcode//lib/rqrcode/export/svg.rb#9
  def result; end
end

# source://rqrcode//lib/rqrcode/export/svg.rb#118
RQRCode::Export::SVG::DEFAULT_SVG_ATTRIBUTES = T.let(T.unsafe(nil), Array)

# source://rqrcode//lib/rqrcode/export/svg.rb#100
class RQRCode::Export::SVG::Edge < ::Struct
  # source://rqrcode//lib/rqrcode/export/svg.rb#101
  def end_x; end

  # source://rqrcode//lib/rqrcode/export/svg.rb#109
  def end_y; end
end

# source://rqrcode//lib/rqrcode/export/svg.rb#17
class RQRCode::Export::SVG::Path < ::RQRCode::Export::SVG::BaseOutputSVG
  # source://rqrcode//lib/rqrcode/export/svg.rb#18
  def build(module_size, offset, color); end
end

# source://rqrcode//lib/rqrcode/export/svg.rb#83
class RQRCode::Export::SVG::Rect < ::RQRCode::Export::SVG::BaseOutputSVG
  # source://rqrcode//lib/rqrcode/export/svg.rb#84
  def build(module_size, offset, color); end
end

# source://rqrcode//lib/rqrcode/export/svg.rb#125
RQRCode::Export::SVG::SVG_PATH_COMMANDS = T.let(T.unsafe(nil), Hash)

# source://rqrcode//lib/rqrcode/qrcode/qrcode.rb#6
class RQRCode::QRCode
  include ::RQRCode::Export::ANSI
  include ::RQRCode::Export::HTML
  include ::RQRCode::Export::PNG
  include ::RQRCode::Export::SVG
  extend ::Forwardable

  # @return [QRCode] a new instance of QRCode
  #
  # source://rqrcode//lib/rqrcode/qrcode/qrcode.rb#13
  def initialize(string, *args); end

  # source://forwardable/1.3.3/forwardable.rb#231
  def modules(*args, **_arg1, &block); end

  # Returns the value of attribute qrcode.
  #
  # source://rqrcode//lib/rqrcode/qrcode/qrcode.rb#11
  def qrcode; end

  # source://forwardable/1.3.3/forwardable.rb#231
  def to_s(*args, **_arg1, &block); end
end

# source://rqrcode//lib/rqrcode/version.rb#4
RQRCode::VERSION = T.let(T.unsafe(nil), String)