#!/usr/bin/env ruby
# frozen_string_literal: true

# Renders src/books/shelf.yaml into web/books/shelf.html. The books are baked
# into the page as JSON, so it makes no requests of its own.

require "date"
require "json"
require "uri"
require "yaml"
require_relative "lib/site"
require_relative "lib/includes"

FIELDS   = %i[title author status progress_percent progress_note category
              favourite started_at finished_at rating notes amazon].freeze
STATUSES = %i[finished reading paused want].freeze

# Amazon's Indian store, since that's where the books get bought. Books
# without a hand-picked link get a search: it never rots, and it copes with
# editions and reprints better than a guessed product page.
AMAZON_SEARCH = "https://www.amazon.in/s?k="

def check(book, where)
  unknown = book.keys - FIELDS
  warn "#{where}: unknown field(s) #{unknown.join(", ")}" if unknown.any?

  %i[title author status].each do |field|
    raise "#{where}: missing required field '#{field}'" if book[field].to_s.strip.empty?
  end
  raise "#{where}: status '#{book[:status]}' is not one of #{STATUSES.join("/")}" unless STATUSES.include?(book[:status]&.to_sym)
  raise "#{where}: progress_percent must be an integer 0-100, or left out entirely" unless within?(book[:progress_percent], 0..100)
  raise "#{where}: rating must be an integer 1-5, or left out entirely" unless within?(book[:rating], 1..5)
end

def within?(value, range) = value.nil? || (value.is_a?(Integer) && range.cover?(value))

def amazon(book)
  book[:amazon] || AMAZON_SEARCH + URI.encode_www_form_component(
    "#{book[:title]} #{book[:author]}".gsub(/[^\p{Alnum}\s]/, " ").split.join(" "))
end

# The footer the article pages use, so the two stay in sync. A deliberately
# small Markdown pass: the file is a raw <img> tag plus a few paragraphs of
# links and bold text.
def footer
  Site.path("src/text/page_footer.md").read.split(/\n{2,}/).map(&:strip).reject(&:empty?).map do |block|
    next block if block.start_with?("<")

    "<p>#{block.gsub("&", "&amp;").gsub(/\*\*(.+?)\*\*/, '<strong>\1</strong>').gsub(/\[(.+?)\]\((.+?)\)/, '<a href="\2">\1</a>')}</p>"
  end.join("\n        ")
end

books = YAML.safe_load(Site.path("src/books/shelf.yaml").read, permitted_classes: [Date], symbolize_names: true)[:books] || []
books.each_with_index do |book, i|
  check(book, "shelf.yaml entry ##{i + 1} (#{book[:title] || "untitled"})")
  # Dates come back from YAML as Date objects; the page wants plain strings.
  %i[started_at finished_at].each { book[_1] = book[_1].to_s unless book[_1].nil? }
  book[:amazon] = amazon(book)
end

page = Includes.expand(Site.path("src/books/shelf.template.html").read)
               .sub("GENERATED_JSON") { JSON.generate(books).gsub("<") { '<' } }
               .sub("<!-- GENERATED_FOOTER -->") { footer }

out = Site.path("web/books/shelf.html")
out.dirname.mkpath
out.write(page)
puts "written #{out} (#{books.size} books)"
