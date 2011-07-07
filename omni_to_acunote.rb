module OmniToAcunote
  include 'rubygems'
  include 'nokogiri'

  
  
  def omni_page(file_location = '/Users/bfeigin/Documents/Enova/Team')
    @page ||= Nokogiri::HTML(open(file_location))
  end

  def omni_headers
    @headers ||= omni_page.css(css_mapping[:headers]).children.map(&:content)
  end


  def css_mapping
    @css_mapping ||= 
      {
        :headers => 'td.header',
      }
  end
end
