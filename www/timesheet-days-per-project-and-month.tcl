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
    { end_date "" }
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
set current_user_id [auth::require_login]
set read_p [db_string report_perms "
	select	im_object_permission_p(m.menu_id, :current_user_id, 'read')
	from	im_menus m
	where	m.label = :menu_label
" -default 'f']
set read_p "t"
if {"t" ne $read_p } {
    ad_return_complaint 1 "<li>
    [lang::message::lookup "" intranet-reporting.You_dont_have_permissions "You don't have the necessary permissions to view this page"]"
    ad_script_abort
}

set page_title "Timesheet Reported Days per Project and Month"
set context_bar [im_context_bar $page_title]
set context ""


# Check that Start-Date have correct format
set start_date [string range $start_date 0 9]
if {"" != $start_date && ![regexp {^[0-9][0-9][0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]$} $start_date]} {
    ad_return_complaint 1 "Start Date doesn't have the right format.<br>
    Current value: '$start_date'<br>
    Expected format: 'YYYY-MM'"
}

set end_date [string range $end_date 0 9]
if {"" != $end_date && ![regexp {^[0-9][0-9][0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]$} $end_date]} {
    ad_return_complaint 1 "End Date doesn't have the right format.<br>
    Current value: '$end_date'<br>
    Expected format: 'YYYY-MM'"
}


# ------------------------------------------------------------
# Defaults
# ------------------------------------------------------------

set days_in_past 365
db_1row todays_date "
select
	to_char(sysdate::date, 'YYYY') as todays_year,
	to_char(sysdate::date, 'MM') as todays_month,
	to_char(sysdate::date - '1 year'::interval + '1 month'::interval, 'YYYY') as start_year,
	to_char(sysdate::date - '1 year'::interval + '1 month'::interval, 'MM') as start_month
from dual
"

if {"" == $start_date & "" == $end_date} {
    set end_date [db_string end_date "select ('$todays_year-$todays_month-01'::date + '1 month'::interval - '1 day'::interval)::date"]
    set start_date [db_string start_date "select to_char(:end_date::date - '1 year'::interval + '1 month'::interval, 'YYYY-MM-DD')"]
}

if {"" == $start_date} { set start_date "$start_year-$start_month-01" }
if {"" == $end_date} { set end_date [db_string end_date "select ('$todays_year-$todays_month-01'::date + '1 month'::interval - '1 day'::interval)::date"] }

set internal_company_id [im_company_internal]
set company_url "/intranet/companies/view?company_id="
set project_url "/intranet/projects/view?project_id="
set user_url "/intranet/users/view?user_id="
set this_url [export_vars -base "/intranet-reporting/timesheet-days-per-project-and-month" {start_date} ]
set levels {2 "Users" 3 "Users and Projects"} 
set num_format "999,990.99"
set hours_per_day [parameter::get_from_package_key -package_key intranet-timesheet2-tasks -parameter "TimesheetHoursPerDay" -default 8]


# ------------------------------------------------------------
# Conditional SQL Where-Clause
#

set criteria [list]

if {"" != $project_id && 0 != $project_id} {
    lappend criteria "main_p.project_id = :project_id"
}

if {[info exists user_id] && 0 != $user_id && "" != $user_id} {
    lappend criteria "h.user_id = :user_id"
}

if { [info exists cost_center_id] && 0 != $cost_center_id && "" != $cost_center_id && [im_cost_center_company] != $cost_center_id } {
    set cost_center_code [db_string cc_code "select cost_center_code from im_cost_centers where cost_center_id = :cost_center_id" -default ""]
    lappend criteria "h.user_id in (
		select	e.employee_id
		from	im_employees e
		where	e.department_id in (
			select	cc.cost_center_id
			from	im_cost_centers cc
			where	position(:cost_center_code in cc.cost_center_code) > 0
			)
	)"
}

set where_clause [join $criteria " and\n            "]
if { $where_clause ne "" } {
    set where_clause " and $where_clause"
}



# ------------------------------------------------------------
#
if {![regexp {^(....)-(..)-(..)$} $start_date match year_start month_start]} {
    ad_return_complaint 1 "Error parsing start_date='$start_date'"
}
if {![regexp {^(....)-(..)-(..)$} $end_date match year_end month_end]} {
    ad_return_complaint 1 "Error parsing end_date='$end_date'"
}

set month_start [scan $month_start %d]
set month_end [scan $month_end %d]




# ------------------------------------------------------------
# List of months to report on
#
set months [list]
set year $year_start
set month $month_start
set select_sum_sql ""
set report_line_specs {$user_name $cost_center_name $job_title $project_name }
set report_footer_specs {"" "" "" ""}
set header0 {"User" "Department" "Job Title" "Project"}
set footer0 {}
set first_month ""

# ad_return_complaint 1 "$year_end - $month_end<br>$year_start - $month"

for {set i 0} {[expr {$year * 12 + $month}] <= [expr {$year_end * 12 + $month_end}]} {incr i} {
    if {$month > 12} {
	set month 1
	incr year
    }
    set month_formatted $month
    if {[string length $month_formatted] < 2} { set month_formatted "0$month_formatted" }

    # Start building lists of things per month
    if {"" == $first_month} { set first_month "$year-$month" }
    lappend months "${year}-${month_formatted}"

    set interval_end_date [db_string interval_end "select ('$year-$month-01'::date + '1 month'::interval - '1 day'::interval)::date from dual"]
    append select_sum_sql "\t\t,round(sum(
    	   CASE WHEN h.day between '$year-$month-01' and '$interval_end_date'
	   THEN h.hours ELSE 0 END) / :hours_per_day,1) as h${year}_${month_formatted}"
    lappend report_line_specs "\$h${year}_${month_formatted}"
    lappend report_footer_specs "<b>\$h${year}_${month_formatted}_subtotal</b>"
    lappend header0 "${year}<br>-${month_formatted}"
    lappend counters [list \
        pretty_name "Hours $year-$month_formatted" \
	var "h${year}_${month_formatted}_subtotal" \
        reset \$user_id \
	expr "\$h${year}_${month_formatted}" \
    ]

    incr month
}

lappend report_line_specs "<b>\$htotal</b>"
lappend header0 "Total"
append select_sum_sql "\t\t,round(sum(
	CASE WHEN h.day between '$first_month-01' and '$interval_end_date'
	THEN h.hours ELSE 0 END) / :hours_per_day,1) as htotal"

lappend counters [list \
        pretty_name "Hours Total Subtotal" \
	var "htotal_subtotal" \
        reset \$user_id \
	expr "\$htotal" \
]
lappend report_footer_specs "<b>\$htotal_subtotal</b>"

# Select out all hours and 
set inner_sql "
	select	h.user_id,
		main_p.project_id
		$select_sum_sql
	from	im_projects main_p,
		im_projects sub_p,
		im_hours h
	where	h.project_id = sub_p.project_id and
		main_p.tree_sortkey = tree_root_key(sub_p.tree_sortkey)
		$where_clause
	group by
		h.user_id,
		main_p.project_id
"

set sql "
	select	t.*,
		e.job_title,
		e.employee_id as user_id,
		im_name_from_user_id(e.employee_id) as user_name,
		cc.cost_center_code,
		cc.cost_center_name,
		acs_object__name(t.project_id) as project_name
	from	($inner_sql) t,
		im_employees e,
		im_cost_centers cc
	where	t.user_id = e.employee_id and
		e.department_id = cc.cost_center_id
	order by
	        user_name,
		project_name
"



set report_def [list \
    group_by user_id \
    header {
	"\#colspan=99 <b><a href=$user_url$user_id>$user_name</a></b>"
    } \
    content [list \
            group_by project_id \
            header {} \
	    content [list \
		header $report_line_specs \
		content {} \
	    ] \
	    footer {} \
    ] \
    footer $report_footer_specs \
]

# ------------------------------------------------------------
# Start formatting the page
#

# Write out HTTP header, considering CSV/MS-Excel formatting
im_report_write_http_headers -output_format $output_format -report_name "timesheet-days-per-project-and-month.csv"


# Add the HTML select box to the head of the page
switch $output_format {
    html {
        ns_write "
	[im_header]
	[im_navbar]
	<table border=0 'width=100%' cellspacing=10 cellpadding=10>
	<tr><td>
	<form>
		<table border=0 cellspacing=1 cellpadding=1>
		<tr>
		  <td class=form-label>[lang::message::lookup "" intranet-reporting.LevelOfDetails "Level of Details"]</td>
		  <td class=form-widget>
		    [im_select -translate_p 0 level_of_detail $levels $level_of_detail]
		  </td>
		</tr>
		<tr>
		  <td class=form-label>Start</td>
		  <td class=form-widget>
		    <input type=textfield name=start_date value=$start_date>
		  </td>
		</tr>
		<tr>
		  <td class=form-label>End</td>
		  <td class=form-widget>
		    <input type=textfield name=end_date value=$end_date>
		  </td>
		</tr>
		<tr>
		  <td class=form-label>User</td>
		  <td class=form-widget>
		    [im_user_select -include_empty_p 1 -include_empty_name "" user_id $user_id]
		  </td>
		</tr>
                <tr>
                  <td class=form-label>Project</td>
                  <td class=form-widget>
                    [im_project_select -include_empty_p 1 project_id $project_id]
                  </td>
                </tr>
                <tr>
                  <td class=form-label>Department</td>
                  <td class=form-widget>
                    [im_cost_center_select -include_empty 1 cost_center_id $cost_center_id]
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
	</td><td valign=top>
		<b>$page_title</b>
		<p>This report shows <i>days</i> of logged hours per month for several months.<br>
		The number of days are calculated by dividing the number of hours by <br>
		the TimesheetHoursPerDay parameter (by default 8 hours).
	</td></tr>
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
	
	im_report_update_counters -counters $counters
	

	# Rounding for counter sums
	set year $year_start
	set month $month_start
	for {set i 0} {[expr {$year * 12 + $month}] <= [expr {$year_end * 12 + $month_end}]} {incr i} {
	    if {$month > 12} {
		set month 1
		incr year
	    }
	    set month_formatted $month
	    if {[string length $month_formatted] < 2} { set month_formatted "0$month_formatted" }
	    set "h${year}_${month_formatted}_subtotal" [expr round(10.0 * [expr "\$h${year}_${month_formatted}_subtotal"])/10.0 ]
	    incr month
	}
	set "htotal_subtotal" [expr round(10.0 * [expr "\$htotal_subtotal"])/10.0 ]


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

