#!/usr/bin/env ruby
# frozen_string_literal: true

ROOT = File.expand_path('..', __dir__)
SRC_DIR = File.join(ROOT, 'src', 'books')
OUT_DIR = File.join(ROOT, 'web', 'books')
TEMPLATE_PATH = File.join(SRC_DIR, 'page.template.html')


def escape_html(text)
  text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
end


def render_inline(markdown)
  out = escape_html(markdown)
  out = out.gsub(/\*\*(.+?)\*\*/, '<strong>\1</strong>')
  out.gsub(/\[(.+?)\]\((.+?)\)/, '<a href="\2">\1</a>')
end


def markdown_to_html(lines)
  html = []
  in_list = false

  lines.each do |line|
    stripped = line.strip

    if stripped.empty?
      if in_list
        html << '</ul>'
        in_list = false
      end
      next
    end

    if (m = stripped.match(/^#\s+(.+)$/))
      html << '<h1>' + render_inline(m[1]) + '</h1>'
      next
    end

    if (m = stripped.match(/^\*\s+(.+)$/))
      unless in_list
        html << '<ul>'
        in_list = true
      end
      html << '<li>' + render_inline(m[1]) + '</li>'
      next
    end

    if in_list
      html << '</ul>'
      in_list = false
    end

    html << '<p>' + render_inline(stripped) + '</p>'
  end

  html << '</ul>' if in_list
  html.join("\n")
end


def page_title(lines, fallback)
  first = lines.find { |line| line.strip.start_with?('# ') }
  return fallback unless first

  first.strip.sub(/^#\s+/, '')
end


template = File.read(TEMPLATE_PATH)
Dir.mkdir(OUT_DIR) unless Dir.exist?(OUT_DIR)

Dir.glob(File.join(SRC_DIR, '*.md')).sort.each do |md_path|
  lines = File.readlines(md_path, encoding: 'utf-8')
  slug = File.basename(md_path, '.md')
  title = page_title(lines, "Favorite Books #{slug}")
  description = "Rishi Banerjee's favorite books from #{slug}."
  canonical = "https://banerjeerishi.com/books/#{slug}.html"

  body_html = markdown_to_html(lines)
  output = template
           .gsub('GENERATED_TITLE', title)
           .gsub('GENERATED_DESCRIPTION', description)
           .gsub('GENERATED_CANONICAL', canonical)
           .gsub('<!-- GENERATED_HTML -->', body_html)

  out_path = File.join(OUT_DIR, "#{slug}.html")
  File.write(out_path, output)
  puts "written #{out_path}"
end
