#!/usr/bin/env ruby
# frozen_string_literal: true

# Builds the homepage Markdown that spanify reads. src/index.md holds the prose
# and the page's layout; the lists live in YAML under src/home/:
#
#   <!-- SECTION gigs -->   is replaced by src/home/gigs.yaml, rendered
#   <!-- ESSAYS -->         is replaced by every published article, newest first
#
# Everything is generated as Markdown, not HTML, and runs before spanify, so
# generated words get wrapped in spans and fade in like every other word.
#
# Article selection mirrors tool/htmlgen.dart exactly: a file in the markdown
# directory is listed only if it has front matter, `publish: true`, and a
# `created` date. Slugs use the same rules as htmlgen's _sanitizeFilename, so
# every link lands on a page htmlgen actually builds.

require 'date'
require 'time'
require 'yaml'

ROOT = File.expand_path('..', __dir__)
SOURCE_PATH = File.join(ROOT, 'src', 'index.md')
OUTPUT_PATH = File.join(ROOT, 'src', '.index.generated.md')
HTMLGEN_CONFIG = File.join(ROOT, 'htmlgen.toml')
ESSAYS_MARKER = '<!-- ESSAYS -->'
SECTIONS_DIR = File.join(ROOT, 'src', 'home')
SECTION_MARKER = /<!-- SECTION ([a-z0-9_-]+) -->/
SECTION_FIELDS = %w[title level intro items].freeze
ITEM_FIELDS = %w[text url note children].freeze
SITE_TEXT_URL = 'https://banerjeerishi.com/text/'
FRONT_MATTER_LINE = /^\s*-{3,}\s*$/


def markdown_directory
  config = File.read(HTMLGEN_CONFIG)
  dir = config[/^\s*markdown_directory\s*=\s*['"]([^'"]+)['"]/, 1]
  raise "markdown_directory not found in #{HTMLGEN_CONFIG}" unless dir

  File.expand_path(dir, ROOT)
end


# Same as _sanitizeFilename in tool/htmlgen.dart.
def slugify(text)
  slug = text.downcase
             .gsub(/['’]/, '')
             .gsub(/[^a-z0-9]+/, '-')
             .gsub(/-{2,}/, '-')
             .gsub(/\A-+|-+\z/, '')
  return 'untitled' if slug.empty?

  slug[0, 255]
end


def front_matter(path)
  lines = File.readlines(path, encoding: 'utf-8')
  return nil unless lines.first&.match?(FRONT_MATTER_LINE)

  close = lines[1..].index { |line| line.match?(FRONT_MATTER_LINE) }
  return nil unless close

  YAML.safe_load(lines[1, close].join, permitted_classes: [Date, Time]) || {}
end


def to_time(value)
  case value
  when Time then value
  when Date then value.to_time
  else Time.parse(value.to_s)
  end
end


# Keeps a title from being read as Markdown syntax.
def escape_markdown(text)
  text.gsub(/([\\\[\]*_`])/) { "\\#{Regexp.last_match(1)}" }
end


def published_essays
  essays = Dir.glob(File.join(markdown_directory, '*.md')).filter_map do |path|
    fm = front_matter(path)
    next unless fm && fm['publish'] == true && fm['created']

    basename = File.basename(path, '.md')
    slug = slugify(basename)
    # Index.md becomes /text/index.html, the archive page itself.
    next if slug == 'index'

    { title: (fm['title'] || basename).to_s, slug: slug, created: to_time(fm['created']) }
  end

  # Newest first; several articles share a date, so break ties by title.
  essays.sort_by { |e| [-e[:created].to_i, e[:title].downcase] }
end


def essays_markdown(essays)
  essays.map { |e| "* [#{escape_markdown(e[:title])}](#{SITE_TEXT_URL}#{e[:slug]}.html)" }
        .join("\n")
end


# One list item, and its children one level in. A `text` with a `url` becomes
# a link; `note` is Markdown written after it exactly as given, so it can
# carry its own separator ("- Founding Engineer") or links of its own.
def render_item(item, where, depth = 0)
  unknown = item.keys - ITEM_FIELDS
  warn "#{where}: unknown field(s) #{unknown.join(', ')}" unless unknown.empty?
  raise "#{where}: every item needs `text`" if item['text'].to_s.strip.empty?

  head = item['url'] ? "[#{item['text']}](#{item['url']})" : item['text'].to_s
  line = "#{'  ' * depth}#{depth.zero? ? '*' : '-'} #{head}"
  line += " #{item['note']}" unless item['note'].to_s.strip.empty?

  children = (item['children'] || []).each_with_index.map do |child, i|
    render_item(child, "#{where} > child ##{i + 1}", depth + 1)
  end
  [line, *children].join("\n")
end


def render_section(name)
  path = File.join(SECTIONS_DIR, "#{name}.yaml")
  raise "index.md asks for section '#{name}' but #{path} does not exist" unless File.exist?(path)

  data = YAML.safe_load(File.read(path, encoding: 'utf-8')) || {}
  unknown = data.keys - SECTION_FIELDS
  warn "#{name}.yaml: unknown field(s) #{unknown.join(', ')}" unless unknown.empty?
  raise "#{name}.yaml: needs a `title`" if data['title'].to_s.strip.empty?

  parts = ["#{'#' * (data['level'] || 2)} #{data['title']}"]
  parts << data['intro'].to_s.strip unless data['intro'].to_s.strip.empty?
  items = (data['items'] || []).each_with_index.map do |item, i|
    render_item(item, "#{name}.yaml item ##{i + 1} (#{item['text']})")
  end
  parts << items.join("\n") unless items.empty?
  parts.join("\n\n")
end


source = File.read(SOURCE_PATH, encoding: 'utf-8')
unless source.include?(ESSAYS_MARKER)
  raise "#{SOURCE_PATH} has no #{ESSAYS_MARKER} marker to fill in"
end

used = source.scan(SECTION_MARKER).flatten
available = Dir.glob(File.join(SECTIONS_DIR, '*.yaml')).map { |f| File.basename(f, '.yaml') }
(available - used).each { |name| warn "src/home/#{name}.yaml exists but index.md never places it" }

essays = published_essays
output = source.gsub(SECTION_MARKER) { render_section(Regexp.last_match(1)) }
               .sub(ESSAYS_MARKER) { essays_markdown(essays) }
# Only touch the file when it changes. tool/dev_server.rb rebuilds on mtime
# changes, so rewriting identical content every build would loop forever.
if File.exist?(OUTPUT_PATH) && File.read(OUTPUT_PATH, encoding: 'utf-8') == output
  puts "unchanged #{OUTPUT_PATH} (#{used.size} sections, #{essays.size} essays)"
else
  File.write(OUTPUT_PATH, output)
  puts "written #{OUTPUT_PATH} (#{used.size} sections, #{essays.size} essays)"
end
