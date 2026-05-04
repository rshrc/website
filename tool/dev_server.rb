#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'

ROOT = File.expand_path('..', __dir__)
PORT = (ENV['PORT'] || '3002').to_i
WATCH_DIRS = %w[src markdowns tool].freeze
WATCH_FILES = %w[Makefile htmlgen.toml sitemap.xml robots.txt].freeze
IGNORE_PREFIXES = %w[build .git .dart_tool node_modules].freeze


def run_builder
  puts '[watch] rebuilding...'
  ok = system('make', 'builder', chdir: ROOT)
  rewrite_links_for_local_preview if ok
  puts(ok ? '[watch] build ok' : '[watch] build failed')
  ok
end

def rewrite_links_for_local_preview
  Dir.glob(File.join(ROOT, 'build', '**', '*.html')).each do |path|
    content = File.read(path)
    rewritten = content.gsub('https://banerjeerishi.com', '')
    next if rewritten == content

    File.write(path, rewritten)
  end
end


def ignored?(path)
  rel = path.sub(%r{\A#{Regexp.escape(ROOT)}/?}, '')
  IGNORE_PREFIXES.any? { |prefix| rel == prefix || rel.start_with?("#{prefix}/") }
end


def snapshot
  files = []
  WATCH_DIRS.each do |dir|
    base = File.join(ROOT, dir)
    next unless Dir.exist?(base)

    Dir.glob(File.join(base, '**', '*'), File::FNM_DOTMATCH).each do |path|
      next unless File.file?(path)
      next if ignored?(path)
      files << path
    end
  end

  WATCH_FILES.each do |name|
    path = File.join(ROOT, name)
    files << path if File.file?(path)
  end

  sig = files.sort.map { |p| "#{p}:#{File.mtime(p).to_f}" }.join('|')
  Digest::SHA256.hexdigest(sig)
end

run_builder

puts "[watch] starting static server at http://localhost:#{PORT}"
server_pid = spawn('serve', 'build', '-l', PORT.to_s, chdir: ROOT)

shutdown = proc do
  puts "\n[watch] shutting down..."
  begin
    Process.kill('TERM', server_pid)
  rescue StandardError
    nil
  end
  exit 0
end

trap('INT', &shutdown)
trap('TERM', &shutdown)

last = snapshot
loop do
  sleep 1.0
  current = snapshot
  next if current == last

  last = current
  run_builder
end
