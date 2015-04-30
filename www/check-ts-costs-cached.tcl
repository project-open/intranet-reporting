# /packages/intranet-reporting/www/check-ts-costs-cached.tcl
#
# Copyright (c) 2003-2015 ]project-open[
#
# All rights reserved. 
# Please see http://www.project-open.com/ for licensing.


# ------------------------------------------------------------
# Check if financial elements have the same customers/providers
# as their associated projects.


# ------------------------------------------------------------
# SECURITY

set current_user_id [ad_maybe_redirect_for_registration]
if { ![im_is_user_site_wide_or_intranet_admin $current_user_id] } {
    set message "You don't have the necessary permissions to view this page"
    ad_return_complaint 1 "<li>$message"
    ad_script_abort
}

# ------------------------------------------------------------
# Default Values and Constants

set page_title "Compare cached TS costs with TS costs as tracked in table: im_hours"
set help_text "
	This report checks for inconsistencies between the timesheet 
	costs that are cached and that are shown in many reports and portlets 
	and the ones that are calculated based on the entries in the 
	im_hours table. The report only shows main projects.  
"

# ------------------------------------------------------------
# Do not spam product w/ otherwise useless functions 

set im_report_get_ts_costs_im_hours_sql "
	CREATE OR REPLACE FUNCTION pg_temp.im_report_get_ts_costs_im_hours (int4)
	RETURNS NUMERIC AS \$BODY\$

	declare
		p_project_id        alias for \$1;
		v_sum_ts_cost       numeric;
		v_total_ts_cost     numeric;
		r           	    record;
	
	begin
		v_total_ts_cost := 0;
		    FOR r IN
		        select      hours,
			            billing_rate 
	        	from 	    im_hours 
		        where       project_id = p_project_id       
	        LOOP
			v_sum_ts_cost := r.hours * r.billing_rate;
	        	IF v_sum_ts_cost is null THEN 
				v_sum_ts_cost := 0; 
			END IF;  
			v_total_ts_cost := v_total_ts_cost + v_sum_ts_cost;
			v_sum_ts_cost := 0;
		END LOOP;
		return v_total_ts_cost;
	
	end;\$BODY\$ LANGUAGE 'plpgsql';
" 

db_dml create_im_report_get_ts_costs_im_hours_sql $im_report_get_ts_costs_im_hours_sql


set im_report_get_ts_costs_no_cache_sql "
	CREATE OR REPLACE FUNCTION pg_temp.im_report_get_ts_costs_no_cache (int4)
	RETURNS NUMERIC AS \$BODY\$

	declare
	p_project_id        alias for \$1;
	v_child_project_id  int;
	v_sum_ts_cost       numeric;
	v_total_ts_cost     numeric;
	r	            record;

	begin
		v_total_ts_cost := 0;
    		FOR r IN
        		select      p_child.project_id 
        		from        im_projects p_parent,
                		    im_projects p_child
        		where       p_child.tree_sortkey between p_parent.tree_sortkey 
		                    and tree_right(p_parent.tree_sortkey)
                		    and p_parent.project_id = p_project_id
        LOOP

		select pg_temp.im_report_get_ts_costs_im_hours(r.project_id) into v_sum_ts_cost;  
		v_total_ts_cost := v_total_ts_cost + v_sum_ts_cost;
		v_sum_ts_cost := 0;
	END LOOP;
	return v_total_ts_cost;
	end;\$BODY\$ LANGUAGE 'plpgsql';
"
db_dml create_im_report_get_ts_costs_no_cache_sql $im_report_get_ts_costs_no_cache_sql


# ------------------------------------------------------------
# Report SQL 

set sql "
	select 
		'<a href=\"/intranet/projects/view?project_id=' || p.project_id  || '\">' || p.project_name || '</a>' as project_name,
		pg_temp.im_report_get_ts_costs_no_cache(p.project_id) as costs_no_cache,
		CASE p.cost_timesheet_logged_cache is null OR p.cost_timesheet_logged_cache = 0
			WHEN true THEN 
				0
			ELSE	
				cost_timesheet_logged_cache
		END as cost_timesheet_logged_cache,
		CASE (pg_temp.im_report_get_ts_costs_no_cache(p.project_id) - p.cost_timesheet_logged_cache) <> 0
                        WHEN true THEN
                                '<span style=\"color:red\">' || pg_temp.im_report_get_ts_costs_no_cache(p.project_id) - p.cost_timesheet_logged_cache || '</span>'
                        ELSE
                                '<span style=\"color:green\">0</span>' 
		END as diff,
		im_name_from_id(p.project_status_id) as status
	from 
		im_projects p 
	where 
		p.parent_id is null
"

# ------------------------------------------------------------
# Start Formatting the HTML Page Contents

ad_return_top_of_page "
	[im_header]
	[im_navbar]
	<table cellspacing=0 cellpadding=0 border=0>
	<tr valign=top>
	  <td>
		<table cellspacing=2 width='90%'>
		<tr>
		  <td>$help_text</td>
		</tr>
		</table>
	  </td>
	</tr>
	</table>
	<br/><br/>
	<!-- Here starts the main report table -->
	<table border=1 cellspacing=2 cellpadding=5>
    	     <tr>
                <td><strong>Project Name</strong></td>\n
                <td><strong>TS Costs<br>im_hours</strong></td>\n
                <td><strong>Cached Costs</strong></td>\n
                <td><strong>Difference</strong></td>\n
                <td><strong>Project Status</strong></td>\n
             </tr>
"

db_foreach r $sql {
    ns_write "<tr>\n
		<td>$project_name</td>\n
		<td>$costs_no_cache</td>\n
		<td>$cost_timesheet_logged_cache</td>\n
		<td>$diff</td>\n
		<td>$status</td>\n
	      </tr>"
}

ns_write "
	</table>
	[im_footer]
"
