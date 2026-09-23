#!/usr/bin/env ruby
# frozen_string_literal: true

# Builds /games/: compiles each game in src/games/games.yaml from Dart to
# JavaScript and bakes it into web/games/<slug>.html, then writes the index.
# Like every other page here, each game ships as one file.
#
# Compiling is the slow part, so the output is cached in .dart_tool/gamesgen
# under a hash of the game's Dart sources (and the shared ones, and the
# pubspec lock). Editing one game recompiles only that one.

require "digest"
require "fileutils"
require "yaml"
require_relative "lib/site"
require_relative "lib/includes"
require_relative "lib/footer"

FIELDS = %i[slug title note description intro colophon].freeze
CACHE  = Site.path(".dart_tool/gamesgen")

def check(game, where)
  unknown = game.keys - FIELDS
  warn "#{where}: unknown field(s) #{unknown.join(", ")}" if unknown.any?
  FIELDS.each { raise "#{where}: missing '#{_1}'" if game[_1].to_s.strip.empty? }
  raise "#{where}: no src/games/#{game[:slug]}/main.dart" unless Site.path("src/games/#{game[:slug]}/main.dart").file?
end

def compiled(slug)
  sources = (Dir.glob("src/games/{shared,#{slug}}/**/*.dart", base: Site::ROOT).sort + ["pubspec.lock"])
            .map { "#{_1}\n#{Site.path(_1).read}" }
  js = CACHE.join("#{slug}-#{Digest::SHA256.hexdigest(sources.join("\n"))[0, 16]}.js")
  unless js.exist?
    CACHE.mkpath
    CACHE.glob("#{slug}-*").each(&:delete)
    ok = system("dart", "compile", "js", "-O2", "--no-source-maps", "-o", js.to_s,
                "src/games/#{slug}/main.dart", chdir: Site::ROOT, out: File::NULL)
    raise "dart compile js failed for #{slug}" unless ok
  end
  # "</script" can only appear inside a JS string or comment, where "<\/"
  # means the same thing; left alone it would end the inline <script> early.
  js.read.gsub("</script", "<\\/script")
end

def html(text) = text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")

games = YAML.safe_load(Site.path("src/games/games.yaml").read, symbolize_names: true)[:games] || []
games.each_with_index { |game, i| check(game, "games.yaml entry ##{i + 1} (#{game[:slug] || "unnamed"})") }

out = Site.path("web/games")
out.mkpath
template = Includes.expand(Site.path("src/games/game.template.html").read)
footer = Footer.html

games.each do |game|
  page = template.gsub("GAME_TITLE") { html(game[:title]) }
                 .gsub("GAME_SLUG") { game[:slug] }
                 .gsub("GAME_DESCRIPTION") { html(game[:description]) }
                 .sub("GAME_INTRO") { game[:intro].strip }
                 .sub("GAME_COLOPHON") { game[:colophon].strip }
                 .sub("<!-- GENERATED_FOOTER -->") { footer }
                 .sub("GENERATED_JS") { compiled(game[:slug]) }
  file = out.join("#{game[:slug]}.html")
  puts "#{Site.write(file, page) ? "written" : "unchanged"} #{file} (#{page.bytesize / 1024} KB)"
end

list = games.map do |game|
  %(<li><a href="/games/#{game[:slug]}.html">#{html(game[:title])}</a> <span class="note">— #{html(game[:note])}</span></li>)
end.join("\n        ")
index = Includes.expand(Site.path("src/games/index.template.html").read)
                .sub("<!-- GENERATED_GAMES -->") { list }
                .sub("<!-- GENERATED_FOOTER -->") { footer }
file = out.join("index.html")
puts "#{Site.write(file, index) ? "written" : "unchanged"} #{file} (#{games.size} games)"
