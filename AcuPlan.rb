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

class AcuPlan

  ## Acunote LOGIN##
  SESSION_FILE = "#{THIS_DIR}/acuforce.session"
  LOGIN_URL = "https://acunote.cashnetusa.com/login"
  HOME_URL = "https://acunote.cashnetusa.com/"
  ATTATCHMENT_NEW_URL = 'https://acunote.cashnetusa.com/attachments/new'


  #Login STUFF#
  LOGIN_FIELDS = ['login[username]', 'login[password]']
  LOGIN_FORM_NAME = "login_form"

  def initialize(options)
    @mech = Mechanize.new
    options.merge!(get_login_info) unless options[:username] && options[:password]
    @options = options
    acunote_login
    run_loop
  end

  def run_loop
    puts "what would you like to do?"
    puts "only file upload test for now"
    file_location = ask("File Location")
    task_id = ask("Task ID")
    acunote_submit_attachment(file_location, task_id)
  end

  def get_login_info
    username = ask("Acunote Login")
    password = ask("Acunote(LDAP) Password") {|q| q.echo = false}
    {:username => username, :password => password}
  end


  def acunote_submit_attachment(file_location, issue_number, delete_after_write = false)
    add_attachment_page = get_page(ATTATCHMENT_NEW_URL + '?issue=' + issue_number)

    #Hackish but screw selectors :)
    attach_form = add_attachment_page.forms.first
    attach_form['attachment[uploaded_data]'] = file_location
    attach_form['attachment[description]'  ] = 'OmniPlan Meta Data for #{issue_number} DO NOT MODIFY!!!!'
    attach_form.submit

  end

  def acunote_login(force = false)
    return true if @logged_in

    #Going to assume the session is good to save time here. The session will be
    #discarded and a force login will be performed if get_page fails.
    if !force && File.exists?(SESSION_FILE) && @mech.cookie_jar.load(SESSION_FILE)
      STDERR.puts "Loaded session file" if DEBUG
      return @logged_in = true
    end

    #In case force login is called without credentials
    return false unless @options[:username] && @options[:password]

    #try to log in
    p = get_page(LOGIN_URL) 
    STDERR.puts "Navigated to '#{p.title}'" if DEBUG

    form = p.forms.first
    form[LOGIN_FIELDS[0]] = @options[:username]
    form[LOGIN_FIELDS[1]] = @options[:password]
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

  #Retrieves the requested page and verifies destination url to make sure there
  #was no innapropriate redirect. If redirected, a force login will be performed
  #(assuming credentials are passed in as arguments) and the page will be retrieved 
  #again. 
  def get_page(url, matcher = /.*/, retry_count = 1)
    creds = @options[:username] && @options[:password]

    begin
      page = @mech.get(url)
      if page.uri.to_s =~ matcher
        page
      else
        #try a force login and retry once (in case the session is stale)
        if creds && retry_count > 0 && login(true)
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

runner = AcuPlan.new(options)
runner.acunote_login

