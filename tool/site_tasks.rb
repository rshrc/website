#!/usr/bin/env ruby
# frozen_string_literal: true

require 'open3'

ROOT = File.expand_path('..', __dir__)


def run_cmd(*cmd)
  puts "+ #{cmd.join(' ')}"
  system(*cmd, chdir: ROOT) ? 0 : 1
end

def cmd_spanify
  src_tpl = File.join(ROOT, 'src', 'index.template.html')
  src_md = File.join(ROOT, 'src', 'index.md')
  out_file = File.join(ROOT, 'web', 'index.html')

  Dir.mkdir(File.dirname(out_file)) unless Dir.exist?(File.dirname(out_file))

  cmd = ['dart', '--enable-asserts', 'tool/spanify.dart', '--html', src_tpl, src_md]
  puts "+ #{cmd.join(' ')} > #{out_file}"
  File.open(out_file, 'w') do |f|
    success = system(*cmd, chdir: ROOT, out: f)
    return success ? 0 : 1
  end
end

def cmd_htmlgen
  run_cmd('dart', '--enable-asserts', 'tool/htmlgen.dart')
end

def cmd_update_sitemap
  run_cmd('ruby', 'tool/update_sitemap.rb')
end

def cmd_check_sitemap_urls
  run_cmd('ruby', 'tool/check_sitemap_urls.rb', '--sitemap', 'sitemap.xml', '--build-dir', 'build')
end

def cmd_booksgen
  run_cmd('ruby', 'tool/booksgen.rb')
end

commands = {
  'spanify' => method(:cmd_spanify),
  'htmlgen' => method(:cmd_htmlgen),
  'update-sitemap' => method(:cmd_update_sitemap),
  'check-sitemap-urls' => method(:cmd_check_sitemap_urls),
  'booksgen' => method(:cmd_booksgen)
}

command = ARGV[0]
unless commands.key?(command)
  warn "Usage: ruby tool/site_tasks.rb [#{commands.keys.join('|')}]"
  exit 2
end

exit(commands[command].call)
