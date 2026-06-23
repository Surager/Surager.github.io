# frozen_string_literal: true

require 'base64'
require 'fileutils'
require 'jekyll'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../_plugins/responsive-images'

class ResponsiveImagesTest < Minitest::Test
  PNG_2X1 = Base64.decode64(
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAADElEQVR42mP8z8AAAAMBAQAY3Y2wAAAAAElFTkSuQmCC'
  )

  Site = Struct.new(:source, :baseurl)

  def test_adds_lazy_dimensions_and_responsive_sources
    Dir.mktmpdir do |source|
      write_file(source, 'assets/photo.png', PNG_2X1)
      write_file(source, 'assets/generated/photo-640.avif', 'avif')
      write_file(source, 'assets/generated/photo-640.webp', 'webp')

      html = '<p><img src="/assets/photo.png" alt="Photo"></p>'
      optimized = Jekyll::ResponsiveImages.optimize_output(Site.new(source, ''), html)

      assert_includes optimized, '<picture>'
      assert_includes optimized, 'type="image/avif"'
      assert_includes optimized, '/assets/generated/photo-640.avif 640w'
      assert_includes optimized, 'type="image/webp"'
      assert_includes optimized, '/assets/generated/photo-640.webp 640w'
      assert_includes optimized, 'loading="lazy"'
      assert_includes optimized, 'decoding="async"'
      assert_includes optimized, 'width="2"'
      assert_includes optimized, 'height="1"'
    end
  end

  def test_skips_remote_images
    html = '<img src="https://example.com/photo.png" alt="Remote">'
    optimized = Jekyll::ResponsiveImages.optimize_output(Site.new(Dir.pwd, ''), html)

    assert_equal html, optimized
  end

  def test_preserves_existing_loading_attribute
    Dir.mktmpdir do |source|
      write_file(source, 'assets/photo.png', PNG_2X1)

      html = '<img src="/assets/photo.png" alt="Photo" loading="eager">'
      optimized = Jekyll::ResponsiveImages.optimize_output(Site.new(source, ''), html)

      assert_includes optimized, 'loading="eager"'
      refute_includes optimized, 'loading="lazy"'
      assert_includes optimized, 'width="2"'
      assert_includes optimized, 'height="1"'
    end
  end

  private

  def write_file(root, relative_path, content)
    path = File.join(root, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, content)
  end
end
