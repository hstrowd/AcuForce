require 'acunote_connection'

# API for accessing Acunote tasks.
class AcunoteTask
  def self.acu_conn
    AcunoteConnection.instance
  end

  def self.url(proj_id, task_id)
    "#{acu_conn.home_url}/projects/#{proj_id}/tasks/#{task_id}"
  end

  # This assumes that the task is current in the not started state. If it is in any other state, this will not work.
  # TODO: Update this to identify the current status of the task and move it from any status to completed.
  def self.mark_complete(proj_id, task_id)
    task_page = acu_conn.get_page(url(proj_id,task_id))
    if task_page.root.to_s =~ /FORM_AUTH_TOKEN = '(.*=)';/
      form_auth_token = $1
      acu_conn.mech.post("#{acu_conn.home_url}/issues/update", {'number'=>task_id,'field'=>'status','view'=>'task_details','value'=>'Completed','old_value'=>'Not Started','authenticity_token'=>form_auth_token,'project_id'=>proj_id,'_method'=>'post'})
      true
    else
      nil
    end
  end
end
