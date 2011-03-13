# /packages/intranet-reporting/www/timesheet-productivity-calendar-view.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/ for licensing details.


ad_page_contract {
	testing reports	
    @param start_year Year to start the report
    @param start_unit Month or week to start within the start_year
} {
    { report_year_month "" }
    { level_of_detail 3 }
    { output_format "html" }
    { user_id 0 }
    { project_id 0 }
    { project_status_id 0 }
    { customer_id 0 }
    { daily_hours 0 }
}


proc round_down {val rounder} {
       set nval [expr floor($val*$rounder) /$rounder]
       return $nval
       }

# ------------------------------------------------------------
# Security
# ------------------------------------------------------------

# Label: Provides the security context for this report
# because it identifies unquely the report's Menu and
# its permissions.
set menu_label "reporting-timesheet-productivity"

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

set page_title "Timesheet Productivity Report"
set context_bar [im_context_bar $page_title]
set context ""


# Check that Start-Date have correct format
set report_year_month [string range $report_year_month 0 6]
if {"" != $report_year_month && ![regexp {^[0-9][0-9][0-9][0-9]\-[0-9][0-9]$} $report_year_month]} {
    ad_return_complaint 1 "Start Date doesn't have the right format.<br>
    Current value: '$report_year_month'<br>
    Expected format: 'YYYY-MM'"
}

set date_format "YYYY-MM-DD"

# ------------------------------------------------------------
# Defaults
# ------------------------------------------------------------

set todays_date [db_string todays_date "select to_char(now(), :date_format) from dual" -default ""]

if { [empty_string_p $report_year_month] } {
    set report_year_month "[string range $todays_date 0 3]-[string range $todays_date 5 6]"
}    

set report_year [string range $report_year_month 0 3]
set report_month [string range $report_year_month 5 6 ]


# set days_in_past 15
# db_1row todays_date "
# select
#	to_char(sysdate::date - :days_in_past::integer, 'YYYY') as todays_year,
#	to_char(sysdate::date - :days_in_past::integer, 'MM') as todays_month
# from dual
# "

set first_day_of_month "$report_year-$report_month-01"
set first_day_next_month [db_string get_number_days_month "SELECT '$first_day_of_month'::date + '1 month'::interval" -default 0]

set duration [db_string get_number_days_month "SELECT date_part('day','$first_day_of_month'::date + '1 month'::interval - '1 day'::interval)" -default 0]
# set duration 1


set company_url "/intranet/companies/view?company_id="
set project_url "/intranet/projects/view?project_id="
set user_url "/intranet/users/view?user_id="

set this_url [export_vars -base "/intranet-reporting/timesheet-productivity" {report_year_month} ]

set internal_company_id [im_company_internal]

set levels {1 "User Only" 2 "User+Company" 3 "User+Company+Project" 4 "All Details"} 

set num_format "999,990.99"

set im_absence_type_vacation 5000
set im_absence_type_personal 5001
set im_absence_type_sick 5002
set im_absence_type_travel 5003
set im_absence_type_bankholiday 5005
set im_absence_type_training 5004

# ------------------------------------------------------------
# Conditional SQL Where-Clause
#

set criteria [list]

if {"" != $project_id && 0 != $project_id} {
    lappend criteria "
                p.project_id in (
                select distinct
                        children.project_id as subproject_id
                from
                        im_projects parent,
                        im_projects children
                where
                        children.tree_sortkey between parent.tree_sortkey and tree_right(parent.tree_sortkey)
                        and parent.project_id = :project_id
                        )
    "
}

if {"" != $customer_id && 0 != $customer_id} {
	 lappend criteria "p.company_id = :customer_id" 
}

if { ![empty_string_p $project_status_id] && $project_status_id > 0 } {
    lappend criteria "p.project_status_id in ([join [im_sub_categories $project_status_id] ","])"
}

if {[info exists user_id] && 0 != $user_id && "" != $user_id} {
    lappend criteria "h.user_id = :user_id"
}

set where_clause [join $criteria " and\n            "]
if { ![empty_string_p $where_clause] } {
    set where_clause " and $where_clause"
}

if {"" != $daily_hours && 0 != $daily_hours} {
    set criteria_inner_sql "and h.hours > :daily_hours"
} else {
    set criteria_inner_sql "and 1=1"
}


# ------------------------------------------------------------
# Define the report - SQL, counters, headers and footers 
#

set day_placeholders ""
set day_header ""
for { set i 1 } { $i < $duration + 1 } { incr i } {
    if { 1 == [string length $i]} { set day_double_digit 0$i } else { set day_double_digit $i }
    lappend inner_sql_list "(select sum(hours) from im_hours h where
            h.user_id = s.sub_user_id
            and h.project_id in (
                select distinct
                        children.project_id as subproject_id
                from
                        im_projects parent,
                        im_projects children
                where
                        children.tree_sortkey between parent.tree_sortkey and tree_right(parent.tree_sortkey)
                        and parent.project_id = h.project_id
                        )
            and h.day like '%$report_year-$report_month-$day_double_digit%'
	    $criteria_inner_sql
	) as day$day_double_digit

    "
    append day_placeholders "\\" "\$day$day_double_digit "
    append day_header \"$day_double_digit\"
    append day_header " "
    # set h_date [db_string get_view_id "select to_char(to_date('$report_year-$report_month-$day_double_digit', :date_format)-$i, 'DY') as h_date from dual" -default 0]
    # if { $h_date == "SAT" || $h_date == "SUN" } {
    #        append table_header_html "<td class=rowtitle>$day_double_digit</td>"
    # } else {
    #        append table_header_html "<td class=rowtitle>$day_double_digit</td>"
    # }
}

# ad_return_complaint 1 $day_placeholders


set inner_sql [join $inner_sql_list ", "]

set sql "
	select 
		s.sub_user_id as user_id,
		s.sub_user_name as user_name,
		s.sub_project_id as project_id,
		s.sub_project_name as project_name,
		(select count(*) from (select * from im_absences_working_days_month(s.sub_user_id,$report_month,$report_year) t(days int))ct) as work_days,
		(select count(distinct absence_query.days) from (select * from im_absences_month_absence_type (s.sub_user_id, $report_month, $report_year, $im_absence_type_vacation) AS (days date)) absence_query) as vacation_days,
		(select count(distinct absence_query.days) from (select * from im_absences_month_absence_type (s.sub_user_id, $report_month, $report_year, $im_absence_type_training) AS (days date)) absence_query) as training_days,
		(select count(distinct absence_query.days) from (select * from im_absences_month_absence_type (s.sub_user_id, $report_month, $report_year, $im_absence_type_travel) AS (days date)) absence_query) as travel_days,
		(select count(distinct absence_query.days) from (select * from im_absences_month_absence_type (s.sub_user_id, $report_month, $report_year, $im_absence_type_sick) AS (days date)) absence_query) as sick_days,
		(select count(distinct absence_query.days) from (select * from im_absences_month_absence_type (s.sub_user_id, $report_month, $report_year, $im_absence_type_personal) AS (days date)) absence_query) as personal_days,
		$inner_sql
	from 
	(select 
		distinct on (u.user_id) u.user_id as sub_user_id,
		p.project_id as sub_project_id,
		p.project_name as sub_project_name, 

		im_name_from_user_id(u.user_id) as sub_user_name
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
                and h.day >= to_date(:first_day_of_month, 'YYYY-MM-DD')
                and h.day < to_date(:first_day_next_month, 'YYYY-MM-DD') 
                $where_clause
	order by 
		u.user_id,
		p.project_id,
		h.day
	) s 
"

# ad_return_complaint 1 $sql

set report_def [list \
    group_by user_id \
    header {
                "\#colspan=99 <b><a href=$user_url$user_id>$user_name</a></b>"
    } \
	            content [list \
		            group_by project_id \
        	            header {
				""
                	        "<b><a href=$project_url$project_id>$project_name</a></b>"
				$day01 
				"-"
                    	     } \
                    	     content {} \
            	    ] \
    footer {
            "Summary" "#colspan=33" "$number_days_ctr_pretty" 
    } \
]


set line_str " \"\" \"<b><a href=\$project_url\$project_id>\$project_name</a></b>\" "
append line_str $day_placeholders "-" 
set no_empty_columns [expr $duration+1]

set report_def 		[list group_by user_id header {"\#colspan=99 <b><a href=$user_url$user_id>$user_name</a></b>"} content]
lappend report_def 	[list group_by project_id header $line_str content {}]
lappend report_def 	footer { "Summary" "\#colspan=$no_empty_columns" "$number_days_ctr_pretty" "[expr $work_days - $vacation_days - $training_days - $travel_days - $sick_days - $personal_days ]" "[round_down [expr 100 * $number_days_ctr_pretty / $work_days ] 1000]%" }

# Global header/footer
# set header0 {"Employee" "Project" "01" "02" "03" "04" "05" "06" "07" "08" "09" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21" "22" "23" "24" "25" "26" "27" "28" "29" "30" "31" "Working<br>Days"}
set header0 "\"Employee\" \"Project\" $day_header \"Days shown\" \"Working<br>Days net\" \"Utilization\" "
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
		  <td class=form-label>Month</td>
		  <td class=form-widget>
		    <input type=textfield name='report_year_month' value='$report_year_month'>
		  </td>
		</tr>
		<tr>
		  <td class=form-label>Employee</td>
		  <td class=form-widget>
		    [im_user_select -include_empty_p 1 user_id $user_id]
		  </td>
		</tr>
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
                    [im_project_select -include_empty_p 1 project_id $project_id]
                  </td>
                </tr>
                <tr>
                  <td class=form-label>Project Status</td>
                  <td class=form-widget>
                    [im_project_status_select "project_status_id" "76"]
                  </td>
                </tr>
                <tr>
                  <td class=form-label>Daaily hours</td>
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
		  <td class=form-label></td>
		  <td class=form-widget><input type=submit value=Submit></td>
		</tr>
		</table>
	</form>
	<table border=0 cellspacing=1 cellpadding=1>\n
	"
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

set number_days_ctr 0

        set number_days_counter [list \
                pretty_name "Invoice Amount" \
                var number_days_ctr_pretty \
                reset "\$user_id" \
                expr "\$number_days_ctr+0" \
        ]

        set counters [list \
                $number_days_counter \
        ]

db_foreach sql $sql {

        set number_days_ctr 0

	im_report_display_footer \
	    -output_format $output_format \
	    -group_def $report_def \
	    -footer_array_list $footer_array_list \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class

	for { set i 1 } { $i < $duration + 1 } { incr i } {
		if { 1 == [string length $i]} { set day_double_digit day0$i } else { set day_double_digit day$i }
		if { "" != [expr $$day_double_digit] } { set number_days_ctr [expr $number_days_ctr+1] } 
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

