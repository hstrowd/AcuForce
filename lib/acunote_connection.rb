require 'mechanize'
require 'yaml'
require 'singleton'

# A singleton class to contain the acunote session information.
class AcunoteConnection
  include Singleton

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

  def load_session
    if File.exists?(SESSION_FILE) && ! File.zero?(SESSION_FILE) && mech.cookie_jar.load(SESSION_FILE)
      @logged_in = true
    end
  end

  def clear_session
    File.delete(SESSION_FILE) if File.exists?(SESSION_FILE)
  end

  def login(username, password, force = false)
    @logged_in = nil if force
    return true if logged_in
    
    # Try to load an existing session.
    load_session unless force

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
      @logged_in = true
    end
    true
  end

  def logout()
    if File.exists?(SESSION_FILE)
      File.delete(SESSION_FILE)
    end
    get_page(logout_url)
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
