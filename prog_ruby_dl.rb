#!/usr/bin/ruby1.9.3

# = LWP::UserAgent
require 'mechanize'

# Output directory
dir = 'Programming_Ruby'
# Base URL
base_url = "http://ruby-doc.com/docs/ProgrammingRuby/"

# Make dir and change into it
Dir.mkdir(dir) unless File.exists? dir
Dir.chdir(dir) or abort "Unable to change to \"#{dir}\" : #{$!}"

# initialize mechanize
agent = Mechanize.new
# get page content
page = agent.get(base_url + "pr_toc.html")

# open file 'index.html', write page content and close file
toc_file = File.new( 'index.html', 'w' )

header = %{<html><body><h1>Table of Contents</h1><p style="text-indent:0pt">}
toc_file.puts(header)

i = 0
# for each link
page.search('a').each do |a|
  i += 1
  # replace all spaces by underscores
  title = a.text.tr(' ','_')
  # filename = 00_title.html
  filename = i.to_s.rjust(2,'0') + '_' + title + '.html'
  # open/create file
  output = File.new( filename, 'w' )
  # get content of the linked page
  content = agent.get base_url + a["href"]
  # print it in output file
  output.puts(content.body)
  # close output file
  output.close

  toc_line = "<a href='" + filename + "'>" + a.text + "</a>"
  toc_file.puts(toc_line)
end

footer = %{</p></body></html>}
