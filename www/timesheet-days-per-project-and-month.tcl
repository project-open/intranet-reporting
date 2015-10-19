# /packages/intranet-reporting/www/timesheet-days-per-project-and-month.tcl
#
# Copyright (C) 2003 - 2015 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/ for licensing details.


ad_page_contract {
	testing reports	
    @param start_year Year to start the report
    @param start_unit Month or week to start within the start_year
} {
    { start_date "" }
    { level_of_detail 3 }
    { output_format "html" }
    { user_id "" }
    { project_id ""}
    { cost_center_id ""}
}

# ------------------------------------------------------------
# Security
# ------------------------------------------------------------

# Label: Provides the security context for this report
# because it identifies unquely the report's Menu and
# its permissions.
set menu_label "reporting-timesheet-days-per-project-and-month"
set current_user_id [ad_maybe_redirect_for_registration]
set read_p [db_string report_perms "
	select	im_object_permission_p(m.menu_id, :current_user_id, 'read')
	from	im_menus m
	where	m.label = :menu_label
" -default 'f']
set read_p "t"
if {![string equal "t" $read_p]} {
    ad_return_complaint 1 "<li>
    [lang::message::lookup "" intranet-reporting.You_dont_have_permissions "You don't have the necessary permissions to view this page"]"
    ad_script_abort
}

set page_title "Timesheet Reported Days per Project and Month"
set context_bar [im_context_bar $page_title]
set context ""


# Check that Start-Date have correct format
set start_date [string range $start_date 0 6]
if {"" != $start_date && ![regexp {^[0-9][0-9][0-9][0-9]\-[0-9][0-9]$} $start_date]} {
    ad_return_complaint 1 "Start Date doesn't have the right format.<br>
    Current value: '$start_date'<br>
    Expected format: 'YYYY-MM'"
}


# ------------------------------------------------------------
# Defaults
# ------------------------------------------------------------

set days_in_past 365
db_1row todays_date "
select
	to_char(sysdate::date - :days_in_past::integer, 'YYYY') as todays_year,
	to_char(sysdate::date - :days_in_past::integer, 'MM') as todays_month
from dual
"

if {"" == $start_date} { 
    set start_date "$todays_year-$todays_month"
}

set internal_company_id [im_company_internal]
set company_url "/intranet/companies/view?company_id="
set project_url "/intranet/projects/view?project_id="
set user_url "/intranet/users/view?user_id="
set this_url [export_vars -base "/intranet-reporting/timesheet-days-per-project-and-month" {start_date} ]
set levels {1 "User Only" 2 "User+Company" 3 "User+Company+Project" 4 "All Details"} 
set num_format "999,990.99"


# ------------------------------------------------------------
# Conditional SQL Where-Clause
#

set criteria [list]

if {"" != $project_id && 0 != $project_id} {
    lappend criteria "p.project_id = :project_id"
}

if {[info exists user_id] && 0 != $user_id && "" != $user_id} {
    lappend criteria "h.user_id = :user_id"
}

if { [info exists cost_center_id] && 0 != $cost_center_id && "" != $cost_center_id && 525 != $cost_center_id } {
    lappend criteria "e.department_id = :cost_center_id"
}

set where_clause [join $criteria " and\n            "]
if { ![empty_string_p $where_clause] } {
    set where_clause " and $where_clause"
}


# ------------------------------------------------------------
# Define the list of months to display
#


# ------------------------------------------------------------
# Define the report - SQL, counters, headers and footers 
#
set sql "
	select	e.employee_id as user_id,
		e.job_title,
		cc.cost_center_code,
		cc.cost_center_name,
		im_name_from_user_id(e.employee_id) as user_name,
		main_p.project_id as main_project_id,
		main_p.project_name as main_project_name,
		(select sum(h.hours) from im_hours h where 
			h.project_id = sub_p.project_id and h.user_id = e.employee_id and 
			h.day between '2015-01-01' and '2015-01-31'
		) as h2015_01
	from	im_projects main_p,
		im_projects sub_p,
		im_employees e,
		im_cost_centers cc
	where	
		main_p.tree_sortkey = tree_root_key(sub_p.tree_sortkey) and
		e.department_id = cc.cost_center_id
        	$where_clause
	order by 
	        user_name,
		main_project_name
"

set report_def [list \
    group_by user_id \
    header {
	"\#colspan=99 <b><a href=$user_url$user_id>$user_name</a></b>"
    } \
        content [list \
            group_by main_project_id \
            header {
                "\#colspan=1 "
		"\#colspan=99 <b><a href=$project_url$main_project_id>$main_project_name</a></b>"
            } \
		     content [list \
				  header {
				      $user_name
				      $cost_center_name
				      $job_title
				      $main_project_name
				      $h2015_01
				  } \
				  content {} \
				 ] \
		     footer {
			 "#colspan=99"
		     } \
	] \
	footer {
		"#colspan=99 Summary"
	} \
]


# Global header/footer
set header0 {"Project" "Employee" "01" "02" "03" "04" "05" "06" "07" "08" "09" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21" "22" "23" "24" "25" "26" "27" "28" "29" "30" "31" "% of <br>total hours<br>logged by user<br>this month"}
set footer0 {"" "" "" "" "" "" "" "" ""}


# ------------------------------------------------------------
# Start formatting the page
#

# Write out HTTP header, considering CSV/MS-Excel formatting
im_report_write_http_headers -output_format $output_format

# Add the HTML select box to the head of the page
switch $output_format {
    html {
        ns_write "
	[im_header]
	[im_navbar]
	<form>
		<table border=0 cellspacing=1 cellpadding=1>
		<tr>
		  <td class=form-label>Start-Month (YYYY-MM)</td>
		  <td class=form-widget>
		    <input type=textfield name=start_date value=$start_date>
		  </td>
		</tr>
		<tr>
		  <td class=form-label>User</td>
		  <td class=form-widget>
		    [im_user_select -include_empty_p 1 user_id $user_id]
		  </td>
		</tr>
                <tr>
                  <td class=form-label>Project</td>
                  <td class=form-widget>
                    [im_project_select project_id $project_id]
                  </td>
                </tr>
                <tr>
                  <td class=form-label>Department</td>
                  <td class=form-widget>
                    [im_cost_center_select cost_center_id $cost_center_id]
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
	</form>
	<table border=0 cellspacing=1 cellpadding=1>\n"
    }
}

im_report_render_row \
    -output_format $output_format \
    -row $header0 \
    -row_class "rowtitle" \
    -cell_class "rowtitle"


set footer_array_list [list]
set last_value_list [list]
set class "rowodd"
db_foreach sql $sql {

	im_report_display_footer \
	    -output_format $output_format \
	    -group_def $report_def \
	    -footer_array_list $footer_array_list \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class
	
#	im_report_update_counters -counters $counters
	

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
}

