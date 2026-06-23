# frozen_string_literal: true

require 'minitest/autorun'
require 'rake'

load File.expand_path('../Rakefile', __dir__)

class RakefileTest < Minitest::Test
  def test_parse_size
    assert_equal 42, parse_size('42')
    assert_equal 204_800, parse_size('200KB')
    assert_equal 1_572_864, parse_size('1.5MB')
  end

  def test_generated_path_preserves_asset_subdirectory
    path = generated_path('assets/posts/photo.jpg', 640, 'webp').tr('\\', '/')

    assert_match %r{/assets/generated/posts/photo-640\.webp\z}, path
  end

  def test_ffmpeg_args_for_webp
    args = ffmpeg_args('assets/photo.jpg', 'assets/generated/photo-640.webp', 640, 'webp')

    assert_includes args, '-vf'
    assert_includes args, 'scale=640:-2'
    assert_includes args, 'libwebp'
    assert_equal 'assets/generated/photo-640.webp', args.last
  end

  def test_ffmpeg_args_for_avif
    args = ffmpeg_args('assets/photo.png', 'assets/generated/photo-640.avif', 640, 'avif')

    assert_includes args, 'libaom-av1'
    assert_includes args, '-still-picture'
    assert_equal 'assets/generated/photo-640.avif', args.last
  end

  def test_images_responsive_task_is_registered
    assert Rake::Task.task_defined?('images:responsive')
    assert Rake::Task.task_defined?('verify:fixtures')
    assert Rake::Task.task_defined?('test')
  end
end
