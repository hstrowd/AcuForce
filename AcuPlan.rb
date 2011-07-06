#!/usr/bin/env ruby
#INITAL DEVELOPMENT
#askryl
#https://github.com/skryl/AcuForce.git

#bfeigin intense modifications
#Ripped out most of AcuForce, kept the basic Acunote logic see AcunoteBase
#https://github.com/bfeigin/AcuForce.git

#Major modifications to transition from OmniPlan to Accunote
#Notes there are a few gems required see directly below :)

require 'rubygems'
require 'mechanize'
require 'highline/import'
require 'yaml'

THIS_FILE = File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__
THIS_DIR = File.dirname(THIS_FILE)
DEBUG = true

module AcunoteBase

  SESSION_FILE = "#{THIS_DIR}/acuPlan.session"


  HOME_URL = "https://acunote.cashnetusa.com/"
  LOGIN_URL = "https://acunote.cashnetusa.com/login"

  LOGIN_FIELDS = ['login[username]', 'login[password]']
  LOGIN_FORM_NAME = "login_form"

  @authToken = nil

  # Get user input to login to Acunote
  def get_login_info
    username = ask("Acunote Login name:")
    password = ask("Acunote(LDAP) Password:") {|q| q.echo = false}
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
  end

  #Not currently needed but grabs an auth token from the first form we can find
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

module AcunoteWiki
  include AcunoteBase

  WIKI_URL = proc{|proj_id, task_id| "https://acunote.cashnetusa.com/projects/#{proj_id}/wiki/#{task_id}"}
  WIKI_EDIT_URL = proc{|proj_id, task_id| WIKI_URL.call(proj_id,task_id)+"/edit"}

  def acunote_update_wiki(file_location,task_id)
    #Get the page and form
    wiki_page = get_page(WIKI_EDIT_URL.call('5208',task_id))
    wiki_dialog = wiki_page.forms_with({:name => 'wiki_dialog'}).first

    #Update Text Area with the file contents
    #TODO Add verification for this
    textarea = wiki_dialog.fields_with(:id => 'wiki_editor').first
    puts "GOT A TEXTAREA!!!" if DEBUG && textarea
    textarea.value = IO.read(file_location)

    wiki_dialog.submit
  end

  def pull_task_wiki(issue_number, save_location = nil)
    wiki_page = get_page(WIKI_URL.call('5208',issue_number))

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
  include AcnuoteBase
  include AcunoteWiki

  def initialize
    @mech = Mechanize.new
    run_loop
  end

  #Old School run loop :) 
  #I'll make sweet param style implementation soon
  def run_loop
    puts "welcome to AcuPlan"
    puts "param version comming soon!"
    puts "what would you like to do?"
    acunote_login
    
    # This makes me smile and other cry?
    task_id = ask("Task ID? -OR- blank for default (recommended)")
    #This will need to be updated by quarter?
    task_id = 379310 if task_id.empty?

    while true do
      task_to_run= ask("What would you like to do?\nu - Update metaTask with file\n r - Read MetaWiki\nx - Exit")
      case task_to_run
      when 'r'
        save_location = ask("Where would you like to save the output? blank for STDOUT")
        pull_task_wiki(task_id,save_location)
      when 'u'
        file_location= ask("Where is the file (csv) you'd like to upload?")
        acunote_update_wiki(file_location, task_id)
      when 'x'
        exit(0)
      end
    end
  end
end

runner = AcuPlan.new

