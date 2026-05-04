#!/usr/bin/env ruby
# frozen_string_literal: true

require 'time'
require 'fileutils'

ROOT = File.expand_path('..', __dir__)
MARKDOWN_DIR = File.join(ROOT, 'markdowns')
SITEMAP_OUT = File.join(ROOT, 'sitemap.xml')
SITE_PREFIX = 'https://banerjeerishi.com/text'


def slugify(text)
  slug = text.downcase
             .gsub(/[\'’]/, '')
             .gsub(/[^a-z0-9]+/, '-')
             .gsub(/-+/, '-')
             .gsub(/\A-|\-\z/, '')
  slug.empty? ? 'untitled' : slug
end


def parse_frontmatter_created(path)
  lines = File.readlines(path, encoding: 'utf-8')
  return nil if lines.empty? || lines[0].strip != '---'

  created_value = nil
  lines[1..].each do |line|
    break if line.strip == '---'
    if (m = line.match(/^\s*created\s*:\s*(.+)$/i))
      created_value = m[1].strip.gsub(/\A['\"]|['\"]\z/, '')
      break
    end
  end

  return nil if created_value.nil? || created_value.empty?

  begin
    Time.parse(created_value).utc
  rescue StandardError
    nil
  end
end


def file_lastmod(path)
  File.mtime(path).utc
end


def build_entries
  entries = []
  Dir.children(MARKDOWN_DIR).sort.each do |name|
    path = File.join(MARKDOWN_DIR, name)
    next unless File.file?(path) && File.extname(path).downcase == '.md'

    slug = slugify(File.basename(name, '.md'))
    created = parse_frontmatter_created(path) || file_lastmod(path)
    entries << [created, slug]
  end
  entries
end


def backup_sitemap(path)
  return unless File.exist?(path)

  ts = Time.now.utc.strftime('%Y%m%dT%H%M%SZ')
  bak = "#{path}.bak.#{ts}"
  FileUtils.cp(path, bak)
  puts "Backed up existing sitemap to #{bak}"
end


def write_sitemap(entries)
  backup_sitemap(SITEMAP_OUT)

  entries_sorted = entries.sort_by { |entry| -entry[0].to_i }
  lines = []
  lines << '<?xml version="1.0" encoding="UTF-8"?>'
  lines << '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
  lines << '  <url>'
  lines << '    <loc>https://banerjeerishi.com/</loc>'
  lines << "    <lastmod>#{Time.now.utc.strftime('%Y-%m-%d')}</lastmod>"
  lines << '    <priority>1.00</priority>'
  lines << '  </url>'

  entries_sorted.each do |dt, slug|
    lines << '  <url>'
    lines << "    <loc>#{SITE_PREFIX}/#{slug}.html</loc>"
    lines << "    <lastmod>#{dt.strftime('%Y-%m-%d')}</lastmod>"
    lines << '    <priority>0.80</priority>'
    lines << '  </url>'
  end

  lines << '</urlset>'
  File.write(SITEMAP_OUT, "#{lines.join("\n")}\n")
  puts "Wrote sitemap to #{SITEMAP_OUT}"
end

unless Dir.exist?(MARKDOWN_DIR)
  warn "Error markdown dir not found: #{MARKDOWN_DIR}"
  exit 2
end

entries = build_entries
puts 'No markdown files found, writing sitemap with only homepage.' if entries.empty?
write_sitemap(entries)
