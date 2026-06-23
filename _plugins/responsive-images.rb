# frozen_string_literal: true

require 'cgi'

module Jekyll
  module ResponsiveImages
    IMAGE_TAG = /<img\b[^>]*>/i
    LOCAL_IMAGE = /\.(?:jpe?g|png|gif|webp)$/i
    RESPONSIVE_WIDTHS = [640, 960, 1280, 1600].freeze
    RESPONSIVE_FORMATS = {
      'avif' => 'image/avif',
      'webp' => 'image/webp'
    }.freeze
    DEFAULT_SIZES = '(min-width: 48rem) 66vw, 100vw'

    module_function

    def optimize_output(site, output)
      return output unless output&.include?('<img')

      output.gsub(IMAGE_TAG) do |tag|
        optimize_tag(site, tag)
      end
    end

    def optimize_tag(site, tag)
      src = attr(tag, 'src')
      return tag if src.nil? || src.empty?
      return tag unless local_image?(src)

      image_path = source_path(site, src)
      dimensions = image_dimensions(image_path)
      optimized = add_image_attributes(tag, dimensions)
      picture_sources = responsive_sources(site, src)

      return optimized if picture_sources.empty? || tag.include?('<picture')

      %(<picture>#{picture_sources.join}#{optimized}</picture>)
    end

    def add_image_attributes(tag, dimensions)
      additions = {}
      additions['loading'] = 'lazy' unless has_attr?(tag, 'loading')
      additions['decoding'] = 'async' unless has_attr?(tag, 'decoding')

      if dimensions
        width, height = dimensions
        additions['width'] = width.to_s unless has_attr?(tag, 'width')
        additions['height'] = height.to_s unless has_attr?(tag, 'height')
      end

      return tag if additions.empty?

      insert = additions.map { |key, value| %( #{key}="#{value}") }.join
      tag.sub(%r{\s*/?>\z}) { |ending| "#{insert}#{ending}" }
    end

    def attr(tag, name)
      match = tag.match(/\s#{Regexp.escape(name)}=(["'])(.*?)\1/i)
      match && match[2]
    end

    def has_attr?(tag, name)
      tag.match?(/\s#{Regexp.escape(name)}(?:=|\s|\/?>)/i)
    end

    def local_image?(src)
      return false if src.start_with?('http://', 'https://', '//', 'data:', 'mailto:')

      src.split(/[?#]/, 2).first.match?(LOCAL_IMAGE)
    end

    def source_path(site, src)
      path = src.split(/[?#]/, 2).first
      path = CGI.unescape(path)
      path = path.delete_prefix(site.baseurl.to_s) unless site.baseurl.to_s.empty?
      path = path.delete_prefix('/')
      File.join(site.source, path)
    end

    def responsive_sources(site, src)
      RESPONSIVE_FORMATS.filter_map do |extension, mime_type|
        srcset = generated_sources(site, src, extension)
        next if srcset.empty?

        %(<source type="#{mime_type}" srcset="#{srcset}" sizes="#{DEFAULT_SIZES}">)
      end
    end

    def generated_sources(site, src, extension)
      return [] unless src.match?(/\.(?:jpe?g|png)$/i)

      path = src.split(/[?#]/, 2).first
      path = CGI.unescape(path)
      path = path.delete_prefix(site.baseurl.to_s) unless site.baseurl.to_s.empty?
      path = path.delete_prefix('/')
      return [] unless path.start_with?('assets/')

      dir = File.dirname(path.delete_prefix('assets/'))
      basename = File.basename(path, '.*')
      candidates = RESPONSIVE_WIDTHS.filter_map do |width|
        rel = generated_image_path(dir, basename, width, extension)
        abs = File.join(site.source, rel)
        next unless File.file?(abs)

        "/#{rel} #{width}w"
      end

      candidates.join(', ')
    end

    def generated_image_path(dir, basename, width, extension)
      generated_dir = dir == '.' ? 'assets/generated' : File.join('assets/generated', dir)
      File.join(generated_dir, "#{basename}-#{width}.#{extension}").tr('\\', '/')
    end

    def image_dimensions(path)
      return nil unless path && File.file?(path)

      File.open(path, 'rb') do |file|
        header = file.read(32)
        return png_dimensions(header) if header&.start_with?("\x89PNG\r\n\x1A\n".b)
        return gif_dimensions(header) if header&.start_with?('GIF87a', 'GIF89a')
        return webp_dimensions(file, header) if header&.start_with?('RIFF') && header[8, 4] == 'WEBP'

        jpeg_dimensions(file, header) if header&.byteslice(0, 2) == "\xFF\xD8".b
      end
    rescue StandardError => e
      Jekyll.logger.debug 'ResponsiveImages:', "Cannot read #{path}: #{e.message}"
      nil
    end

    def png_dimensions(header)
      return nil unless header && header.bytesize >= 24

      [header.byteslice(16, 4).unpack1('N'), header.byteslice(20, 4).unpack1('N')]
    end

    def gif_dimensions(header)
      return nil unless header && header.bytesize >= 10

      [header.byteslice(6, 2).unpack1('v'), header.byteslice(8, 2).unpack1('v')]
    end

    def jpeg_dimensions(file, header)
      file.rewind
      file.read(2)

      until file.eof?
        marker_start = file.read(1)
        next unless marker_start == "\xFF".b

        marker = file.read(1)&.ord
        next if marker.nil? || marker == 0xFF
        return nil if marker == 0xD9 || marker == 0xDA

        length = file.read(2)&.unpack1('n')
        return nil if length.nil? || length < 2

        if jpeg_sof_marker?(marker)
          file.read(1)
          height = file.read(2).unpack1('n')
          width = file.read(2).unpack1('n')
          return [width, height]
        end

        file.seek(length - 2, IO::SEEK_CUR)
      end

      nil
    end

    def jpeg_sof_marker?(marker)
      [
        0xC0, 0xC1, 0xC2, 0xC3,
        0xC5, 0xC6, 0xC7,
        0xC9, 0xCA, 0xCB,
        0xCD, 0xCE, 0xCF
      ].include?(marker)
    end

    def webp_dimensions(file, header)
      chunk = header.byteslice(12, 4)

      case chunk
      when 'VP8X'
        data = header.bytesize >= 30 ? header : header + file.read(30 - header.bytesize)
        width = webp_24_bit_dimension(data.byteslice(24, 3))
        height = webp_24_bit_dimension(data.byteslice(27, 3))
        [width, height]
      when 'VP8L'
        file.seek(20, IO::SEEK_SET)
        bytes = file.read(5)&.bytes
        return nil unless bytes&.size == 5 && bytes[0] == 0x2F

        width = 1 + bytes[1] + ((bytes[2] & 0x3F) << 8)
        height = 1 + ((bytes[2] & 0xC0) >> 6) + (bytes[3] << 2) + ((bytes[4] & 0x0F) << 10)
        [width, height]
      when 'VP8 '
        file.seek(26, IO::SEEK_SET)
        width = file.read(2)&.unpack1('v')
        height = file.read(2)&.unpack1('v')
        width && height ? [width & 0x3FFF, height & 0x3FFF] : nil
      end
    end

    def webp_24_bit_dimension(bytes)
      a, b, c = bytes.unpack('C3')
      1 + a + (b << 8) + (c << 16)
    end
  end
end

Jekyll::Hooks.register [:pages, :documents], :post_render do |item|
  next unless item.output_ext == '.html'

  item.output = Jekyll::ResponsiveImages.optimize_output(item.site, item.output)
end
