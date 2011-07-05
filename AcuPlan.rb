#!/usr/bin/env ruby
#INITAL DEVELOPMENT
#askryl
#https://github.com/skryl/AcuForce.git
#Modified to transition from OmniNote to Accunote, yes a lot of notes!
#Notes there are a few gems required:
#namely mechanize, highline, and optsparse

require 'rubygems'
require 'mechanize'
require 'highline/import'
require 'optparse'
require 'yaml'
require 'pp'

THIS_FILE = File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__
THIS_DIR = File.dirname(THIS_FILE)
DEBUG = true

#Parse options to be passed in
options ={}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: OmniAcuNote.rb [options] file_to_upload" 

  options[:debug] = false
  opts.on('-q', '--debug') do
    options[:debug] = true
  end

  opts.on(%w(-h --help)) do 
    puts "TODO with the help sorry for now!"
  end
end

optparse.parse!

module AcunoteBase

  @authToken = nil
  HOME_URL = "https://acunote.cashnetusa.com/"

  def get_page_with_params(url, params = {}, opts = {})
    dirty_url +='?'
    params.each do |key,value|
      dirty_url+=key.to_s + "=" + value.to_s + "&"
    end
    #TODO anything but this maybe?
    #Lazy implementaiton i'll fix later
    get_page(dirty_dirty_url[0..-2])
  end
  
  def grab_auth_token
    return @authToken if @authToken
    home_page = get_page(HOME_URL)
    @authToken = home_page.forms.first['authenticity_token']
    STDERR.puts "FOUND AUTH TOKEN #{@authToken}" if DEBUG
  end

  #Retrieves the requested page and verifies destination url to make sure there
  #was no innapropriate redirect. If redirected, a force login will be performed
  #(assuming credentials are passed in as arguments) and the page will be retrieved 
  #again. 
  def get_page(url, matcher = /.*/, retry_count = 1)

    begin
      page = @mech.get(url)
      if page.uri.to_s =~ matcher
        page
      else
        #try a force login and retry once (in case the session is stale)
        if retry_count > 0 && login(true)
          STDERR.puts "Attn: get_page problem, overwrote stale session, retrying..."
          get_page(url, matcher, retry_count - 1)
        else STDERR.puts "Error: Can't retrieve valid response page for <#{url}>"
        end
      end
    rescue Mechanize::ResponseCodeError => e
      STDERR.puts "ResponseError!"
      puts url if DEBUG
      puts e if DEBUG
    end
  end
  private :get_page
end

module AcunoteLogin

  LOGIN_FIELDS = ['login[username]', 'login[password]']
  LOGIN_FORM_NAME = "login_form"
  SESSION_FILE = "#{THIS_DIR}/acuforce.session"

  LOGIN_URL = "https://acunote.cashnetusa.com/login"
  

  def get_login_info
    username = ask("Acunote Login")
    password = ask("Acunote(LDAP) Password") {|q| q.echo = false}
    {:username => username, :password => password}
  end


  def acunote_login(force = false)
    return true if @logged_in

    #Going to assume the session is good to save time here. The session will be
    #discarded and a force login will be performed if get_page fails.
    if !force && File.exists?(SESSION_FILE) && @mech.cookie_jar.load(SESSION_FILE)
      STDERR.puts "Loaded session file" if DEBUG
      @logged_in = true
    end

    unless @logged_in

      #try to log in
      p = get_page(LOGIN_URL) 
      STDERR.puts "Navigated to '#{p.title}'" if DEBUG

      login_info = get_login_info
      form = p.forms.first
      form[LOGIN_FIELDS[0]] = login_info[:username]
      form[LOGIN_FIELDS[1]] = login_info[:password]
      p = form.submit(form.buttons.first)

      unless p.uri.to_s ==  HOME_URL
        STDERR.puts "Error: Bad login!"
        exit
      end
      STDERR.puts "Navigated to '#{p.title}'" if DEBUG

      #serialize session and save for later reuse
      @mech.cookie_jar.save_as(SESSION_FILE)
      @logged_in = true
    end
    # THIS MUST RUN!!!!
    grab_auth_token
  end
end

module AcunoteModifications

  ATTATCHMENT_NEW_URL   = 'https://acunote.cashnetusa.com/attachments/new'
  WIKI_EDIT_URL = proc{|proj_id, task_id| "https://acunote.cashnetusa.com/projects/#{proj_id}/wiki/#{task_id}/edit"}
  #Not currently functional
  def acunote_submit_attachment(file_location, issue_number, delete_after_write = false)
    raise("NOT FULLY IMPLEMENTED")
    add_attachment_page = get_page_with_params(ATTATCHMENT_NEW_URL ,{:issue => issue_number} )

    #Hackish but screw selectors :)
    attach_form = add_attachment_page.forms.first
    attach_form['attachment[uploaded_data]'] = file_location
    attach_form['attachment[description]'  ] = 'OmniPlan Meta Data for #{issue_number} DO NOT MODIFY!!!!'
    attach_form.submit
  end

  def acunote_update_wiki(file_location,task_id)
    wiki_page = get_page(WIKI_EDIT_URL.call('5208','379310'))
    wiki_dialog = wiki_page.forms_with({:name => 'wiki_dialog'}).first
    textarea = wiki_dialog.fields_with(:id => 'wiki_editor').first
    puts "GOT A TEXTAREA!!!" if DEBUG && textarea
    textarea.value = IO.read(file_location)
    wiki_dialog.submit
  end
end

module AcunoteReading
  WIKI_GET_URL = proc{|proj_id, task_id| "https://acunote.cashnetusa.com/projects/#{proj_id}/wiki/#{task_id}"}

  def pull_task_wiki(issue_number, save_location = nil)
    wiki_page = get_page(WIKI_GET_URL.call('5208',issue_number))

    pulled_data = wiki_page.parser.xpath('/html/body/div/div[7]/div[4]/div/p').first.inner_html

    if save_location.empty?
      puts "no save location specified so to STDOUT!\n"
      puts pulled_data
    else
      puts "saving pull to #{save_location}"
      File.open(save_location, 'w') {|f| f.write(pulled_data) }
    end
  end

end

class AcuPlan
  require 'net/http'
  require 'uri'

  include AcunoteBase
  include AcunoteLogin
  include AcunoteModifications
  include AcunoteReading


  def initialize(options)
    @mech = Mechanize.new
    run_loop
  end

  def run_loop
    puts "welcome to AcuPlan"
    puts "what would you like to do?"
    acunote_login
    task_id = ask("Task ID? -OR- blank for default (recommended)")
    task_id = 379310 if task_id.empty?

    task_to_run= ask("What would you like to do?\nu - Update metaTask with file\n r - Read MetaWiki\nx - Exit")
    case task_to_run
    when 'r'
      save_location = ask("Where would you like to save the output? blank for STDOUT"
      pull_task_wiki(task_id,save_location)
    when 'u'
      file_location= ask("Where is the file (csv) you'd like to upload?")
      acunote_update_wiki(file_location, task_id)
    when 'x'
      exit(0)
    end


    
    #####    UPDTAE WIKI
    #file_location =
    #  if DEBUG
    #    '/Users/bfeigin/Desktop/Q3_2011_bfeigin_team.csv'
    #  else
    #    file_location = ask("File Location (to dump into the wiki)")
    #  end
    #

    #acunote_update_wiki(file_location, task_id)
    #######   END UPDATE WIKI
    puts "reading the wiki for task!"
    pull_task_wiki(379310)
    

    #acunote_submit_attachment(file_location, task_id)
  end
end

runner = AcuPlan.new(options)

