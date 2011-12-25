require 'acunote_connection'

# API for accessing Acunote projects.
class AcunoteProject
  def self.acu_conn
    AcunoteConnection.instance
  end

  def self.url(id)
    "#{acu_conn.home_url}/projects/#{id}"
  end

  def self.find_id_by_name(name)
    link = find_by_name(name)
    if(link && link.uri.to_s =~ /projects\/([0-9]*)\/sprints/)
      $1
    end
  end

  # NAME can be a literal string or a regex.
  def self.find_by_name(name)
    projects = acu_conn.get_page(url(''))
    projects.links_with(:href => /projects\/([0-9]*)\/sprints$/, :text => name).first if projects
  end
end
