# frozen_string_literal: true

# Usage:
#   rake images:responsive
#   rake images:responsive DRY_RUN=1
#   rake images:responsive MIN_BYTES=300KB
#   rake images:responsive WIDTHS=640,960,1280,1600
#   rake images:responsive FORMATS=avif,webp
#   rake images:responsive FORCE=1
#   rake test
#
# Prefer `bundle exec rake images:responsive` when running through Bundler.

require 'fileutils'
require 'open3'
require 'pathname'

ROOT = Pathname.new(__dir__)
CONTENT_DIRS = %w[_posts pages _drafts].freeze
IMAGE_ROOT = 'assets'
GENERATED_ROOT = 'assets/generated'
IMAGE_EXTENSIONS = %w[.jpg .jpeg .png].freeze
DEFAULT_WIDTHS = [640, 960, 1280].freeze
DEFAULT_FORMATS = %w[avif webp].freeze

def env_list(name, default)
  value = ENV[name]
  return default if value.nil? || value.strip.empty?

  value.split(',').map(&:strip).reject(&:empty?)
end

def parse_size(value)
  match = value.to_s.strip.match(/\A(\d+(?:\.\d+)?)([kmgt]?b?)?\z/i)
  raise ArgumentError, "Invalid size: #{value.inspect}" unless match

  amount = match[1].to_f
  unit = match[2].to_s.downcase
  multiplier = case unit
               when '', 'b' then 1
               when 'k', 'kb' then 1024
               when 'm', 'mb' then 1024 * 1024
               when 'g', 'gb' then 1024 * 1024 * 1024
               when 't', 'tb' then 1024 * 1024 * 1024 * 1024
               else raise ArgumentError, "Invalid size unit: #{unit.inspect}"
               end

  (amount * multiplier).to_i
end

def executable(name)
  return ENV[name.upcase] if ENV[name.upcase] && File.executable?(ENV[name.upcase])

  extensions = ENV.fetch('PATHEXT', '').split(';')
  extensions = [''] if extensions.empty?
  ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).each do |dir|
    extensions.each do |extension|
      path = File.join(dir, "#{name}#{extension}")
      return path if File.executable?(path)
    end
  end

  nil
end

def relative_path(path)
  Pathname.new(path).relative_path_from(ROOT).to_s.tr('\\', '/')
end

def content_index
  CONTENT_DIRS.filter_map { |dir| ROOT.join(dir) if ROOT.join(dir).directory? }
              .flat_map { |dir| Dir.glob(dir.join('**/*.{md,html}').to_s) }
              .map { |path| File.binread(path).force_encoding('UTF-8').scrub }
              .join("\n")
end

def referenced_images(min_bytes:)
  content = content_index
  images = Dir.glob(ROOT.join(IMAGE_ROOT, '**', '*').to_s).select do |path|
    File.file?(path) &&
      IMAGE_EXTENSIONS.include?(File.extname(path).downcase) &&
      relative_path(path).start_with?("#{IMAGE_ROOT}/") &&
      !relative_path(path).start_with?("#{GENERATED_ROOT}/") &&
      File.size(path) >= min_bytes
  end

  images.filter_map do |path|
    rel = relative_path(path)
    next unless content.include?(rel) || content.include?("/#{rel}")

    { path: path, rel: rel, bytes: File.size(path) }
  end.sort_by { |item| -item[:bytes] }
end

def image_dimensions(path, ffprobe)
  output, status = Open3.capture2e(
    ffprobe,
    '-v', 'error',
    '-select_streams', 'v:0',
    '-show_entries', 'stream=width,height',
    '-of', 'csv=s=x:p=0',
    path
  )
  return nil unless status.success?

  width, height = output.lines.first.to_s.strip.split('x').map(&:to_i)
  width&.positive? && height&.positive? ? [width, height] : nil
end

def generated_path(source_rel, width, format)
  asset_rel = source_rel.delete_prefix("#{IMAGE_ROOT}/")
  dir = File.dirname(asset_rel)
  basename = File.basename(asset_rel, '.*')
  generated_dir = dir == '.' ? GENERATED_ROOT : File.join(GENERATED_ROOT, dir)

  ROOT.join(generated_dir, "#{basename}-#{width}.#{format}").to_s
end

def ffmpeg_args(source, dest, width, format)
  common = ['-y', '-hide_banner', '-loglevel', 'error', '-i', source, '-vf', "scale=#{width}:-2", '-frames:v', '1']

  case format
  when 'avif'
    crf = File.extname(source).downcase == '.png' ? ENV.fetch('PNG_AVIF_CRF', '30') : ENV.fetch('AVIF_CRF', '34')
    common + ['-c:v', 'libaom-av1', '-still-picture', '1', '-crf', crf, '-cpu-used', ENV.fetch('AVIF_CPU_USED', '8'), dest]
  when 'webp'
    quality = File.extname(source).downcase == '.png' ? ENV.fetch('PNG_WEBP_QUALITY', '88') : ENV.fetch('WEBP_QUALITY', '82')
    common + ['-c:v', 'libwebp', '-quality', quality, '-compression_level', ENV.fetch('WEBP_COMPRESSION', '6'), dest]
  else
    raise ArgumentError, "Unsupported format: #{format.inspect}"
  end
end

namespace :images do
  desc 'Generate responsive AVIF/WebP variants for referenced large images'
  task :responsive do
    widths = env_list('WIDTHS', DEFAULT_WIDTHS.map(&:to_s)).map(&:to_i).select(&:positive?).uniq.sort
    formats = env_list('FORMATS', DEFAULT_FORMATS).map(&:downcase).uniq
    min_bytes = parse_size(ENV.fetch('MIN_BYTES', '200KB'))
    force = ENV['FORCE'] == '1'
    dry_run = ENV['DRY_RUN'] == '1'
    limit = ENV.fetch('LIMIT', '0').to_i

    abort 'No widths configured' if widths.empty?
    abort 'No formats configured' if formats.empty?

    ffmpeg = executable('ffmpeg') || abort('ffmpeg was not found. Set FFMPEG=/path/to/ffmpeg.')
    ffprobe = executable('ffprobe') || abort('ffprobe was not found. Set FFPROBE=/path/to/ffprobe.')

    targets = referenced_images(min_bytes: min_bytes)
    targets = targets.first(limit) if limit.positive?

    puts "formats=#{formats.join(',')}"
    puts "widths=#{widths.join(',')}"
    puts "min_bytes=#{min_bytes}"
    puts "targets=#{targets.length}"
    puts 'dry_run=1' if dry_run

    generated = 0
    skipped = 0
    failed = 0

    targets.each do |item|
      dimensions = image_dimensions(item[:path], ffprobe)
      unless dimensions
        warn "skip probe_failed #{item[:rel]}"
        failed += 1
        next
      end

      source_width = dimensions.first
      widths.each do |width|
        next if source_width <= width

        formats.each do |format|
          dest = generated_path(item[:rel], width, format)
          dest_rel = relative_path(dest)

          if !force && File.exist?(dest) && File.mtime(dest) >= File.mtime(item[:path])
            puts "skip existing #{dest_rel}"
            skipped += 1
            next
          end

          puts "#{dry_run ? 'would generate' : 'generate'} #{dest_rel}"
          next if dry_run

          FileUtils.mkdir_p(File.dirname(dest))
          if system(ffmpeg, *ffmpeg_args(item[:path], dest, width, format))
            generated += 1
          else
            failed += 1
            warn "failed #{dest_rel}"
          end
        end
      end
    end

    puts "generated=#{generated}"
    puts "skipped=#{skipped}"
    puts "failed=#{failed}"
    abort 'image generation failed' if failed.positive?
  end
end

namespace :verify do
  desc 'Run fixture checks for responsive images and image generation helpers'
  task :fixtures do
    ruby '_tests/responsive_images_test.rb'
    ruby '_tests/rakefile_test.rb'
  end
end

desc 'Run project checks'
task test: 'verify:fixtures'
