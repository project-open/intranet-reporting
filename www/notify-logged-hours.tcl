# /packages/intranet-reporting/www/notify-logged-hours.tcl
#
# Copyright (C) 1998 - now Project Open Business Solutions S.L. 

# All rights reserved. Please check
# http://www.project-open.com/ for licensing details.

ad_page_contract {
    Purpose: Allows sending an email reminder 
    @author klaus.hofeditz@project-open.com
} {
    user_id:array,optional
    start_date 
    end_date 
    { return_url "" }
}

set current_user_id [ad_maybe_redirect_for_registration]
set current_user_name [db_string cur_user "select im_name_from_user_id(:current_user_id) from dual"]
db_0or1row get_user_name "select first_names, last_name from persons where person_id=:current_user_id"

set user_id_list [array names user_id]
set direct_reports [db_list get_direct_reports "select employee_id from im_employees e, registered_users u where e.employee_id = u.user_id and e.supervisor_id = $current_user_id" ]

set list_name_recipient [list]

# Check if all user_id are direct reports of current user and set name_recipient at the same time 
# No other permissions checks will be performed
foreach rec_user_id [array names user_id] {
    if { [lindex $direct_reports $rec_user_id] == -1 } {
	ad_return_complaint 1 [lang::message::lookup "" intranet-reporting.UserNotADirectReport "We found a user that is not one of your direct reports, please go back and correct the error."]
    }  
    lappend list_name_recipient [im_name_from_user_id $rec_user_id]
}

# --------------------------------------------------------
# Prepare to send out an email alert
# --------------------------------------------------------

set page_title [lang::message::lookup "" intranet-reporting.SendReminder "Send Reminder"]%>
set context [list $page_title]
set export_vars [export_vars -form {return_url user_id:multiple start_date end_date}]

set name_recipient [join $list_name_recipient ", "]

# Show a textarea to edit the alert at member-add-2.tcl
ad_return_template

