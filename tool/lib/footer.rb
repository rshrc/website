# frozen_string_literal: true

require_relative "site"

# The footer the article pages use, for the pages generated outside htmlgen
# (the shelf, the games), so they all stay in sync. A deliberately small
# Markdown pass: the file is a raw <img> tag plus a few paragraphs of links
# and bold text.
module Footer
  def self.html
    Site.path("src/text/page_footer.md").read.split(/\n{2,}/).map(&:strip).reject(&:empty?).map do |block|
      next block if block.start_with?("<")

      "<p>#{block.gsub("&", "&amp;").gsub(/\*\*(.+?)\*\*/, '<strong>\1</strong>').gsub(/\[(.+?)\]\((.+?)\)/, '<a href="\2">\1</a>')}</p>"
    end.join("\n        ")
  end
end
