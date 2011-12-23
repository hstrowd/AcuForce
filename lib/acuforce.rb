#!/usr/bin/env ruby
#INITAL DEVELOPMENT
#askryl
#https://github.com/skryl/AcuForce.git

#bfeigin intense modifications
#Ripped out most of AcuForce, kept the basic Acunote logic see AcunoteBase
#https://github.com/bfeigin/AcuForce.git

#Major modifications to transition from OmniPlan to Accunote
#Notes there are a few gems required see directly below :)

require 'bundler'
require 'rubygems'
require 'mechanize'
require 'yaml'
require 'singleton'

THIS_FILE = File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__ unless defined? THIS_FILE
THIS_DIR = File.dirname(THIS_FILE) unless defined? THIS_DIR
DEBUG = true unless defined? DEBUG

class AcunoteSprint
  ACUNOTE_CSV_HEADER = "Level,Number,Description,Tags,Owner,Status,Resolution,Priority,Severity,Estimate,Remaining,Due Date,QA Owner,Business Owner,Wiki,Watchers,Related,Duplicate,Predecessors,Successors,Version 1\r\n" unless defined? ACUNOTE_CSV_HEADER

  def self.acu_conn
    AcunoteConnection.instance
  end

  def self.url(proj_id, sprint_id)
    "#{acu_conn.home_url}/projects/#{proj_id}/sprints/#{sprint_id}"
  end

  def self.create(sprint_name, opts = {})
    opts[:sprint_type] ||= 'Backlog'
    opts[:start_date]  ||= Date.today
    opts[:end_date]    ||= opts[:start_date] + 365

    unless acu_conn.logged_in
      STDERR.puts "Must login before creating a sprint." if DEBUG
      return false
    end

    sprint_page = acu_conn.get_page(url(opts[:proj_id], 'new'))
    sprint_form = sprint_page.forms_with({:name => 'sprint_new_dialog'}).first

    if opts[:sprint_type] == 'Backlog'
      (sprint_form.radiobuttons_with(:value => /Backlog/).first && 
      sprint_form.radiobuttons_with(:value => /Backlog/).first.check)
    else
      sprint_form.radiobuttons_with(:value => /Iteration/).first.check
      sprint_form.fields_with(:id => 'sprint_start_date').first.value = opts[:start_date].to_s
    end
    sprint_form.fields_with(:id => 'sprint_name').first.value = sprint_name
    sprint_form.fields_with(:id => 'sprint_end_date').first.value = opts[:end_date].to_s
    sprint_form.submit
  end

  def self.find_id_by_name(proj_id, sprint_name)
    link = find_sprint_by_name(proj_id, sprint_name)
    if(link.uri.to_s =~ /\/sprints\/([0-9]*)/)
      $1
    end
  end

  def self.find_by_name(proj_id, sprint_name)
    sprints = acu_conn.get_page(url(proj_id, ''))
    sprints.links_with(:text => sprint_name).first if sprints
  end

  def self.upload_csv(raw_data, proj_id, sprint_id)
    import_page = acu_conn.get_page(url(opts[:proj_id],sprint_id)+"/import")
    import_form = import_page.form_with({:name => 'import_form'})
    import_form.field_with(:id => 'data_to_import').value  = raw_data.to_s
    import_form.submit
  end

  def self.export_csv(proj_id, sprint_id)
    acu_conn.get_page(url(proj_id,sprint_id) + '/export').body
  end
end

# A singleton class to contain the acunote session information.
class AcunoteConnection
  include Singleton

  attr_accessor :username
  attr_writer :home_url
  attr_reader :logged_in, :mech

  def initialize()
    @mech ||= Mechanize.new
  end

  # For lack of a better place, put sessions in tmp
  SESSION_DIR = "/tmp" unless defined? SESSION_DIR
  SESSION_FILE = "#{SESSION_DIR}/acunote.session" unless defined? SESSION_FILE

  LOGIN_FIELDS = ['login[username]', 'login[password]'] unless defined? LOGIN_FIELDS
  LOGIN_FORM_NAME = "login_form" unless defined? LOGIN_FORM_NAME

  # The home_url must be set after the instance is first retrieved.
  def home_url
    raise "home_url not set" unless @home_url
    @home_url
  end

  def login_url
    "#{self.home_url}/login"
  end

  def logout_url
    "#{self.home_url}/login/logout"
  end

  def login(username, password, force = false)
    @logged_in = nil if force
    return true if logged_in

    #Going to assume the session is good to save time here. The session will be
    #discarded and a force login will be performed if get_page fails.
    if !force && File.exists?(SESSION_FILE) && ! File.zero?(SESSION_FILE) && mech.cookie_jar.load(SESSION_FILE)
      STDERR.puts "Loaded session file" if DEBUG
      @username = username
      @logged_in = true
    end

    unless logged_in

      #try to log in
      login_page = get_page(login_url)
      STDERR.puts "Navigated to '#{login_page.title}'" if DEBUG

      form = login_page.forms.first
      form[LOGIN_FIELDS[0]] = username
      form[LOGIN_FIELDS[1]] = password
      dest_page = form.submit(form.buttons.first)

      STDERR.puts "Navigated to '#{dest_page.title}'" if DEBUG
      if dest_page.uri == login_page.uri
        STDERR.puts "Error: Bad login!"
        return false
      end

      #serialize session and save for later reuse
      mech.cookie_jar.save_as(SESSION_FILE)
      @username = username
      @logged_in = true
    end
  end

  def logout()
    if File.exists?(SESSION_FILE)
      File.delete(SESSION_FILE)
    end
    get_page(logout_url)
    @username = nil
    @logged_in = false
  end

  def set_timeout(timeout = 60)
    mech.keep_alive = false
    mech.open_timeout = timeout
    mech.read_timeout = timeout
    mech.idle_timeout = timeout
  end

  #Retrieves the requested page and verifies destination url to make sure there
  #was no innapropriate redirect. If redirected, a force login will be performed
  #(assuming credentials are passed in as arguments) and the page will be retrieved 
  #again. 
  def get_page(url, matcher = /.*/, retry_count = 1)
    begin
      page = mech.get(url)
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
end
