require 'acunote_connection'

# API for accessing Acunote tasks.
class AcunoteTask
  def self.acu_conn
    AcunoteConnection.instance
  end

  def self.url(proj_id, task_id)
    "#{acu_conn.home_url}/projects/#{proj_id}/tasks/#{task_id}"
  end

  def self.mark_complete(proj_id, task_id)
    task_page = acu_conn.get_page(url(proj_id,task_id))
    if task_page.root.to_s =~ /FORM_AUTH_TOKEN = '(.*=)';/
      form_auth_token = $1
      acu_conn.mech.post("#{acu_conn.home_url}/issues/update", {'number'=>task_id,'field'=>'status','view'=>'task_details','value'=>'In Progress','old_value'=>'Not Started','authenticity_token'=>form_auth_token,'project_id'=>proj_id,'_method'=>'post'})
      true
    else
      nil
    end
  end
end
