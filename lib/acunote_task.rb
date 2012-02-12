require 'acunote_connection'

# API for accessing Acunote projects.
class AcunoteSprint
  def self.acu_conn
    AcunoteConnection.instance
  end

  def self.url(proj_id, task_id)
    "#{acu_conn.home_url}/projects/#{proj_id}/tasks/#{task_id}"
  end

  def self.mark_complete(proj_id, task_id)
    task_page = acu_conn.get_page(url(proj_id,task_id))
    if page.root.to_s =~ /FORM_AUTH_TOKEN = '(.*=)';/
      form_auth_token = $1
      acu_conn.mech.post("#{acu_conn.home_url}/issues/update", {'number'=>task_id,'field'=>'status','view'=>'task_details','value'=>'In Progress','old_value'=>'Not Started','authenticity_token'=>form_auth_token,'project_id'=>proj_id,'_method'=>'post'})
      true
    else
      nil
    end
    # IT WORKS!!!!!!:
    # res = m.post('https://acunote.cashnetusa.com/issues/update', {'number'=>'482727','field'=>'status','view'=>'task_details','value'=>'In Progress','old_value'=>'Not Started','authenticity_token'=>'pAdUHkxKUoQr8bwnIEaGPz9jf1SeRlVdUnxCuJgfb0Q=','project_id'=>'5208','_method'=>'post'})



    # The following javascript works to update a tasks status:
    # new Ajax.Request('/issues/update',{parameters:{number:482727,field:'status',view:'task_details',value:'In Progress',old_value:'Not Started'}});
    # new Ajax.Request('https://acunote.cashnetusa.com/issues/update',{parameters:{number:482727,field:'status',view:'task_details',value:'Not Started',old_value:'In Progress'}});
    # number='482729'&field='status'&view='task_details'&value='Completed'&old_value='Not Started'

# {number:482727,field:'status',view:'task_details',value:'In Progress',old_value:'Not Started',_method:'post',authenticity_token:'pAdUHkxKUoQr8bwnIEaGPz9jf1SeRlVdUnxCuJgfb0Q=',project_id:'5208'}
# "number=482729&field=status&view=task_details&value=In%20Progress&old_value=Not%20Started&_method=post&authenticity_token=pAdUHkxKUoQr8bwnIEaGPz9jf1SeRlVdUnxCuJgfb0Q%3D&project_id=5208"

# "number='482729'&field='status'&view='task_details'&value='In Progress'&old_value='Not Started'&_method='post'&authenticity_token='pAdUHkxKUoQr8bwnIEaGPz9jf1SeRlVdUnxCuJgfb0Q='&project_id='5208'"

# http = new XMLHttpRequest();
# http.open("POST", "/issues/update")
# http.send("number=482727&field=status&view=task_details&value='In Progress'&old_value='Not Started'")


# /tasks/set_field?task=482729&field=status&sprint=29562
# parameters={'field':field,'old_value':elem.old_value}
# parameters['value_'+field+"_"+id]=value;
# if(taskEditors.view()=='task_details'){parameters["view"]='task_details'}
# if(pageProperties.projectId)
#  parameters["project_id"]=pageProperties.projectId;
# if((/^(description|estimate|remaining)$/).test(field)){this.hideEditor(field,id,'task_');}
# this.resetDynamicEditor(field);
# new Ajax.Request('/tasks/set_field?task='+id+'&field='+field+'&'+taskList.urlParams(),{asynchronous:true,evalScripts:true,parameters:parameters,onComplete:function(){observersManager.restore()}});

# new Ajax.Request('/tasks/set_field?task=482727&field=status&sprint=29562');
# sprint=29562
# new Ajax.Request('/tasks/set_field?task=482727&field=status&sprint=29562',{parameters:{value_status_id:'In Progress',field:'status',old_value:'Not Started'}});
  end
end
