# frozen_string_literal: true

require "json"
require "uri"
require_relative "site"

# The hover cards: what each link on the homepage shows when you rest on it.
# Cards are keyed by path for links on this site, so they match whether an
# href is absolute (production) or made relative by the dev server, and by
# full URL for everywhere else.
class LinkPreviews
  LABELS = { "medium.com": "Medium", "open.spotify.com": "Spotify", "github.com": "GitHub",
             "youtube.com": "YouTube", "www.youtube.com": "YouTube" }.freeze

  # Written by tool/covers.rb and only read here, so builds stay offline.
  COVERS  = Site.path("src/home/covers.json")
  SPOTIFY = %r{https://open\.spotify\.com/(artist|album|track|playlist)/(\w+)[^)\s"]*}

  def initialize(essay_count:)
    @essay_count = essay_count
    @cards = {}
    @written = {}
  end

  # Essays with nothing to quote get no card rather than an empty one.
  def add_essay(article)
    @cards[article.path] = { e: article.opening, m: "#{article.minutes} min read" } if article.opening
  end

  # A `preview` from the YAML sections. It wins over an essay's own opening.
  def add(url, text)
    @written[key(url)] = @cards[key(url)] = { e: text, m: label(url) }
  end

  # A cover card for every Spotify link that has art. Words written in the
  # YAML replace the title.
  def add_covers(markdown)
    covers = COVERS.exist? ? JSON.parse(COVERS.read, symbolize_names: true) : {}

    markdown.enum_for(:scan, SPOTIFY).map { Regexp.last_match }.each do |link|
      url, id = link[0], link[2]
      next unless (cover = covers[id.to_sym])

      @cards[url] = { e: cover[:title], m: "Spotify · #{cover[:kind].capitalize}", i: "/img/covers/#{id}.jpg" }
                    .merge(@written.fetch(url, {}).slice(:e))
    end
  end

  def written_count = @written.size

  # `%{essays}` in any card becomes the live essay count. A literal `</script>`
  # in the data would close the tag early, hence the escaped `<`.
  def to_script
    cards = @cards.transform_values { _1.merge(e: _1[:e].gsub("%{essays}", @essay_count.to_s)) }
    %(<script id="link-previews" type="application/json">#{JSON.generate(cards).gsub("<") { '<' }}</script>)
  end

  private
    def key(url)
      uri = URI.parse(url)
      return url unless uri.host.nil? || Site::HOSTS.include?(uri.host)

      uri.path.empty? ? "/" : uri.path
    rescue URI::InvalidURIError
      url
    end

    def label(url)
      host = URI.parse(url).host
      return "banerjeerishi.com" if host.nil? || Site::HOSTS.include?(host)

      LABELS.fetch(host.to_sym, host.delete_prefix("www."))
    rescue URI::InvalidURIError
      nil
    end
end
