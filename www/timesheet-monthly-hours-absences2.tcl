# /packages/intranet-reporting/www/timesheet-monthly-hours-absences.tcl
#
# Copyright (C) 2003 - 2012 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/ for licensing details.

ad_page_contract {
    @param start_year Year to start the report
    @param start_unit Month or week to start within the start_year
} {
    { report_year_month "" }
    { level_of_detail 3 }
    { output_format "html" }
    { report_user_id 0 }
    { daily_hours 0 }
    { different_from_project_p "" }
    { report_cost_center_id 0 }
}

# ------------------------------------------------------------
# Security & Permissions
# ------------------------------------------------------------

# Label: Provides the security context for this report
set menu_label "timesheet-monthly-hours-absences"
set current_user_id [auth::require_login]
set read_p [db_string report_perms "
	select	im_object_permission_p(m.menu_id, :current_user_id, 'read')
	from	im_menus m
	where	m.label = :menu_label
" -default 'f']

if {"t" ne $read_p } {
    ad_return_complaint 1 "<li>
    [lang::message::lookup "" intranet-reporting.You_dont_have_permissions "You don't have the necessary permissions to view this page"]"
    return
}


# ------------------------------------------------------------
# Validate 
# ------------------------------------------------------------

# Check that Start-Date have correct format
set report_year_month [string range $report_year_month 0 6]
if {"" != $report_year_month && ![regexp {^[0-9][0-9][0-9][0-9]\-[0-9][0-9]$} $report_year_month]} {
    ad_return_complaint 1 "Start Date doesn't have the right format.<br>
    Current value: '$report_year_month'<br>
    Expected format: 'YYYY-MM'"
}


# ------------------------------------------------------------
# Defaults
# ------------------------------------------------------------
set debug 0
set date_format "YYYY-MM-DD"
set num_format "999,990.99"

set view_hours_all_p [im_permission $current_user_id view_hours_all]
if { [im_is_user_site_wide_or_intranet_admin $current_user_id] } { set view_hours_all_p 1 }

set timesheet_hours_per_day [parameter::get -package_id [apm_package_id_from_key intranet-timesheet2] -parameter "TimesheetHoursPerDay" -default 8]

set page_title [lang::message::lookup "" intranet-reporting.TimesheetMonthlyViewIncludingAbsences "Timesheet - Monthly View including Absences"]
set context_bar [im_context_bar $page_title]
set context ""
set todays_date [db_string todays_date "select to_char(now(), :date_format) from dual" -default ""]

if { $report_year_month eq "" } {
    set report_year_month "[string range $todays_date 0 3]-[string range $todays_date 5 6]"
}    

set report_year [string range $report_year_month 0 3]
set report_month [string range $report_year_month 5 6 ]

set first_day_of_month "$report_year-$report_month-01"
set first_day_next_month [string range [db_string get_number_days_month "SELECT '$first_day_of_month'::date + '1 month'::interval" -default 0] 0 9 ]

set report_year_month_days_in_month [db_string get_number_days_month "SELECT date_part('day','$first_day_of_month'::date + '1 month'::interval - '1 day'::interval)" -default 0]

set project_url "/intranet/projects/view?project_id="
set absence_url "/intranet-timesheet2/absences/new?form_mode=display&absence_id="
set user_url "/intranet/users/view?user_id="
set this_url "[export_vars -base "/intranet-reporting/timesheet-monthly-hours-absences2" {} ]?"



# If privilige "view_hours_all_p" is not set, show only the users "own" hours
if {!$view_hours_all_p} {
    set report_user_id $current_user_id
}

set absence_l10n [lang::message::lookup "" intranet-timesheet2.Absence "Absence"]


# ------------------------------------------------------------
# Conditional SQL Where-Clause
#
 
if {$different_from_project_p eq ""} {
   set mm_checked ""
   set mm_value  ""
} else {
   set mm_checked "checked"
   set mm_value  "value='on'"
}

set criteria [list]

if {0 ne $report_user_id && "" ne $report_user_id} {
    lappend criteria "u.user_id = :report_user_id"
}

if {"" != $report_cost_center_id && 0 != $report_cost_center_id} {
    lappend criteria "u.user_id in (
		select	eee.employee_id
		from	im_employees eee
		where	eee.department_id in ([join [im_sub_cost_center_ids $report_cost_center_id] ","])
	)"
} 


# Put everything together
set where_clause [join $criteria " and\n            "]
if {$where_clause ne ""} { set where_clause " and $where_clause" }

# ad_return_complaint 1 $where_clause


# ------------------------------------------------------------
# Define the report - SQL, counters, headers and footers 
#

set inner_sql "
    	-- Hours on the 2nd level Work packages and below
	select	u.user_id,
		p.project_id as object_id,
		:project_url as object_url,
		p.project_name as object_name,
		h.day::date as day,
		h.hours
	from	users u,
		im_projects main_p,
		im_projects p,
		im_projects task,
		im_hours h
	where	main_p.parent_id is null and
		p.parent_id = main_p.project_id and
		task.tree_sortkey between p.tree_sortkey and tree_right(p.tree_sortkey) and
		h.user_id = u.user_id and
		h.project_id = task.project_id
		$where_clause

UNION

    	-- Hours logged on the main project only (no on anything below)
	select	u.user_id,
		main_p.project_id as object_id,
		:project_url as object_url,
		main_p.project_name as object_name,
		h.day::date as day,
		h.hours
	from	users u,
		im_projects main_p,
		im_hours h
	where	main_p.parent_id is null and
		h.project_id = main_p.project_id and
		h.user_id = u.user_id
		$where_clause

UNION

    	-- Hours due to absences
	select	t.user_id,
		t.absence_id as object_id,
		:absence_url as object_url,
		:absence_l10n || ': ' || t.absence_name as object_name,
		t.im_day_enumerator as day,
		8.0 * t.availability / 100.0 * t.duration_days * 100.0 / (0.000000001 + abs(t.day_percentages)) as hours
	from	(
		select	u.user_id,
			ua.absence_id, 
			ua.absence_name, 
			ua.start_date::date, 
			ua.end_date::date, 
			im_day_enumerator(ua.start_date::date, ua.end_date::date+1),
			ua.duration_days,
			(select sum(unnest) from unnest(im_resource_mgmt_work_days(ua.owner_id, ua.start_date::date, ua.end_date::date))) as day_percentages,
			(select availability from im_employees where employee_id = ua.owner_id) as availability
		from	im_user_absences ua,
			users u
		where	ua.owner_id = u.user_id and
			(to_char(ua.start_date, 'YYYY-MM') = :report_year_month or to_char(ua.end_date, 'YYYY-MM') = :report_year_month)
			$where_clause

		) t
"
# ad_return_complaint 1 [im_ad_hoc_query -format html $inner_sql]



set hours_per_day_case ""
set hours_per_day_aggregate ""
for {set d 1} {$d <= $report_year_month_days_in_month} {incr d} {
    append hours_per_day_case ", CASE WHEN extract(day from t.day) = $d THEN t.hours ELSE null END as day_$d\n"
    append hours_per_day_aggregate ", round(sum(day_$d)::numeric,1) as hours_$d\n"
}

set sql "
	select	t.user_id,
		t.object_id,
		t.object_url,
		t.object_name,
		im_name_from_user_id(user_id) as user_name
		$hours_per_day_aggregate
	from
		(select	t.user_id,
			t.object_id,
			t.object_url,
			t.object_name
			$hours_per_day_case
		from	($inner_sql) t
		where	to_char(t.day, 'YYYY-MM') = :report_year_month
		) t
	group by
		t.user_id,
		t.object_url,
		t.object_name,
		t.object_id
	order by
		acs_object__name(user_id),
		object_url,
		coalesce(object_id, 999999999999999)

"
# ad_return_complaint 1 [im_ad_hoc_query -format html $sql]



# -----------------------------------------------
# Define Report 
# -----------------------------------------------

# Global Header
set header0 {
	"User"
	"Project"
}

# Main content line
set project_vars {
	""
	"<nobr><a href='$object_url$object_id'>$object_name</a></nobr>"
}


set user_header {
	"\#colspan=44 <a href=$this_url&user_id=$user_id&level_of_detail=3
	target=_blank><img src=/intranet/images/plus_9.gif width=9 height=9 border=0></a> 
	<b><a href=$user_url$user_id>$user_name</a></b>"
}

set user_footer {
    "" 
    ""
}


# Add rows for days
set counters [list]
for {set d 1} {$d <= $report_year_month_days_in_month} {incr d} {
    lappend header0 "Day $d"
    lappend project_vars "\$hours_$d"

    set counter [list \
    	pretty_name "Hours day_$d" \
	var hours_${d}_subtotal \
	reset \$user_id \
	expr "\$hours_${d}+0" \
    ]
    lappend counters $counter
    lappend user_footer "<b>\$hours_${d}_subtotal</b>"
}


# Disable project headers for CSV output
# in order to create one homogenous exportable  lst
if {"csv" == $output_format} { set project_header "" }

# The entries in this list include <a HREF=...> tags
# in order to link the entries to the rest of the system (New!)
#
set report_def [list \
    group_by user_id \
    header $user_header \
    content [list \
	group_by object_id \
	header $project_vars \
	content {} \
    ] \
    footer $user_footer \
]

# Global Footer Line
set footer0 {}

# ------------------------------------------------------------
# Start formatting the page
#

# Write out HTTP header, considering CSV/MS-Excel formatting
im_report_write_http_headers -output_format $output_format -report_name "timesheet-monthly-hours-absences"

# Add the HTML select box to the head of the page
switch $output_format {
    html {
        ns_write "
		[im_header]
		[im_navbar reporting]
		<table border=0 cellspacing=1 cellpadding=1>
		<tr>
		<td>
		<form>
			<table border=0 cellspacing=1 cellpadding=1>
			<tr>
			  <td class=form-label>Month</td>
			  <td class=form-widget>
			    <input type=textfield name='report_year_month' value='$report_year_month'>
			  </td>
			</tr>
	"

	if { $view_hours_all_p } {
	    ns_write "
		<tr>
                  <td class=form-label>[_ intranet-core.Department]:</td>
                  <td class=form-widget>
		      [im_cost_center_select -include_empty 1 -include_empty_name "All" -department_only_p 0  -show_inactive_cc_p 1  report_cost_center_id $report_cost_center_id]
                 </td>
		</tr>
		<tr>
		  <td class=form-label>Employee</td>
		  <td class=form-widget>
		    [im_user_select -include_empty_p 1 report_user_id $report_user_id]
		  </td>
		</tr>
                <tr>
                  <td class=form-label>Format</td>
                  <td class=form-widget>
                    [im_report_output_format_select output_format "" $output_format]
                  </td>
                </tr>
  		 <tr>
		  <td class=form-label></td>
		  <td class=form-widget><input type=submit value=Submit></td>
		</tr>
		</table>
		<br><br>
	</form>
	</td>
	<td>&nbsp;&nbsp;&nbsp;&nbsp;</td>
	<td valign='top' width='600px'>
	    	<ul>
			<li>Report shows max two project/task levels. Hours tracked on projects and tasks of lower level will be accumulated</li>
	        	<li>Report never shows absence entries for Saturday and Sunday</li>
			<li>Report assumes that absences with duration > 1 day are always \"Full day\" absences</li>
			<li>For partial absences to be considered correctly, start date and end date of an absence need to be equal</li>
		</ul>
	</td>
	</tr>
	</table>
	<table border=0 cellspacing=5 cellpadding=5>\n
	"
	}
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

 
#------------------------
# Initialize
#------------------------ 

db_foreach sql $sql {

    if {"" eq $object_name} { set object_name "undefined" }

	im_report_display_footer \
	    -output_format $output_format \
	    -group_def $report_def \
	    -footer_array_list $footer_array_list \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class

	im_report_update_counters -counters $counters

	set last_value_list [im_report_render_header \
	    -output_format $output_format \
	    -group_def $report_def \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class
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

im_report_display_footer \
    -output_format $output_format \
    -group_def $report_def \
    -footer_array_list $footer_array_list \
    -last_value_array_list $last_value_list \
    -level_of_detail $level_of_detail \
    -display_all_footers_p 1 \
    -row_class $class \
    -cell_class $class

im_report_render_row \
    -output_format $output_format \
    -row $footer0 \
    -row_class $class \
    -cell_class $class


switch $output_format {
    html { ns_write "</table>\n[im_footer]\n" }
    cvs { }
}

