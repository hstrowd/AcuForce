require 'acunote_connection'

# API for accessing Acunote projects.
class AcunoteSprint
  ACUNOTE_CSV_HEADER = "Level,Number,Description,Tags,Owner,Status,Resolution,Priority,Severity,Estimate,Remaining,Due Date,QA Owner,Business Owner,Wiki,Watchers,Related,Duplicate,Predecessors,Successors,Version 1\r\n" unless defined? ACUNOTE_CSV_HEADER

  def self.acu_conn
    AcunoteConnection.instance
  end

  def self.url(proj_id, sprint_id)
    "#{acu_conn.home_url}/projects/#{proj_id}/sprints/#{sprint_id}"
  end

  def self.create(proj_id, name, opts = {})
    opts[:type] ||= 'Backlog'
    opts[:start_date]  ||= Date.today
    opts[:end_date]    ||= opts[:start_date] + 365

    unless acu_conn.logged_in
      STDERR.puts "Must login before creating a sprint." if DEBUG
      return false
    end

    sprint_page = acu_conn.get_page(url(proj_id, 'new'))

    # Check that the project could be found.
    unless sprint_page
      STDERR.puts "Spcified project could not be found." if DEBUG
      return false
    end

    sprint_form = sprint_page.forms_with({:name => 'sprint_new_dialog'}).first

    if opts[:type] == 'Backlog'
      (sprint_form.radiobuttons_with(:value => /Backlog/).first && 
      sprint_form.radiobuttons_with(:value => /Backlog/).first.check)
    else
      sprint_form.radiobuttons_with(:value => /Iteration/).first.check
      sprint_form.fields_with(:id => 'sprint_start_date').first.value = opts[:start_date].to_s
    end
    sprint_form.fields_with(:id => 'sprint_name').first.value = name
    sprint_form.fields_with(:id => 'sprint_end_date').first.value = opts[:end_date].to_s
    sprint_form.submit
  end

  # NAME can be a literal string or a regex.
  def self.find_id_by_name(proj_id, name)
    link = find_by_name(proj_id, name)
    if(link && link.uri.to_s =~ /\/sprints\/([0-9]*)/)
      $1
    end
  end

  # NAME can be a literal string or a regex.
  def self.find_by_name(proj_id, name)
    sprints = acu_conn.get_page(url(proj_id, ''))
    sprints.links_with(:text => name).first if sprints
  end

  def self.upload_csv(proj_id, sprint_id, raw_data)
    import_page = acu_conn.get_page(url(proj_id,sprint_id)+"/import")
    import_form = import_page.form_with({:name => 'import_form'})
    import_form.field_with(:id => 'data_to_import').value  = raw_data.to_s
    import_form.submit
  end

  def self.export_csv(proj_id, sprint_id)
    acu_conn.get_page(url(proj_id,sprint_id) + '/export').body
  end
end
