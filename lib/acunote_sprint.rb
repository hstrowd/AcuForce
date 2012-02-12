require 'acunote_connection'

# API for accessing Acunote sprints.
class AcunoteSprint
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

  # Note: This is extremely brittle to the structure of the acunote sprint page, but I 
  # couldn't find any other way to do it. 
  def self.find_task_id_by_name(proj_id, sprint_id, task_name)
    sprint_page = acu_conn.get_page(url(proj_id,sprint_id)+'/show')
    all_tasks = sprint_page.parser.search('span.descr_edit')
    matches = all_tasks.select { |task_node| task_node.text.match(task_name) }
    STDOUT.puts("Found #{all_tasks.size} tasks in this sprint. Out of those #{matches.size} matched the task name provided.") if DEBUG
    if matches.size == 1
      STDOUT.puts("Found match: #{matches[0]}") if DEBUG
      prop = matches[0].search('span.task_properties')[0]
      prop_id_str = prop.attribute('id').text
      STDOUT.puts("Found a properties span with: #{prop_id_str}") if DEBUG
      if prop_id_str =~ /^task_propertires_([0-9]*)$/
        task_prop = $1
        links = sprint_page.links_with(:id => "issue_number_for_#{task_prop}")
        STDOUT.puts "Found the following links matching the property for this task: #{links.inspect}" if DEBUG 
        if links.size == 1
          links[0].text
        else
          nil
        end
      else
        nil
      end
    else
      nil
    end
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
