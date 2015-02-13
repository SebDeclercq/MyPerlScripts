#!/usr/bin/ruby1.9.3

require 'mechanize' # = LWP::UserAgent
require 'zip'

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
  next if a.text =~ /content/i                             # Except ToC
  i += 1
  title = a.text.tr(' ','_')                               # replace all spaces by underscores
  filename = i.to_s.rjust(2,'0') + '_' + title + '.html'   # filename = 00_title.html
  output = File.new( filename, 'w' )                       # open/create file
  content = agent.get base_url + a["href"]                 # get content of the linked page
  output.puts(content.body)                                # print it in output file
  output.close                                             # close output file

  # Add link to file in index.html
  toc_line = "      <a href='" + filename + "'>" + a.text + "</a><br/>"
  toc_file.puts(toc_line)
end

footer = %{           # Print footer to index.html
    </p>
  </body>
</html>}

# Download cover
cover = agent.get("https://imagery.pragprog.com/products/49/ruby.jpg")
png = File.new('cover.png','w')
png.puts cover.body
png.close

files = Dir.glob("*")           # List of files for creating zip
zip = '../Programming_Ruby.zip'            

if File.exists? zip                                    # If file exists
  print "Delete previous generated zipfile ? (y|n)\t"
  answer = gets.chomp                                  # Remove it
  if answer =~ /y| /
    File.delete(zip)
    puts "Creating new zip file now..."
  else
    abort "Bye, then !"                                # Or abort
  end
end


Zip::File.open(zip, Zip::File::CREATE) do |zipfile| # Create zip file
  files.each do |f|                                 # For each downloaded file
    zipfile.add(f,f)                                # Add it to zip
  end
end

# Trying to exec Calibre conversion but ???
# Dir.chdir('..')
# exec( "ebook-convert #{dir}.zip #{dir}.azw3 --cover #{dir}/cover.png" )
