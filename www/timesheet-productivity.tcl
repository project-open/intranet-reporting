# /packages/intranet-reporting/www/timesheet-productivity.tcl
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
    { level_of_detail 2 }
}

# ------------------------------------------------------------
# Security

# Check that Start-Date have correct format
if {"" != $start_date && ![regexp {^[0-9][0-9][0-9][0-9]\-[0-9][0-9]$} $start_date]} {
    ad_return_complaint 1 "Start Date doesn't have the right format.<br>
    Current value: '$start_date'<br>
    Expected format: 'YYYY-MM'"
}

set current_user_id [ad_maybe_redirect_for_registration]
set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $current_user_id]
if {!$user_is_admin_p} {
    ad_return_complaint 1 "<li>[_ intranet-core.lt_You_need_to_be_a_syst]">
    return
}


set page_title "Timesheet Productivity Report"
set context_bar [im_context_bar $page_title]
set context ""


# ------------------------------------------------------------
# Defaults

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
# Define the report - SQL, counters, headers and footers 
#

set inner_sql "
select
	h.day::date as date,
	h.user_id,
	p.project_id,
	p.company_id,
	h.hours as hours,
	h.note,
	h.billing_rate,
	e.availability,
	to_char(e.salary, :num_format) as salary,
	to_char(e.social_security, :num_format) as social_security,
	to_char(e.insurance, :num_format) as insurance,
	to_char(e.other_costs, :num_format) as other_costs,
	to_char(e.hourly_cost, :num_format) as hourly_cost,
	e.currency,
	e.hourly_cost,
	e.salary_payments_per_year,
	(e.salary + e.social_security + e.insurance + e.other_costs) * e.salary_payments_per_year / 12 as total_cost
from
	im_hours h,
	im_projects p,
	cc_users u
	LEFT OUTER JOIN
		im_employees e
		on (u.user_id = e.employee_id)
where
	h.project_id = p.project_id
	and h.user_id = u.user_id
	and h.day >= to_date(:start_date, 'YYYY-MM')
	and h.day < to_date(:start_date, 'YYYY-MM') + 31
	and :start_date = to_char(h.day, 'YYYY-MM')
"

set sql "
select
	s.*,
	CASE c.company_id = :internal_company_id WHEN true THEN s.hours ELSE 0 END as hours_intl,
	CASE c.company_id != :internal_company_id WHEN true THEN s.hours ELSE 0 END as hours_extl,
	to_char(s.date, 'YYYY-MM-DD') as date,
	u.user_id,
	u.first_names || ' ' || u.last_name as user_name,
	p.project_id,
	p.project_nr,
	p.project_name,
	c.company_id,
	c.company_path as company_nr,
	c.company_name,
	to_char(s.hours, :num_format) as hours_pretty,
	to_char(s.total_cost, :num_format) as total_cost_pretty
from
	($inner_sql) s,
	im_companies c,
	im_projects p,
	cc_users u
where
	s.user_id = u.user_id
	and s.company_id = c.company_id
	and s.project_id = p.project_id
order by
	u.user_id,
	s.company_id,
	p.project_id,
	s.date
"

set report_def [list \
    group_by user_id \
    header {
	"\#colspan=99 <a href=$this_url&project_id=$project_id&user_id=$user_id&level_of_detail=4 target=_blank><img src=/intranet/images/plus_9.gif border=0></a>
	<b><a href=$user_url$user_id>$user_name</a></b>"
    } \
    content [list  \
	group_by company_id \
	header {
	    $user_name
	    "\#colspan=99 <a href=$this_url&company_id=$company_id&level_of_detail=4 target=_blank><img src=/intranet/images/plus_9.gif border=0></a> 
	    <b><a href=$company_url$company_id>$company_name</a></b>"
	} \
	content [list \
	    group_by project_id \
	    header {
		$user_name
		$company_nr 
		"\#colspan=99 <a href=$this_url&project_id=$project_id&level_of_detail=4 target=_blank><img src=/intranet/images/plus_9.gif border=0></a>
		<b><a href=$project_url$project_id>$project_name</a></b>"
	    } \
	    content [list \
		    header {
			$user_name
			$company_nr
			$project_nr
			$date
			"" "" "" "" "" "" "" "" ""
			$hours_intl
			$hours_extl
			""
			$hours
		    } \
		    content {} \
	    ] \
	    footer {
		$user_name
		$company_nr 
		$project_nr 
		"#colspan=99"
	    } \
	] \
	footer {
	    "#colspan=99"
	} \
    ] \
    footer {
	$user_name 
	"" "" ""
	"$availability %"
        $salary
        $social_security
        $insurance
        $other_costs
        $salary_payments_per_year
        "<b>$total_cost_pretty $currency</b>"
        $hourly_cost
	""
	"<b>$hours_user_intl_subtotal</b>" 
	"<b>$hours_user_extl_subtotal</b>" 
	"" 
	"<b>$hours_user_subtotal</b>" 
    } \
]

# Global header/footer
set header0 {"Employee" "Customer" "Project" "Date" Avail Salary SS Ins Other "\#Pay" Total "Hourly<br>Rate" "&nbsp;" "Intl<br>Hours" "Extl<br>Hours" "&nbsp;" "Total<br>Hours"}
set footer0 {"" "" "" "" "" "" "" "" ""}

set hours_user_counter [list \
	pretty_name Hours \
	var hours_user_subtotal \
	reset \$user_id \
	expr \$hours
]

set hours_user_intl_counter [list \
	pretty_name HoursIntl \
	var hours_user_intl_subtotal \
	reset \$user_id \
	expr \$hours_intl
]

set hours_user_extl_counter [list \
	pretty_name HoursExtl \
	var hours_user_extl_subtotal \
	reset \$user_id \
	expr \$hours_extl
]

set counters [list \
	$hours_user_counter \
	$hours_user_intl_counter \
	$hours_user_extl_counter \
]


# ------------------------------------------------------------
# Start formatting the page
#

ad_return_top_of_page "
[im_header]
[im_navbar]
<form>
<table border=0 cellspacing=1 cellpadding=1>
<tr>
  <td class=form-label>Level of Details</td>
  <td class=form-widget>
    [im_select -translate_p 0 level_of_detail $levels $level_of_detail]
  </td>
</tr>
<tr>
  <td class=form-label>Start Date</td>
  <td class=form-widget>
    <input type=textfield name=start_date value=$start_date>
  </td>
</tr>
<tr>
  <td></td>
  <td><input type=submit value=Submit></td>
</tr>
</table>
</form>

<table border=0 cellspacing=1 cellpadding=1>\n"

im_report_render_row \
    -row $header0 \
    -row_class "rowtitle" \
    -cell_class "rowtitle"


set footer_array_list [list]
set last_value_list [list]
set class "rowodd"
db_foreach sql $sql {

	im_report_display_footer \
	    -group_def $report_def \
	    -footer_array_list $footer_array_list \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class
	
	im_report_update_counters -counters $counters
	
	set last_value_list [im_report_render_header \
	    -group_def $report_def \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class
        ]

        set footer_array_list [im_report_render_footer \
	    -group_def $report_def \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class
        ]
}

im_report_display_footer \
    -group_def $report_def \
    -footer_array_list $footer_array_list \
    -last_value_array_list $last_value_list \
    -level_of_detail $level_of_detail \
    -display_all_footers_p 1 \
    -row_class $class \
    -cell_class $class

im_report_render_row \
    -row $footer0 \
    -row_class $class \
    -cell_class $class


ns_write "</table>\n[im_footer]\n"