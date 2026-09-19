#!/usr/bin/env ruby
# frozen_string_literal: true

# Renders src/books/shelf.yaml into a single interactive page at
# web/books/shelf.html. The book data is baked into the page as JSON, so the
# page makes no requests of its own.

require 'date'
require 'json'
require 'uri'
require 'yaml'

ROOT = File.expand_path('..', __dir__)
SRC_DIR = File.join(ROOT, 'src', 'books')
OUT_DIR = File.join(ROOT, 'web', 'books')
SHELF_DATA_PATH = File.join(SRC_DIR, 'shelf.yaml')
SHELF_TEMPLATE_PATH = File.join(SRC_DIR, 'shelf.template.html')

# The same footer the article pages use, so the two stay in sync.
FOOTER_PATH = File.join(ROOT, 'src', 'text', 'page_footer.md')

BOOK_FIELDS = %w[title author status progress_percent progress_note category
                 favourite started_at finished_at rating notes amazon].freeze
VALID_STATUSES = %w[finished reading paused want].freeze

# Amazon's Indian store, since that's where the books actually get bought.
AMAZON_SEARCH = 'https://www.amazon.in/s?k='

# JSON-escaped '<', so no `</script>` in the data can close the tag early.
ESCAPED_LT = '\\u003c'


# Books without a hand-picked product URL get a search link. Search beats a
# guessed ASIN: it never rots, and it copes with editions and reprints.
def amazon_url(book)
  return book['amazon'] if book['amazon']

  query = "#{book['title']} #{book['author']}".gsub(/[^\p{Alnum}\s]/, ' ').split.join(' ')
  AMAZON_SEARCH + URI.encode_www_form_component(query)
end


# A deliberately small Markdown pass: enough for the footer file, which is a
# raw <img> tag plus a few paragraphs of links and bold text.
def render_footer
  html = []
  File.read(FOOTER_PATH).split(/\n{2,}/).each do |block|
    block = block.strip
    next if block.empty?

    if block.start_with?('<')
      html << block
      next
    end

    text = block.gsub('&', '&amp;')
    text = text.gsub(/\*\*(.+?)\*\*/, '<strong>\\1</strong>')
    text = text.gsub(/\[(.+?)\]\((.+?)\)/, '<a href="\\2">\\1</a>')
    html << "<p>#{text}</p>"
  end
  html.join("\n        ")
end


def validate!(book, where)
  unknown = book.keys - BOOK_FIELDS
  warn "#{where}: unknown field(s) #{unknown.join(', ')}" unless unknown.empty?

  %w[title author status].each do |field|
    raise "#{where}: missing required field '#{field}'" if book[field].to_s.strip.empty?
  end

  unless VALID_STATUSES.include?(book['status'])
    raise "#{where}: status '#{book['status']}' is not one of #{VALID_STATUSES.join('/')}"
  end

  pct = book['progress_percent']
  unless pct.nil? || (pct.is_a?(Integer) && pct.between?(0, 100))
    raise "#{where}: progress_percent must be an integer 0-100, or left out entirely"
  end

  rating = book['rating']
  unless rating.nil? || (rating.is_a?(Integer) && rating.between?(1, 5))
    raise "#{where}: rating must be an integer 1-5, or left out entirely"
  end
end


# Reads shelf.yaml, validates it, and returns the books as JSON safe to embed
# inside a <script type="application/json"> tag.
def shelf_books
  data = YAML.safe_load(File.read(SHELF_DATA_PATH), permitted_classes: [Date])
  books = data['books'] || []

  books.each_with_index do |book, i|
    validate!(book, "shelf.yaml entry ##{i + 1} (#{book['title'] || 'untitled'})")

    # Dates come back as Date objects; JSON should carry plain strings.
    %w[started_at finished_at].each do |field|
      book[field] = book[field].to_s unless book[field].nil?
    end

    book['amazon'] = amazon_url(book)
  end

  books
end


def write_shelf_page
  Dir.mkdir(OUT_DIR) unless Dir.exist?(OUT_DIR)

  books = shelf_books
  # A literal `</script>` in the data would close the tag early.
  json = JSON.generate(books).gsub('<') { ESCAPED_LT }

  footer = render_footer
  output = File.read(SHELF_TEMPLATE_PATH)
               .sub('GENERATED_JSON') { json }
               .sub('<!-- GENERATED_FOOTER -->') { footer }
  out_path = File.join(OUT_DIR, 'shelf.html')
  File.write(out_path, output)
  puts "written #{out_path} (#{books.size} books)"
end


write_shelf_page
