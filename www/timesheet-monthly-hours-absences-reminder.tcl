# /packages/intranet-reporting/www/timesheet-monthly-hours-absences-reminder.tcl
#
# Copyright (C) 2003-now Project Open Business Solutions S.L.
#
# All rights reserved. Please check
# http://www.project-open.com/ for licensing details.

# Changes: 
#	- show at least one week  
# 	- show max. 4 weeks

ad_page_contract {
    @param start_year Year to start the report
    @param start_unit Month or week to start within the start_year
} {
    { start_date "" }
    { end_date "" }
    { level_of_detail 3 }
    { output_format "html" }
    { user_id:integer,multiple 0  }
    { project_id 0 }
    { project_status_id 76 }
    { customer_id 0 }
    { daily_hours 0 }
    { different_from_project_p "" }
    { cost_center_id 0 }
    { department_id 0 }
}

# ------------------------------------------------------------
# Report specific procs
# ------------------------------------------------------------

ad_proc -private im_report_render_absences {
    -group_def
    -last_value_array_list
    -start_date 
    -end_date
    {-encoding ""}
    {-output_format "html"}
    {-row_class ""}
    {-cell_class ""}
    {-level_of_detail 999}
    {-debug 0}
    {-absences_list ""}
} {
    Renders the footer stack of a single row in a project-open report. 
    The procedure acts similar to im_report_render_header,
    but returns a list of results instead of writing the results
    to the web page immediately.
    This is done, because the decision what footer lines to display
    can only be taken when the next row is displayed.
    Returns a list of report lines, each together with the group_var.
    A group_var with a value different from the current one is the
    trigger to display the footer line.
} {

    # im_day_enumerator excludes last day
    set end_date_plus_one [db_string get_number_days_month "SELECT :end_date::date + '1 day'::interval" -default 0]

    set timesheet_hours_per_day [parameter::get -package_id [apm_package_id_from_key intranet-timesheet2] -parameter "TimesheetHoursPerDay" -default 8]
    if { "" != $absences_list  } { array set absence_arr $absences_list }

    if {$debug} { ns_log Notice "render_footer:" }
    array set last_value_array $last_value_array_list
    if {$debug} { ns_log NOTICE "intranet-reporting-procs::im_report_render_absences:: ==============================================================" }
    if {$debug} { ns_log NOTICE "intranet-reporting-procs::im_report_render_absences:: group_def: $group_def" }
    if {$debug} { ns_log NOTICE "intranet-reporting-procs::im_report_render_absences:: last_value_array_list: $last_value_array_list" }

    # Split group_def and assign to an array for reverse access
    set group_level 1
    while {[llength $group_def] > 0} {
	set group_def_array($group_level) $group_def
	if {$debug} { ns_log Notice "render_footer: group_def_array($group_level) = ..." }
	array set group_array $group_def
        set group_def {}
        if {[info exists group_array(content)]} {
            set group_def $group_array(content)
        }
        incr group_level
    }
    set group_level [expr $group_level - 1]

    while {$group_level > 0} {
	if {$debug} { ns_log Notice "render_footer: level=$group_level" }

	# -------------------------------------------------------
	# Extract the definition of the current level from the definition
	array set group_array $group_def_array($group_level)
	set group_var $group_array(group_by)
	set footer $group_array(footer)
	set content $group_array(content)

        # -------------------------------------------------------
        # Determine the new value for the current group_level
        set new_value ""
        if {$group_var != ""} {
            upvar $group_var $group_var
            if {![info exists $group_var]} {
                ad_return_complaint 1 "Header: Level $group_level: Group var '$group_var' doesn't exist"
            }
            set cmd "set new_value \"\$$group_var\""
            eval $cmd
            if {$debug} { ns_log Notice "render_footer: level=$group_level, new_value='$new_value'" }
        }

	# -------------------------------------------------------
	# Get absences for user 
	# -------------------------------------------------------

	# Determine month 
	if {$debug} { ns_log NOTICE "intranet-reporting-procs::im_report_render_absences::group_var: $group_var" }

	# -------------------------------------------------------
	# Write out absences to an array
	# -------------------------------------------------------
	set absence_line [list]
	set ctr 0
	set total_sum_absences 0
	
	lappend absence_line [lang::message::lookup "" intranet-timesheet2.Absences "Absences"]
	lappend absence_line "&nbsp;"
	lappend absence_line "&nbsp;"
	
	db_foreach rec "select im_day_enumerator(to_date(:start_date,'yyyy-mm-dd'), to_date(:end_date_plus_one,'yyyy-mm-dd')) as r_date from dual" {
	    set date_ansi_key $r_date
	    if { [info exists absence_arr($date_ansi_key)] } {
		if {$debug} { ns_log NOTICE "intranet-reporting-procs::im_report_render_absences::found absence" }
                    # Evaluate absence amount
                    # absence_arr($date_ansi_key) is list of lists
                    set total_absence 0
		foreach absence_list_item $absence_arr($date_ansi_key) {
                        # Absences are stored as days/fractions of a day
                        # Evaluate total absence in UoM: 'Hours'
		    if { 1 < [expr [lindex $absence_list_item 0] + 0] } {
                            # We assume that absences with a total (total_days) > 1 are always full day absences
			set total_absence [expr $total_absence + $timesheet_hours_per_day]
		    } else {
                            # Single absences might be fraction of day
			set total_absence [expr [expr $timesheet_hours_per_day + 0] * [expr [lindex $absence_list_item 0]]]
		    }
		}

		if { "html" == $output_format } {
                        set value "<a href='/intranet-timesheet2/absences?view_name=absence_list_home&user_selection=$new_value"
                        append value "&timescale=start_stop&start_date=$date_ansi_key&end_date=$date_ansi_key' title='$absence_arr($date_ansi_key)'><strong>$total_absence</strong></a>"
		} else {
                        set value "$total_absence"
		}
		set total_sum_absences [expr $total_sum_absences + [expr $total_absence + 0]]
	    } else {
		if {$debug} { ns_log NOTICE "intranet-reporting-procs::im_report_render_absences::did not found absence in array" }
		set value "&nbsp;"
	    }
	    lappend absence_line $value
	    incr ctr
	}

	# For column "hours total"
	lappend absence_line "&nbsp;"

	set footer_record [list \
	    line $absence_line \
	    new_value $new_value
	]
	# Store the result to display later
	set footer_array($group_level) $footer_record

	set group_level [expr $group_level - 1]
    }
    if {$debug} { ns_log Notice "render_footer: after group_by footers" }
    
    return [array get footer_array]
}


ad_proc -private im_report_display_absences {
    -group_def
    -footer_array_list
    -last_value_array_list
    {-encoding ""}
    {-output_format "html"}
    {-display_all_footers_p 0}
    {-level_of_detail 999}
    {-cell_class ""}
    {-row_class ""}
    {-debug 0}
} {
    
} {
    if {$debug} { ns_log Notice "display_footer:" }
    array set last_value_array $last_value_array_list
    array set footer_array $footer_array_list

    # -------------------------------------------------------
    # Abort if there are no footer values, because this
    # is probably the first time that this routine is executed
    if {[llength $footer_array_list] == 0} {
	return
    }

    set group_def_org $group_def

    # -------------------------------------------------------
    # Determine the "return_group_level" to which we have to go _back_.
    # This level determines the number of footers that we need to write out.
    #
    set return_group_level 1
    while {[llength $group_def] > 0} {

	# -------------------------------------------------------
	# Extract the definition of the current level from the definition
	array set group_array $group_def
	set group_var $group_array(group_by)
	set header $group_array(header)
	set content $group_array(content)
	if {$debug} { ns_log Notice "display_footer: level=$return_group_level, group_var=$group_var" }

	# -------------------------------------------------------
	# 
	set footer_record_list $footer_array($return_group_level)
	array set footer_record $footer_record_list
	set new_record_value $footer_record(new_value)

	# -------------------------------------------------------
	# Determine new value for the current group return_group_level
	set new_value ""
	if {$group_var != ""} {
	    upvar $group_var $group_var
	    set cmd "set new_value \"\$$group_var\""
	    eval $cmd
	}

	# -------------------------------------------------------
	# Check if new_value != new_record_value.
	# In this case we have found the first level in which the
	# results differ. This is the level where we have to return.
	if {$debug} { ns_log Notice "display_footer: level=$return_group_level, group_var=$group_var, new_record_value=$new_record_value, new_value=$new_value" }
	if {![string equal $new_value $new_record_value]} {
	    # leave the while loop
	    break
	}

	# -------------------------------------------------------
	# Prepare the next iteration of the while loop:
	# continue with the "row" part of the current level
	set group_def {}
	if {[info exists group_array(content)]} {
	    set group_def $group_array(content)
	}
	incr return_group_level

    }

    # Restore the group_def destroyed by the previous while loop
    set group_def $group_def_org


    # -------------------------------------------------------
    # Calculate the maximum level in the report definition
    set max_group_level 1
    while {[llength $group_def] > 0} {
	set group_def_array($max_group_level) $group_def
	if {$debug} { ns_log Notice "display_footer: group_def_array($max_group_level) = ..." }
	array set group_array $group_def
        set group_def {}
        if {[info exists group_array(content)]} {
            set group_def $group_array(content)
        }
        incr max_group_level
    }
    set max_group_level [expr $max_group_level - 2]


    if {$display_all_footers_p} { set return_group_level 1 }
    if {$max_group_level > $level_of_detail} { set max_group_level $level_of_detail }

    # -------------------------------------------------------
    # Now let's display all footers between max_group_level and
    # return_group_level.
    #
    if {$debug} { ns_log Notice "display_footer: max_group_level=$max_group_level, return_group_level=$return_group_level" }
    for {set group_level $max_group_level} { $group_level >= $return_group_level} { set group_level [expr $group_level-1]} {

	# -------------------------------------------------------
	# Extract the absence_line
	#
	set footer_record_list $footer_array($group_level)
	array set footer_record $footer_record_list
	set new_record_value $footer_record(new_value)
	set absence_line $footer_record(line)

	# -------------------------------------------------------
	# Write out the header if last_value != new_value

	if {$debug} { ns_log Notice "display_footer: writing footer for group_level=$group_level" }

	switch $output_format {
	    html - printer { ns_write "<tr>\n" }
	    csv {  }
	}

	foreach field $absence_line {
	    im_report_render_cell -encoding $encoding -output_format $output_format -cell $field -cell_class $cell_class
	}

	switch $output_format {
	    html - printer { ns_write "</tr>\n" }
	    csv { ns_write "\n" }
	}

    }
}


# ------------------------------------------------------------
# Security & Permissions
# ------------------------------------------------------------

# Label: Provides the security context for this report
set menu_label "timesheet-monthly-hours-absences-reminder"
set current_user_id [ad_maybe_redirect_for_registration]
set read_p [db_string report_perms "
	select	im_object_permission_p(m.menu_id, :current_user_id, 'read')
	from	im_menus m
	where	m.label = :menu_label
" -default 'f']

if {![string equal "t" $read_p]} {
    ad_return_complaint 1 "<li>
    [lang::message::lookup "" intranet-reporting.You_dont_have_permissions "You don't have the necessary permissions to view this page"]"
    return
}

# Check if current user has direct reports 
set count_direct_reports [db_string count_direct_reports "select count(*) from im_employees e, registered_users u where e.employee_id = u.user_id and e.supervisor_id = $current_user_id" -default 0]
if { 0 == $count_direct_reports && ![im_is_user_site_wide_or_intranet_admin $current_user_id ]} {
    ad_return_complaint 1 [lang::message::lookup "" intranet-reporting.NoDirectReportsFound "Report not available, no direct reports found for current user"]
}

# ------------------------------------------------------------
# Defaults
# ------------------------------------------------------------

set debug 0
set date_format "YYYY-MM-DD"
set timesheet_hours_per_day [parameter::get -package_id [apm_package_id_from_key intranet-timesheet2] -parameter "TimesheetHoursPerDay" -default 8]

set page_title [lang::message::lookup "" intranet-reporting.TimesheetReportReminder "Timesheet - Reminders"]
set context_bar [im_context_bar $page_title]
set context ""

set company_url "/intranet/companies/view?company_id="
set project_url "/intranet/projects/view?project_id="
set user_url "/intranet/users/view?user_id="

set internal_company_id [im_company_internal]

set num_format "999,990.99"

set im_absence_type_vacation 5000
set im_absence_type_personal 5001
set im_absence_type_sick 5002
set im_absence_type_travel 5003
set im_absence_type_bankholiday 5005
set im_absence_type_training 5004

set todays_date [db_string todays_date "select to_char(now(), :date_format) from dual" -default ""]

# ------------------------------------------------------------
# Validate Dates 
# ------------------------------------------------------------

if { "" != $start_date } {
    if {[catch {
	if { $start_date != [clock format [clock scan $start_date] -format %Y-%m-%d] } {
	    ad_return_complaint 1 "<strong>[_ intranet-core.Start_Date]</strong> [lang::message::lookup "" intranet-core.IsNotaValidDate "is not a valid date"].<br>
            [lang::message::lookup "" intranet-core.Current_Value "Current value"]: '$start_date'<br>"
	}
    } err_msg]} {
	ad_return_complaint 1 "<strong>[_ intranet-core.Start_Date]</strong> [lang::message::lookup "" intranet-core.DoesNotHaveRightFormat "doesn't have the right format"].<br>
            [lang::message::lookup "" intranet-core.Current_Value "Current value"]: '$start_date'<br>
            [lang::message::lookup "" intranet-core.Expected_Format "Expected Format"]: 'YYYY-MM-DD'"
    }
} else {
    # set start date 1st of current month 
    set start_date "[string range $todays_date 0 3]-[string range $todays_date 5 6]-01"
}

if { "" != $end_date } {
    if {[catch {
	if { $end_date != [clock format [clock scan $end_date] -format %Y-%m-%d] } {
	    ad_return_complaint 1 "<strong>[_ intranet-core.End_Date]</strong> [lang::message::lookup "" intranet-core.IsNotaValidDate "is not a valid date"].<br>
            [lang::message::lookup "" intranet-core.Current_Value "Current value"]: '$end_date'<br>"
	}
    } err_msg]} {
	ad_return_complaint 1 "<strong>[_ intranet-core.End_Date]</strong> [lang::message::lookup "" intranet-core.DoesNotHaveRightFormat "doesn't have the right format"].<br>
            [lang::message::lookup "" intranet-core.Current_Value "Current value"]: '$end_date'<br>
            [lang::message::lookup "" intranet-core.Expected_Format "Expected Format"]: 'YYYY-MM-DD'"
    }
} else {
    set first_day_of_this_month "[string range $todays_date 0 3]-[string range $todays_date 5 6]-01"
    set end_date [string range [db_string get_number_days_month "SELECT '$first_day_of_this_month'::date + '1 month'::interval" -default 0] 0 9 ]
    set end_date [string range [db_string get_number_days_month "SELECT '$end_date'::date - '1 day'::interval" -default 0] 0 9 ]
}

# im_day_enumerator excludes last day
set end_date_plus_one [db_string get_number_days_month "SELECT :end_date::date + '1 day'::interval" -default 0]

# Period should not exceed 4 weeks days, primarely for layout reasons, secondary because dayxx var's would need to extended to hold also month  
set duration [db_string get_number_days_month "select count(*) from (select im_day_enumerator(to_date(:start_date,'yyyy-mm-dd'), to_date(:end_date_plus_one,'yyyy-mm-dd')) from dual) foo" -default 0]

if { $duration > 31  } {
    ad_return_complaint 1 [lang::message::lookup "" intranet-reporting.MaxFourWeeks "Reported is limited to a maximum of 31 days, please adjust start and end date accordingly"]
}

# ------------------------------------------------------------
# Conditional SQL Where-Clause
#
 
if {[empty_string_p $different_from_project_p]} {
   set mm_checked ""
   set mm_value  ""
} else {
   set mm_checked "checked"
   set mm_value  "value='on'"
}

set criteria [list]

if {"" != $project_id && 0 != $project_id && $different_from_project_p == ""} {	
    lappend criteria "
		p.project_id in (
		select 
			children.project_id as subproject_id
		from
			im_projects parent,
			im_projects children
		where
		        tree_ancestor_key(children.tree_sortkey, 1) = parent.tree_sortkey 
			and parent.project_id = :project_id
			)
    "
}

 if {"" != $project_id && 0 != $project_id && $different_from_project_p != ""} {
        lappend criteria "
		p.project_id in (
		select 
			children.project_id as subproject_id
		from
			im_projects parent,
			im_projects children
		where
			tree_ancestor_key(children.tree_sortkey, 1) = parent.tree_sortkey 
			and parent.project_id <> :project_id
			)
    "
}

if {"" != $customer_id && 0 != $customer_id} {
	 lappend criteria "p.company_id = :customer_id" 
}

if { ![empty_string_p $project_status_id] && $project_status_id > 0 } {
    lappend criteria "p.project_status_id in ([join [im_sub_categories $project_status_id] ","])"
}

if {[info exists user_id] && 0 != $user_id && "" != $user_id } {
    lappend criteria "h.user_id in ([join $user_id ", "])"
}

# Put everything together
set where_clause [join $criteria " and\n            "]
if { ![empty_string_p $where_clause] } {
    set where_clause " and $where_clause"
}

# -----------------------------------------------------------
# Outer where 
# -----------------------------------------------------------

set outer_where ""
set criteria_outer [list]

# Check for filter "Employee"  
if { "" != $user_id } { lappend criteria_outer "user_id in ([join $user_id ", "])" }

# Check for filter "Cost Center"  
if { "0" != $cost_center_id &&  "" != $cost_center_id } {
        lappend criteria_outer "
        	user_id in (select employee_id from im_employees where department_id in (select object_id from acs_object_context_index where ancestor_id = $cost_center_id))
	"
}

# Check for filter "Department"  

if { "0" != $department_id &&  "" != $department_id } {
  	lappend criteria_outer "
                user_id in (
                        select employee_id from im_employees where department_id in (
                                select
                                        object_id
                                from
                                        acs_object_context_index
                                where
                                        ancestor_id = $department_id
                	)
           	)
        "
}

# Create "outer where" 
if { ![empty_string_p $criteria_outer] } { 
   set outer_where [join $criteria_outer " and\n   "] 
} 
if {"" != $outer_where} { set outer_where "and $outer_where" }

# if {"" != $daily_hours && 0 != $daily_hours} {
#    set criteria_inner_sql "and h.hours > :daily_hours"
#} else {
#    set criteria_inner_sql "and 1=1"
#}


set day_placeholders ""
set day_header ""

db_foreach rec "select im_day_enumerator(to_date(:start_date,'yyyy-mm-dd'), to_date(:end_date_plus_one,'yyyy-mm-dd')) as r_date from dual" {
    
    set day_mm_dd "[string range $r_date 5 6][string range $r_date 8 9]"

    lappend inner_sql_list "sum((select sum(hours) from im_hours h where
            h.user_id = s.user_id
            and h.project_id in (
                select
                        children.project_id as subproject_id
                from
                        im_projects parent,
                        im_projects children
                where
                          tree_ancestor_key(children.tree_sortkey, 1) = parent.tree_sortkey
                        )
            and h.project_id = s.sub_project_id
            and date_trunc('day', day) = '$r_date'
        )) as day$day_mm_dd
    "
    lappend outer_sql_list "
        sum(CASE WHEN day$day_mm_dd <= $daily_hours THEN null ELSE day$day_mm_dd
        END) as day$day_mm_dd
    "
    append day_placeholders "\\" "\$day$day_mm_dd "

    set dow [clock format [clock scan $r_date] -format %w]
    if { 0 == $dow || 6 == $dow } {
        append day_header "\"<span style='color:#800000'>$day_mm_dd</span>\""
    } else {
        append day_header \"$day_mm_dd\"
    }
    append day_header " "
}


set inner_sql [join $inner_sql_list ", "]
set outer_sql [join $outer_sql_list ", "]

set sql "
	select
        	user_id,
		user_name,
	        top_parent_project_id,
		top_project_name,
		(select project_nr from im_projects where project_id = top_parent_project_id) as top_project_nr,
		sub_project_id,
		CASE WHEN t.sub_project_id = t.top_parent_project_id THEN NULL ELSE t.sub_project_name END as sub_project_name,
                CASE WHEN t.sub_project_id = t.top_parent_project_id THEN NULL ELSE t.sub_project_nr END as sub_project_nr,
	        $outer_sql
	from
        	(select
                	user_id,
	                user_name,
        	        s.top_parent_project_id,
                	(select project_name from im_projects where project_id = s.top_parent_project_id) as top_project_name,
                	(select project_nr from im_projects where project_id = s.top_parent_project_id) as top_project_nr,			
                        	 CASE
                                         WHEN s.project_type_id = 100 THEN
                                         (select project_name from im_projects where project_id = s.sub_project_id)
                                         ELSE
                                         s.sub_project_name
                                END as sub_project_name,
                                CASE
                                         WHEN s.project_type_id = 100 THEN
                                         (select project_nr from im_projects where project_id in (select parent_id from im_projects where project_id = s.sub_project_id))
                                         ELSE
                                         s.sub_project_nr
                                END as sub_project_nr,
                                CASE
                                         WHEN s.project_type_id = 100 THEN
                                         (select project_id from im_projects where project_id = s.sub_project_id)
                                         ELSE
                                         s.sub_project_id
                                END as sub_project_id,
			$inner_sql
        	from
                	(
			 select	distinct p.project_id, 
                	        u.user_id,
                        	im_name_from_user_id(u.user_id) as user_name,
	                        (select main_p.project_id from im_projects pr, im_projects main_p where pr.project_id = h.project_id and tree_ancestor_key(pr.tree_sortkey, 1) = main_p.tree_sortkey limit 1) as top_parent_project_id,
				p.project_name   as sub_project_name,
				p.project_id	 as sub_project_id,
				p.project_nr     as  sub_project_nr,
				p.project_type_id
		   	from
                        	im_hours h,
	                        im_projects p,
        	                users u
                	        LEFT OUTER JOIN
                        	        im_employees e
                                	on (u.user_id = e.employee_id)
	                where
        	                h.project_id = p.project_id
                	        and h.user_id = u.user_id
                        	and h.day >= to_date('$start_date', 'YYYY-MM-DD')
	                        and h.day < to_date('$end_date', 'YYYY-MM-DD')
        	                $where_clause
                	order by
                        	p.project_id,
	                        u.user_id
                	) s
		group by 
                	user_id,
	                user_name,
        	        top_parent_project_id,
                	top_project_name,
			project_type_id,
	                sub_project_id,
 			sub_project_nr,
        	        sub_project_name
	 ) t
	 where 
	       1=1
	       $outer_where
	 group by 
	 	user_id,
		user_name,
		top_parent_project_id,
		top_project_name,
		top_project_nr,
		sub_project_id,
		sub_project_name,
		sub_project_nr
	order by
              user_id,
	      top_parent_project_id
"

# This string represents a project/sub project
set line_str " \"\" \"<b><a href=\$project_url\$top_parent_project_id>\${top_project_nr} - \${top_project_name}</a></b>\" \"<b><a href=\$project_url\$sub_project_id>\${sub_project_nr} - \${sub_project_name}</a></b>\" "
append line_str $day_placeholders "\$number_hours_project_ctr" 

set no_empty_columns [expr $duration+1]

# -----------------------------------------------
# Define Report 
# -----------------------------------------------

# Evaluate first how many columns to show (needed to set header colspan) 
set day_columns ""
set ctr_day_cols 0 
db_foreach rec "select im_day_enumerator(to_date(:start_date,'yyyy-mm-dd'), to_date(:end_date_plus_one,'yyyy-mm-dd')) as r_date from dual" {
    set day_mm_dd "[string range $r_date 5 6][string range $r_date 8 9]"
    append day_columns "\"<strong>\$ts_hours_arr($day_mm_dd)</strong>\" " 
    incr ctr_day_cols 
}

set ctr_day_cols [expr $ctr_day_cols + 4] ; # Employee, Project, Sub-Project, Hours
# set reminder_url "notify-logged-hours?user_id=$user_id&start_date=$start_date&end_date=$end_date&return_url=[ns_urlencode "[ns_conn url]?[ns_conn query]"]"
# set reminder_link "<a href='$reminder_url'>[lang::message::lookup "" intranet-reporting.SendReminder "Send Reminder"]</a>"

set report_def 		[list group_by user_id header {"\#colspan=$ctr_day_cols <a href=$user_url$user_id>$user_name</a>" "<input name='user_id.$user_id' type='checkbox' value='on'>" } content]
lappend report_def 	[list group_by project_id header $line_str content {}]

set	tmp_footer	"\"<strong>Summary</strong>\" \"&nbsp;\" \"&nbsp;\" "
append 	tmp_footer 	$day_columns
append 	tmp_footer 	" \"<strong>\$number_hours_ctr_pretty</strong>\" "
lappend report_def      footer $tmp_footer

# Main Header
set header0 "\"Employee\" \"Project\" \"Sub-Project\" $day_header \"Hours\" \"Reminder\""
 
# Main Footer
set button "<input type=submit value='[lang::message::lookup "" intranet-reporting.SendReminder "Send Reminder"]'>" 
set footer0 [list] 
for {set i 0} {$i < $ctr_day_cols} {incr i} { lappend footer0 ""}
lappend footer0 $button

# ------------------------------------------------------------
# Start formatting the page
# ------------------------------------------------------------

# Write out HTTP header, considering CSV/MS-Excel formatting
im_report_write_http_headers -output_format $output_format -report_name "timesheet-monthly-hours-absences"

# Add the HTML select box to the head of the page
switch $output_format {
    html {
        ns_write "
		[im_header]
		[im_navbar]
		<table border=0 cellspacing=1 cellpadding=1>
		<tr>
		<td>
		<form>
			<table border=0 cellspacing=1 cellpadding=1>
			<tr>
				<td class=form-label>[_ intranet-core.Start_Date]</td>
				<td class=form-widget><input type=textfield name=start_date value=$start_date></td>
			</tr>
                	<tr>
				<td class=form-label>[_ intranet-core.End_Date]</td>
				<td class=form-widget><input type=textfield name=end_date value=$end_date></td>
			</tr>
	"
	ns_write "
                <!--
		<tr>
                  <td class=form-label>[_ intranet-core.Cost_Center]:</td>
                  <td class=form-widget>
		      [im_cost_center_select -include_empty 1  -department_only_p 0  cost_center_id $cost_center_id [im_cost_type_timesheet]]
                 </td>
		</tr>
		<tr>
                  <td class=form-label>[_ intranet-core.Department]:</td>
                  <td class=form-widget>
		      [im_cost_center_select -include_empty 1  -department_only_p 1  department_id $department_id [im_cost_type_timesheet]]
                 </td>
		</tr>
                -->
		<tr>
		  <td class=form-label>Employee</td>
		  <td class=form-widget>"
	# SysAdmins can see all users 
	if { [im_is_user_site_wide_or_intranet_admin $current_user_id]  } {
	    ns_write [im_employee_select_multiple user_id $user_id 8 multiple]		
	} else {
	    ns_write [im_employee_select_multiple -limit_to_direct_reports_of_user_id $current_user_id user_id $user_id 8 multiple]
	}
	ns_write "
		  </td>
		</tr>
                <!-- 
                <tr>
                  <td class=form-label>Customer</td>
                  <td class=form-widget>
                    [im_company_select customer_id $customer_id]
                  </td>
                </tr>
                <tr>
                <tr>
                  <td class=form-label>Project</td>
                  <td class=form-widget>
                    [im_project_select -include_empty_p 1 project_id $project_id]<br>
                     <input name=different_from_project_p type=checkbox $mm_value $mm_checked> [lang::message::lookup "" intranet-reporting.Exclude "Exclude selected project"]
                  </td>
                </tr>	    
                <tr>
                  <td class=form-label>Project Status</td>
                  <td class=form-widget>
 			[im_category_select -include_empty_p 1 "Intranet Project Status" project_status_id ""]
                  </td>
                </tr>
                <tr>
                  <td class=form-label>Daily hours</td>
                  <td class=form-widget>
			<select name='daily_hours'>
	   "
	if {0==$daily_hours || ""==$daily_hours } {ns_write " <option selected value='0'>all</option>"} else {ns_write "<option value='0'>all</option>" }
	for {set ctr 2} {$ctr < 9} {incr ctr} {
	    if { "$ctr"==$daily_hours } {ns_write " <option selected value='$ctr'>>$ctr hours</option>"} else {ns_write "<option value='$ctr'>>$ctr hours</option>" }
	}
	
	ns_write "
			</select>
                  </td>
                </tr>
                <tr>
                  <td class=form-label>Format</td>
                  <td class=form-widget>
                    [im_report_output_format_select output_format "" $output_format]
                  </td>
                </tr>
		-->"
	ns_write "
  		 <tr>
		  <td class=form-label></td>
		  <td class=form-widget><input type=submit value=Submit></td>
		</tr>
		</table>
		</form>
		<br><br>
	</td>
	<td>&nbsp;&nbsp;&nbsp;&nbsp;</td>
	<td valign='top' width='600px'>
	    	<ul>
			<li>Report shows max two project/task levels. Hours tracked on projects and tasks of lower level will be accumulated</li>
	        	<li>Report never shows ABSENCE entries for Saturday and Sunday</li>
			<li>Report assumes that absences with duration > 1 day are always \"Full day\" absences</li>
			<li>For partial absences to be considered correctly, start date and end date of an absence need to be equal</li>
		</ul>
	</td>
	</tr>
	</table>"

	# Ad form for bulk reminders 
	ns_write "<form action='notify-logged-hours'>"
	set return_url [ns_urlencode "[ns_conn url]?[ns_conn query]"]
	set export_vars [export_form_vars return_url start_date end_date]
	ns_write $export_vars
        ns_write "<table border=0 cellspacing=5 cellpadding=5>\n"
    }
}

im_report_render_row \
    -output_format $output_format \
    -row $header0 \
    -row_class "rowtitle" \
    -cell_class "rowtitle"

set footer_array_list [list]
set absence_array_list [list]

set last_value_list [list]
set class "rowodd"

set number_days_ctr 0
set number_days_counter [list \
       pretty_name "Number days" \
       var number_days_ctr_pretty \
       reset \$user_id \
       expr "\$number_days_ctr+0" \
]

set counters [list $number_days_counter ]
 
#------------------------
# Initialize
#------------------------ 

set saved_user_id 0
set number_hours_project_ctr 0

# ns_return 1 text/html "start_date: $start_date, end_date_plus_one: $end_date_plus_one"
#ad_return_complaint xx ee
db_foreach rec "select im_day_enumerator(to_date(:start_date,'yyyy-mm-dd'), to_date(:end_date_plus_one,'yyyy-mm-dd')) as r_date from dual" {
	set day_mm_dd "[string range $r_date 5 6][string range $r_date 8 9]"
	set month_arr($day_mm_dd) 0
	set ts_hours_arr($day_mm_dd) ""
}

#------------------------
# Writing Report 
#------------------------

db_foreach sql $sql {
        set number_days_ctr 0
        set number_hours_ctr 0

	im_report_display_absences \
	    -output_format $output_format \
	    -group_def $report_def \
	    -footer_array_list $absence_array_list \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class

	im_report_display_footer \
	    -output_format $output_format \
	    -group_def $report_def \
	    -footer_array_list $footer_array_list \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class

        set number_hours_project_ctr 0

	if { $user_id != $saved_user_id } {
	    # Next user - write totals  
	    set saved_user_id $user_id

	    # reset counters  
	    db_foreach rec "select im_day_enumerator(to_date(:start_date,'yyyy-mm-dd'), to_date(:end_date_plus_one,'yyyy-mm-dd')) as r_date from dual" {
		set day_mm_dd "[string range $r_date 5 6][string range $r_date 8 9]"
	        set month_arr($day_mm_dd) 0
		set ts_hours_arr($day_mm_dd) ""
 	   	set number_hours_ctr_pretty 0
	    }
	    
	    array unset absence_arr 

	    # Get absences for this user - setting absence_arr 

	    if {$debug} { ns_log NOTICE "timesheet-monthly-hours-absences::get-absences: new_value: $new_value" }
	    set sql "select * from im_absences_get_absences_for_user_duration(:user_id, :start_date, :end_date, null) AS (absence_date date, absence_type_id int, absence_id int, duration_days numeric)"
	    db_foreach col $sql {
		set days $absence_date
		if {$debug} { ns_log NOTICE "timesheet-monthly-hours-absences::switch_user - setting absence_arr($days)" }
		set duration_absence_type_list [list $duration_days [im_category_from_id $absence_type_id]]
		if { [info exists absence_arr($days)] } {
		    set absence_arr($days) [lappend absence_arr($days) $duration_absence_type_list]
		} else {
		    set absence_arr($days) "{$duration_absence_type_list}"
		}
		if {$debug} { ns_log NOTICE "timesheet-monthly-hours-absences::new absence_arr($days): $absence_arr($days)" }
	    }

	    db_foreach rec "select im_day_enumerator(to_date(:start_date,'yyyy-mm-dd'), to_date(:end_date_plus_one,'yyyy-mm-dd')) as r_date from dual" {
		set day_mm_dd "[string range $r_date 5 6][string range $r_date 8 9]"
		set date_ansi_key $r_date
                if { [info exists absence_arr($date_ansi_key)] } {
                    ns_log NOTICE "timesheet-monthly-hours-absences::switch_user - new User: $user_id - found absence for key: $date_ansi_key"
                    # Evaluate absence amount
                    # absence_arr($date_ansi_key) is list of lists
                    set total_absence 0
                    foreach absence_list_item $absence_arr($date_ansi_key) {
                        # Absences are stored as days/fractions of a day
                        # Evaluate total absence in UoM: 'Hours'
                        if { 1 < [expr [lindex $absence_list_item 0] + 0] } {
                            # We assume that absences with a total (total_days) > 1 are always full day absences
                            set total_absence [expr $total_absence + $timesheet_hours_per_day]
                        } else {
                            # Single absences might be fraction of day
                            set total_absence [expr [expr $timesheet_hours_per_day + 0] * [expr [lindex $absence_list_item 0]]]
                        }
                    }

		    # Preset ts_hours_arr with absence
		    set ts_hours_arr($day_mm_dd) $total_absence
		    
		    # Number hours total per user & period 
		    set number_hours_ctr_pretty [expr $number_hours_ctr_pretty + $total_absence]

		    ns_log NOTICE "timesheet-monthly-hours-absences::switch_user - Found total_absence: $total_absence"
		}
	    }
	    # Convert to list in order pass on as parameter 
	    set absences_list [array get absence_arr]
	}	

	# Formating and row totals 
	db_foreach rec "select im_day_enumerator(to_date(:start_date,'yyyy-mm-dd'), to_date(:end_date_plus_one,'yyyy-mm-dd')) as r_date from dual" {
	    set day_mm_dd "[string range $r_date 5 6][string range $r_date 8 9]"
	    # Building totals for each row
	    set sql_var "day$day_mm_dd"
	    if { "" != [expr $$sql_var] } {
		set ts_hours_arr($day_mm_dd) [expr $ts_hours_arr($day_mm_dd) + [expr $$sql_var] ]
		set number_hours_project_ctr [expr $number_hours_project_ctr + [expr $$sql_var] ] 
	        set number_hours_ctr_pretty [expr $number_hours_ctr_pretty + [expr $$sql_var] ]
		if { 0 == $month_arr($day_mm_dd) } {
		    set month_arr($day_mm_dd) 1
		    set number_hours_ctr [expr $number_hours_ctr + $ts_hours_arr($day_mm_dd)] 
		}
	    }
	}

	im_report_update_counters -counters $counters

	set last_value_list [im_report_render_header \
	    -output_format $output_format \
	    -group_def $report_def \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class
        ]
	
        set absence_array_list [im_report_render_absences \
	    -output_format $output_format \
	    -group_def $report_def \
	    -last_value_array_list $last_value_list \
	    -start_date $start_date \
            -end_date $end_date \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class \
	    -absences_list $absences_list
        ]

        set footer_array_list [im_report_render_footer \
	    -output_format $output_format \
	    -group_def $report_def \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class 
        ]
}


im_report_display_absences \
       -output_format $output_format \
       -group_def $report_def \
       -footer_array_list $absence_array_list \
       -last_value_array_list $last_value_list \
       -level_of_detail $level_of_detail \
       -display_all_footers_p 1\
       -row_class $class \
       -cell_class $class

im_report_display_footer \
    -output_format $output_format \
    -group_def $report_def \
    -footer_array_list $footer_array_list \
    -last_value_array_list $last_value_list \
    -level_of_detail $level_of_detail \
    -display_all_footers_p 1 \
    -row_class $class \
    -cell_class $class

# Show footer row (Button)
 im_report_render_row \
    -output_format $output_format \
    -row $footer0 \
    -row_class $class \
    -cell_class $class

switch $output_format {
    html { ns_write "</table>\n</form>\n[im_footer]\n" }
    cvs { }
}

