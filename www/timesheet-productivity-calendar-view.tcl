# /packages/intranet-reporting/www/timesheet-productivity-calendar-view.tcl
#
# Copyright (C) 2003-2004 Project/Open
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
    { user_id 0 }
    { project_id 0}
    { cost_center_id 525}
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
set start_date [string range $start_date 0 6]
if {"" != $start_date && ![regexp {^[0-9][0-9][0-9][0-9]\-[0-9][0-9]$} $start_date]} {
    ad_return_complaint 1 "Start Date doesn't have the right format.<br>
    Current value: '$start_date'<br>
    Expected format: 'YYYY-MM'"
}


# ------------------------------------------------------------
# Defaults
# ------------------------------------------------------------

set days_in_past 15

db_1row todays_date "
select
	to_char(sysdate::date - :days_in_past::integer, 'YYYY') as todays_year,
	to_char(sysdate::date - :days_in_past::integer, 'MM') as todays_month
from dual
"

if {"" == $start_date} { 
    set start_date "$todays_year-$todays_month"
}

set company_url "/intranet/companies/view?company_id="
set project_url "/intranet/projects/view?project_id="
set user_url "/intranet/users/view?user_id="

set this_url [export_vars -base "/intranet-reporting/timesheet-productivity" {start_date} ]

set internal_company_id [im_company_internal]

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
# set array of dates to query 
#



set next_date ""   

for {set ctr 1} {$ctr < 32} {incr ctr} {
    set inner_ctr_len [string length $ctr]
    if { 1 == $inner_ctr_len } { 
	set inner_ctr "0"
	append inner_ctr $ctr 
    } else {
	set inner_ctr $ctr
    }
    append next_date $start_date "-" $inner_ctr
    set query_dates($ctr) $next_date
    set next_date ""
}



# ------------------------------------------------------------
# Define the report - SQL, counters, headers and footers 
#

set sql "
	select 
		distinct on (s.sub_project_id, s.sub_user_id)
		s.sub_user_id as user_id,
		s.sub_user_name as user_name,
		s.sub_project_id as project_id,
		s.sub_project_name as project_name,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(1)') as day01,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(2)') as day02,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(3)') as day03,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(4)') as day04,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(5)') as day05,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(6)') as day06,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(7)') as day07,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(8)') as day08,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(9)') as day09,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(10)') as day10,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(11)') as day11,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(12)') as day12,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(13)') as day13,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(14)') as day14,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(15)') as day15,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(16)') as day16,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(17)') as day17,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(18)') as day18,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(19)') as day19,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(20)') as day20,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(21)') as day21,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(22)') as day22,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(23)') as day23,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(24)') as day24,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(25)') as day25,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(26)') as day26,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(27)') as day27,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(28)') as day28,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(29)') as day29,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(30)') as day30,
		im_get_hours_logged (s.sub_user_id, s.sub_project_id, '$query_dates(31)') as day31,
		im_get_hours_percentage(s.sub_user_id, s.sub_project_id, :start_date) as percentage_total_month
	from 
	(select 
		p.project_id as sub_project_id,
		p.project_name as sub_project_name, 
		u.user_id as sub_user_id,
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
                and h.day >= to_date(:start_date, 'YYYY-MM')
                and h.day < to_date(:start_date, 'YYYY-MM') + 31
                and :start_date = to_char(h.day, 'YYYY-MM')
        	$where_clause
	order by 
		p.project_id,
		u.user_id,
		h.day
	) s 
"

set report_def [list \
    group_by project_id \
    header {
	 "\#colspan=99 <b><a href=$project_url$project_id>$project_name</a></b>"
    } \
        content [list \
            group_by user_id \
            header {
                "\#colspan=1 "
                "\#colspan=99 <b><a href=$user_url$user_id>$user_name</a></b>"
            } \
	            content [list \
        	            header {
                	        $project_name
                      		$user_name
				$day01
				$day02
				$day03
				$day04
				$day05
				$day06
				$day07
				$day08
				$day09
				$day10
				$day11
				$day12
				$day13
				$day14
				$day15
				$day16
				$day17
				$day18
				$day19
				$day20
				$day21
				$day22
				$day23
				$day24
				$day25
				$day26
				$day27
				$day28
				$day29
				$day30
				$day31
				$employee_total
				$percentage_total_month
                    	     } \
                    	     content {} \
            	    ] \
              footer {
            	"#colspan=99"
            } \
	] \
    footer {
	    "" ""
	    "<b>$project_subtotal_01</b>"
	    "<b>$project_subtotal_02</b>"
	    "<b>$project_subtotal_03</b>"
	    "<b>$project_subtotal_04</b>"
	    "<b>$project_subtotal_05</b>"
	    "<b>$project_subtotal_06</b>"
	    "<b>$project_subtotal_07</b>"
	    "<b>$project_subtotal_08</b>"
	    "<b>$project_subtotal_09</b>"
	    "<b>$project_subtotal_10</b>"
	    "<b>$project_subtotal_11</b>"
	    "<b>$project_subtotal_12</b>"
	    "<b>$project_subtotal_13</b>"
	    "<b>$project_subtotal_14</b>"
	    "<b>$project_subtotal_15</b>"
	    "<b>$project_subtotal_16</b>"
	    "<b>$project_subtotal_17</b>"
	    "<b>$project_subtotal_18</b>"
	    "<b>$project_subtotal_19</b>"
	    "<b>$project_subtotal_20</b>"
	    "<b>$project_subtotal_21</b>"
	    "<b>$project_subtotal_22</b>"
	    "<b>$project_subtotal_23</b>"
	    "<b>$project_subtotal_24</b>"
	    "<b>$project_subtotal_25</b>"
	    "<b>$project_subtotal_26</b>"
	    "<b>$project_subtotal_27</b>"
	    "<b>$project_subtotal_28</b>"
	    "<b>$project_subtotal_29</b>"
	    "<b>$project_subtotal_30</b>"
	    "<b>$project_subtotal_31</b>"
            "#colspan=99"
    } \
]


# Global header/footer
set header0 {"Project" "Employee" "01" "02" "03" "04" "05" "06" "07" "08" "09" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21" "22" "23" "24" "25" "26" "27" "28" "29" "30" "31" "Summary" "% of <br>total hours<br>logged by user<br>this month"}
set footer0 {"" "" "" "" "" "" "" "" ""}


set project_subtotal_counter_01 [list \
	pretty_name "Hours" \
	var project_subtotal_01 \
	reset "\$project_id" \
	expr "\$day01+0" \
]

set project_subtotal_counter_02 [list \
        pretty_name "Hours" \
        var project_subtotal_02 \
        reset "\$project_id" \
        expr "\$day02+0" \
]

set project_subtotal_counter_03 [list \
        pretty_name "Hours" \
        var project_subtotal_03 \
        reset "\$project_id" \
        expr "\$day03+0" \
]

set project_subtotal_counter_04 [list \
        pretty_name "Hours" \
        var project_subtotal_04 \
        reset "\$project_id" \
        expr "\$day04+0" \
]

set project_subtotal_counter_05 [list \
        pretty_name "Hours" \
        var project_subtotal_05 \
        reset "\$project_id" \
        expr "\$day05+0" \
]

set project_subtotal_counter_06 [list \
        pretty_name "Hours" \
        var project_subtotal_06 \
        reset "\$project_id" \
        expr "\$day06+0" \
]

set project_subtotal_counter_07 [list \
        pretty_name "Hours" \
        var project_subtotal_07 \
        reset "\$project_id" \
        expr "\$day07+0" \
]

set project_subtotal_counter_08 [list \
        pretty_name "Hours" \
        var project_subtotal_08 \
        reset "\$project_id" \
        expr "\$day08+0" \
]

set project_subtotal_counter_09 [list \
        pretty_name "Hours" \
        var project_subtotal_09 \
        reset "\$project_id" \
        expr "\$day09+0" \
]

set project_subtotal_counter_10 [list \
        pretty_name "Hours" \
        var project_subtotal_10 \
        reset "\$project_id" \
        expr "\$day10+0" \
]

set project_subtotal_counter_11 [list \
        pretty_name "Hours" \
        var project_subtotal_11 \
        reset "\$project_id" \
        expr "\$day11+0" \
]

set project_subtotal_counter_12 [list \
        pretty_name "Hours" \
        var project_subtotal_12 \
        reset "\$project_id" \
        expr "\$day12+0" \
]

set project_subtotal_counter_13 [list \
        pretty_name "Hours" \
        var project_subtotal_13 \
        reset "\$project_id" \
        expr "\$day13+0" \
]

set project_subtotal_counter_14 [list \
        pretty_name "Hours" \
        var project_subtotal_14 \
        reset "\$project_id" \
        expr "\$day14+0" \
]

set project_subtotal_counter_15 [list \
        pretty_name "Hours" \
        var project_subtotal_15 \
        reset "\$project_id" \
        expr "\$day15+0" \
]

set project_subtotal_counter_16 [list \
        pretty_name "Hours" \
        var project_subtotal_16 \
        reset "\$project_id" \
        expr "\$day16+0" \
]

set project_subtotal_counter_17 [list \
        pretty_name "Hours" \
        var project_subtotal_17 \
        reset "\$project_id" \
        expr "\$day17+0" \
]

set project_subtotal_counter_18 [list \
        pretty_name "Hours" \
        var project_subtotal_18 \
        reset "\$project_id" \
        expr "\$day18+0" \
]

set project_subtotal_counter_19 [list \
        pretty_name "Hours" \
        var project_subtotal_19 \
        reset "\$project_id" \
        expr "\$day19+0" \
]

set project_subtotal_counter_20 [list \
        pretty_name "Hours" \
        var project_subtotal_20 \
        reset "\$project_id" \
        expr "\$day20+0" \
]

set project_subtotal_counter_21 [list \
        pretty_name "Hours" \
        var project_subtotal_21 \
        reset "\$project_id" \
        expr "\$day21+0" \
]

set project_subtotal_counter_22 [list \
        pretty_name "Hours" \
        var project_subtotal_22 \
        reset "\$project_id" \
        expr "\$day22+0" \
]

set project_subtotal_counter_23 [list \
        pretty_name "Hours" \
        var project_subtotal_23 \
        reset "\$project_id" \
        expr "\$day23+0" \
]

set project_subtotal_counter_24 [list \
        pretty_name "Hours" \
        var project_subtotal_24 \
        reset "\$project_id" \
        expr "\$day24+0" \
]

set project_subtotal_counter_25 [list \
        pretty_name "Hours" \
        var project_subtotal_25 \
        reset "\$project_id" \
        expr "\$day25+0" \
]

set project_subtotal_counter_26 [list \
        pretty_name "Hours" \
        var project_subtotal_26 \
        reset "\$project_id" \
        expr "\$day26+0" \
]

set project_subtotal_counter_27 [list \
        pretty_name "Hours" \
        var project_subtotal_27 \
        reset "\$project_id" \
        expr "\$day27+0" \
]

set project_subtotal_counter_28 [list \
        pretty_name "Hours" \
        var project_subtotal_28 \
        reset "\$project_id" \
        expr "\$day28+0" \
]

set project_subtotal_counter_29 [list \
        pretty_name "Hours" \
        var project_subtotal_29 \
        reset "\$project_id" \
        expr "\$day29+0" \
]

set project_subtotal_counter_30 [list \
        pretty_name "Hours" \
        var project_subtotal_30 \
        reset "\$project_id" \
        expr "\$day30+0" \
]

set project_subtotal_counter_31 [list \
        pretty_name "Hours" \
        var project_subtotal_31 \
        reset "\$project_id" \
        expr "\$day31+0" \
]

set counters [list \
	 $project_subtotal_counter_01 \
	 $project_subtotal_counter_02 \
	 $project_subtotal_counter_03 \
	 $project_subtotal_counter_04 \
	 $project_subtotal_counter_05 \
	 $project_subtotal_counter_06 \
	 $project_subtotal_counter_07 \
	 $project_subtotal_counter_08 \
	 $project_subtotal_counter_09 \
	 $project_subtotal_counter_10 \
	 $project_subtotal_counter_11 \
	 $project_subtotal_counter_12 \
	 $project_subtotal_counter_13 \
	 $project_subtotal_counter_14 \
	 $project_subtotal_counter_15 \
	 $project_subtotal_counter_16 \
	 $project_subtotal_counter_17 \
	 $project_subtotal_counter_18 \
	 $project_subtotal_counter_19 \
	 $project_subtotal_counter_20 \
	 $project_subtotal_counter_21 \
	 $project_subtotal_counter_22 \
	 $project_subtotal_counter_23 \
	 $project_subtotal_counter_24 \
	 $project_subtotal_counter_25 \
	 $project_subtotal_counter_26 \
	 $project_subtotal_counter_27 \
	 $project_subtotal_counter_28 \
	 $project_subtotal_counter_29 \
	 $project_subtotal_counter_30 \
	 $project_subtotal_counter_31 \
]






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

    set employee_total [expr [expr $day01+0] + [expr $day02+0] + [expr $day03+0] + [expr $day04+0] + [expr $day05+0] + [expr $day06+0] + [expr $day07+0] + [expr $day08+0] + [expr $day09+0] + [expr $day10+0] + [expr $day11+0] + [expr $day12+0] + [expr $day13+0] + [expr $day14+0] + [expr $day15+0] + [expr $day16+0] + [expr $day17+0] + [expr $day18+0] + [expr $day19+0] + [expr $day20+0] + [expr $day21+0] + [expr $day22+0] + [expr $day23+0] + [expr $day24+0] + [expr $day25+0] + [expr $day26+0] + [expr $day27+0] + [expr $day28+0] + [expr $day29+0] + [expr $day30+0] + [expr $day31+0] ] 

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
}
