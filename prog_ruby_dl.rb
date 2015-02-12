#!/usr/bin/ruby1.9.3

require 'mechanize' # = LWP::UserAgent

dir = 'Programming_Ruby'
base_url = "http://ruby-doc.com/docs/ProgrammingRuby/"

Dir.mkdir(dir) unless File.exists? dir
Dir.chdir(dir) or abort "Unable to change to \"#{dir}\" : #{$!}"

agent = Mechanize.new                      # initialize mechanize
page = agent.get(base_url + "pr_toc.html") # get page content

toc_file = File.new( 'index.html', 'w' )   # Create toc file (for calibre)

header = %{                                # Header for index.html
<html>
  <body>
    <h1>Table of Contents</h1>
    <p style="text-indent:0pt">
}
toc_file.puts(header)                      # Print header to index.html

i = 0
page.search('a').each do |a|                               # For each link
  i += 1
  title = a.text.tr(' ','_')                               # replace all spaces by underscores
  filename = i.to_s.rjust(2,'0') + '_' + title + '.html'   # filename = 00_title.html
  output = File.new( filename, 'w' )                       # open/create file
  content = agent.get base_url + a["href"]                 # get content of the linked page
  output.puts(content.body)                                # print it in output file
  output.close                                             # close output file

  # Add link to file in index.html
  toc_line = "<a href='" + filename + "'>" + a.text + "</a>"
  toc_file.puts(toc_line)
end

footer = %{</p></body></html>}             # Print footer to index.html
