require 'redcloth'

module RedCloth::Formatters::LATEX_EX
  include RedCloth::Formatters::LATEX
  def td(opts)
    puts opts[:text]
    if opts[:text]
      if opts[:text].include? "\n"
        opts[:text] = opts[:text].gsub! "\n", "\\par"
      end
      if opts[:text].include? '&'
        opts[:text] = opts[:text].gsub! '&', '\\\\\\&'
      end
      if opts[:text].include? '%'
        opts[:text] = opts[:text].gsub! '%', '\\\\%'
      end
    end
    
    opts[:text] = "\\textbf{#{opts[:text]}}" unless opts[:th].nil?
    column = @table_row.size
    if opts[:colspan]
      vline = (draw_table_border_latex ? '|c|' : 'c')
      opts[:text] = "\\multicolumn{#{opts[:colspan]}}{#{vline}}{#{opts[:text]}}"
    end
    if opts[:rowspan]
      @table_multirow_next[column] = opts[:rowspan].to_i - 1
      opts[:text] = "\\multirow{#{opts[:rowspan]}}{*}{#{opts[:text]}}"
    end
    @table_row.push(opts[:text])
    ''
  end

  def table_close(opts)
    @tablecounter = 1 unless defined? @tablecounter
    number = @tablecounter
    @tablecounter = @tablecounter + 1
    output = "\\begin{savenotes}\n"
    output << "\\begin{table}[h]\n"
    output << "  \\centering\n"
    cols = 'X' * @table[0].size if not draw_table_border_latex
    cols = '|' + 'X|' * @table[0].size if draw_table_border_latex
    output << "\\begin{minipage}{\\linewidth}\n"
    output << "  \\begin{tabularx}{\\textwidth}{#{cols}}\n"
    output << "   \\hline \n" if draw_table_border_latex
    @table.each do |row|
      hline = (draw_table_border_latex ? "\\hline" : '')
      output << "    #{row.join(' & ')} \\\\ #{hline} \n"
    end
    output << "  \\end{tabularx}\n"
    output << "  \\caption{Table #{number}}\n"
    output << "  \\end{minipage}\n"
    output << "\\end{table}\n"
    output << "\\end{savenotes}\n"
    output
  end

  def image(opts)
    opts[:alt] = opts[:src] unless defined? opts[:alt]
    # Don't know how to use remote links, plus can we trust them?
    if opts[:src] =~ /^\w+\:\/\//
      title = "Remote content not shown. Click link to see it."
      [
        "\\begin{figure}[#{(opts[:align].nil? ? 'h' : 'htb')}]",
        "  \\centering",
        "  \\fbox{\\url{#{opts[:src]}}}",
        "  \\caption{#{title}}",
        ("  \\label{#opts[:alt]}}" if opts[:alt]),
        "\\end{figure}",
      ].compact.join "\n"
    else
      # Resolve CSS styles if any have been set
      styling = opts[:class].to_s.split(/\s+/).collect { |style| latex_image_styles[style] }.compact.join ','
      
      styling = "width=0.7\\textwidth" if styling.nil? or styling =~ /^$/
      title = opts[:title].nil? ? "Figure" : opts[:title]
      title = escape title
      
      [
        "\\begin{figure}[#{(opts[:align].nil? ? 'h' : 'htb')}]",
        "  \\centering",
        "  \\includegraphics[#{styling}]{#{opts[:src]}}",
        "  \\caption{#{title}}",
        ("  \\label{#opts[:alt]}}" if opts[:alt]),
        "\\end{figure}",
      ].compact.join "\n"
    end
    #    # Build latex code
    #    [ "\\begin{figure}[#{(opts[:align].nil? ? 'h' : 'htb')}]",
    #      "  \\centering",
    #      "  \\lwincludegraphics[#{styling}]{#{opts[:src]}}",
    #      ("  \\caption{#{escape opts[:title]}}" if opts[:title]),
    #      ("  \\label{#{opts[:alt]}}" if opts[:alt]),
    #      "\\end{figure}",
    #    ].compact.join "\n"
  end
  
end

module RedClothExtensionLatex
  # Solution for RegEx:
  # http://stackoverflow.com/questions/12493128/regex-replace-text-but-exclude-when-text-is-between-specific-tag

  def latex_code(text)
    @listingcounter = 1 unless defined? @listingcounter
    text.gsub!(/<pre>(.*?)<\/pre>/im) do |_|
      code = $1
      code.match(/<code\s+class="(.*)">(.*)<\/code>/im)
      lang = '{}'
      unless $1.nil?
	code = $2
	lang = "language={#{$1}}"
      end
      listingcount = @listingcounter
      @listingcounter = @listingcounter + 1
      
      #minted_settings = %W(mathescape linenos numbersep=5pt frame=lines framesep=2mm tabsize=4 fontsize=\\footnotesize breaklines breakanywhere)
      #.join(",")
      if lang == '{}'
        latex_code_text = [
          "<notextile>",
          "\\begin{code}",
          "\\begin{lstlisting}",
          "#{code}",
          "\\end{lstlisting}",
          "\\caption{Listing #{listingcount}}",
          "\\end{code}",
          "</notextile>"
        ].compact.join "\n"
      else
        latex_code_text = [
          "<notextile>",
          "\\begin{code}",
          "\\begin[#{lang}]{lstlisting}",
          "#{code}",
          "\\end{lstlisting}",
          "\\caption{Listing #{listingcount}}",
          "\\end{code}",
          "</notextile>"
        ].compact.join "\n"
      end
      latex_code_text
    end
  end

  
  # "<notextile> #{label} \\ref{page:#{var}}</notextile>"
  def latex_page_ref(text)
    text.gsub!(/(\s|^)\[\[(.*?)(\|(.*?)|)\]\]/i) do |_|
      var = $2
      label = $4
      label = var if label.nil? or label =~ /^\s*$/      
      "<notextile> \\textsl{#{label.gsub('_', ' ')}}\\fbox{\\ref{page:#{var}}}</notextile>"
    end
  end
  
  def latex_image_ref(text)
    text.gsub!(/(\s|^)\{\{!(.*?)!\}\}/i) do |_|
      var = $2
      "<notextile> \\ref{#{var}}</notextile>"
    end
  end

  def latex_footnote(text)
    notes = {}
    # Extract and delete footnote 
    text.gsub!(/fn(\d+)\.\s+(.*)/i) do |_|
      notes[$1] = $2
      ''
    end
    # Add footnote
    notes.each do |fn, txt|
      text.gsub!(/(\w+)\[#{fn}\]/i) do |_|
	"<notextile>#{$1}\\footnote{#{txt}}</notextile>"
      end
    end
  end

  def latex_index_emphasis(text)
    text.gsub!((/(?!<notextile[^>]*?>)(\s_(\w.*?)_)([^<])(?![^<]*?<\/notextile>)/im)) do |_|
      var = $1
      "#{var} <notextile>\\index{#{var.tr '_', ''}}</notextile>"
    end
  end

  def latex_index_importance(text)
    text.gsub!(/(?!<notextile[^>]*?>)(\s\*(\w.*?)\*)([^<])(?![^<]*?<\/notextile>)/im) do |_|
      var = $1
      "#{var} <notextile>\\index{#{var.tr '*', ''}}</notextile>"
    end
  end
  
  def latex_remove_macro(text)
    text.gsub!(/(?!<notextile[^>]*?>)((\s|^)\{\{(.*?)\}\})([^<])(?![^<]*?<\/notextile>)/i) do |_|
      ''
    end
  end
end

# Include rules
RedCloth.include(RedClothExtensionLatex)

class TextileDocLatex < RedCloth::TextileDoc
	attr_accessor :draw_table_border_latex
	
	def to_latex( *rules )
		apply_rules(rules)
		to(RedCloth::Formatters::LATEX_EX)
	end
end


