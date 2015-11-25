# /packages/intranet-reporting/www/check-ts-costs-cached.tcl
#
# Copyright (c) 2003-2015 ]project-open[
#
# All rights reserved. 
# Please see http://www.project-open.com/ for licensing.


# ------------------------------------------------------------
# Check if financial elements have the same customers/providers
# as their associated projects.


ad_page_contract {
    @param start_date Start date (YYYY-MM-DD format)
} {
    { start_date "2010-01-01" }
    { project_status_id:integer 0 }
    { show_diff_only_p:optional }
    { fix_project_id:array,multiple {} }
    btn:optional
}

# ------------------------------------------------------------
# SECURITY

set current_user_id [auth::require_login]
if { ![im_is_user_site_wide_or_intranet_admin $current_user_id] } {
    set message "You don't have the necessary permissions to view this page"
    ad_return_complaint 1 "<li>$message"
    ad_script_abort
}

# ------------------------------------------------------------
# Check Parameters
#

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

# Default should be: Show only Differences
if { "GET" == [ad_conn method] } { set show_diff_only_p 1 }

# Determine the default status if not set
if { 0 == $project_status_id } {
    # Default status is open
    set project_status_id [im_project_status_open]
}

set show_diff_only_p_checked ""
if { [info exists show_diff_only_p] } {
    set show_diff_only_p_checked "checked"
}

if { "POST" == [ad_conn method] && [info exists btn] } {

    set del_cost_ids [list]
    foreach { p_id foo } [array get fix_project_id] {

	# Wrong project assignments
	# Check for mismatch between im_hour::project_id and im_costs::project_id
	set sql "
	select  
		c.cost_id
        from 
                im_hours h, 
                im_costs c
        where 
                h.cost_id = c.cost_id 
                and h.project_id <> c.project_id
                and h.project_id in (
                             select      p_child.project_id
                             from        im_projects p_parent,
                                         im_projects p_child
                             where       p_child.tree_sortkey between p_parent.tree_sortkey
                                         and tree_right(p_parent.tree_sortkey)
                                         and p_parent.project_id = :p_id
	        ) 
	"

	foreach cid [db_list del_cost_ids $sql] {
	    lappend del_cost_ids $cid
	}

	# Missing TS items 
	# Check if there are im_cost items with no TS record 
	set sql "
        select  
            c.cost_id
        from 
            im_costs c
        where 
            c.project_id in (
                     select      p_child.project_id
                     from        im_projects p_parent,
                                 im_projects p_child
                     where       p_child.tree_sortkey between p_parent.tree_sortkey
                                 and tree_right(p_parent.tree_sortkey)
                                 and p_parent.project_id = :p_id
            )
            and c.cost_type_id = 3718
            and c.cost_id not in (
                select cost_id from im_hours where project_id in (  
                         select      p_child.project_id
                       from        im_projects p_parent,
                                     im_projects p_child
                         where       p_child.tree_sortkey between p_parent.tree_sortkey
                                   and tree_right(p_parent.tree_sortkey)
                                     and p_parent.project_id = :p_id
                    )
            )
    	"

	foreach cid [db_list del_cost_ids $sql] {
	    lappend del_cost_ids $cid
	}

	# Mismatch btw. im_cost::amount and im_hours::hours * im_hours::billing_rate
        # Check if there are im_cost items with no TS record

	set sql "
            select 
                h.cost_id 
            from 
                im_hours h, 
                im_costs c 
            where 
                c.cost_id = h.cost_id 
                and c.amount <> (h.hours * h.billing_rate)
                and c.project_id = h.project_id 
                and c.project_id in (
                    select      p_child.project_id
                    from        im_projects p_parent,
                                im_projects p_child
                    where       p_child.tree_sortkey between p_parent.tree_sortkey
                                and tree_right(p_parent.tree_sortkey)
                                and p_parent.project_id = :p_id
                )
	"

        foreach cid [db_list del_cost_ids $sql] {
            lappend del_cost_ids $cid
        }



        # Missing Cost Items. Cost items miss project_id and have amount = 0  
	set sql "	
            select
                h.cost_id
            from
                im_hours h
            where
                h.project_id in (
                         select      p_child.project_id
                         from        im_projects p_parent,
                                     im_projects p_child
                         where       p_child.tree_sortkey between p_parent.tree_sortkey
                                     and tree_right(p_parent.tree_sortkey)
                                     and p_parent.project_id = :p_id
                )
                and h.cost_id not in (
                    select cost_id from im_costs where project_id in (
                             select     p_child.project_id
                             from       im_projects p_parent,
                                        im_projects p_child
                             where      p_child.tree_sortkey between p_parent.tree_sortkey
                                       	and tree_right(p_parent.tree_sortkey)
                                        and p_parent.project_id = :p_id
                        )
                )
	"

        foreach cid [db_list del_cost_ids $sql] {
            lappend del_cost_ids $cid
        }
    }

    foreach cost_id $del_cost_ids {
	db_dml update_hours "update im_hours set cost_id = null where cost_id = :cost_id"
	db_string del_ts_costs "select im_cost__delete(:cost_id)"
    }

    # Set dirty flag for project 
    db_dml set_dirty_flag "update im_projects set cost_cache_dirty=now() where project_id = $p_id"
    
    im_timesheet_update_timesheet_cache -project_id $p_id
    im_timesheet2_sync_timesheet_costs -project_id $p_id
    
    # Recalculate the cost caches
    im_cost_cache_sweeper
    
    # Reset
    unset del_cost_ids

}

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


set im_report_get_ts_costs_im_costs_sql "
        CREATE OR REPLACE FUNCTION pg_temp.im_report_get_ts_costs_im_costs (int4)
        RETURNS NUMERIC AS \$BODY\$

        declare
                p_project_id        alias for \$1;
                v_sum_ts_cost       numeric;
                v_total_ts_cost     numeric;
                r                   record;

        begin
                v_total_ts_cost := 0;
                    FOR r IN
                        select      amount
                        from        im_costs
                        where       project_id = p_project_id
				    and cost_type_id = [im_cost_type_timesheet]
                LOOP
                        v_sum_ts_cost := r.amount;
                        IF v_sum_ts_cost is null THEN
                                v_sum_ts_cost := 0;
                        END IF;
                        v_total_ts_cost := v_total_ts_cost + v_sum_ts_cost;
                        v_sum_ts_cost := 0;
                END LOOP;
                return v_total_ts_cost;

        end;\$BODY\$ LANGUAGE 'plpgsql';
"

db_dml create_im_report_get_ts_costs_im_costs_sql $im_report_get_ts_costs_im_costs_sql


set im_report_get_ts_costs_no_cache_im_hours_sql "
	CREATE OR REPLACE FUNCTION pg_temp.im_report_get_ts_costs_no_cache_im_hours (int4)
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
db_dml create_im_report_get_ts_costs_no_cache_im_hours_sql $im_report_get_ts_costs_no_cache_im_hours_sql

set im_report_get_ts_costs_no_cache_im_costs_sql "
        CREATE OR REPLACE FUNCTION pg_temp.im_report_get_ts_costs_no_cache_im_costs (int4)
        RETURNS NUMERIC AS \$BODY\$

        declare
        p_project_id        alias for \$1;
        v_child_project_id  int;
        v_sum_ts_cost       numeric;
        v_total_ts_cost     numeric;
        r                   record;

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

                select pg_temp.im_report_get_ts_costs_im_costs(r.project_id) into v_sum_ts_cost;
                v_total_ts_cost := v_total_ts_cost + v_sum_ts_cost;
                v_sum_ts_cost := 0;
        END LOOP;
        return v_total_ts_cost;
        end;\$BODY\$ LANGUAGE 'plpgsql';
"
db_dml create_im_report_get_ts_costs_no_cache_im_costs_sql $im_report_get_ts_costs_no_cache_im_costs_sql


# ------------------------------------------------------------
# Report SQL 

set criteria [list]
if { $project_status_id ne "" && $project_status_id > 0 } {
    lappend criteria "p.project_status_id in ([join [im_sub_categories $project_status_id] ","])"
}
if {"" != $start_date} {
    lappend criteria "p.start_date >= :start_date::timestamptz"
}

set where_clause [join $criteria " and\n            "]
if { $where_clause ne "" } {
    set where_clause " and $where_clause"
}

set sql "
	select 
		'<a href=\"/intranet/projects/view?project_id=' || p.project_id  || '\">' || p.project_name || '</a>' as project_name,
		p.project_id,
		to_char(p.end_date, 'YYYY-MM-DD') as start_date,
 		to_char(p.end_date, 'YYYY-MM-DD') as end_date,
		pg_temp.im_report_get_ts_costs_no_cache_im_hours(p.project_id) as costs_no_cache_im_hours,

		CASE p.cost_timesheet_logged_cache is null OR p.cost_timesheet_logged_cache = 0
			WHEN true THEN 
				0
			ELSE	
				cost_timesheet_logged_cache
		END as cost_timesheet_logged_cache,
		pg_temp.im_report_get_ts_costs_no_cache_im_hours(p.project_id) - p.cost_timesheet_logged_cache as diff,
                pg_temp.im_report_get_ts_costs_no_cache_im_costs(p.project_id) as costs_no_cache_im_costs,
		im_name_from_id(p.project_status_id) as status
	from 
		im_projects p 
	where 
		p.parent_id is null
		$where_clause
	order by 
		p.project_id
"

# ------------------------------------------------------------
# Start Formatting the HTML Page Contents

ad_return_top_of_page "
	[im_header]
	[im_navbar]
        <form method='POST'>
	<table cellspacing=0 cellpadding=5 border=0>
        <tr valign=top>
          <td width='30%'>
                <!-- 'Filters' - Show the Report parameters -->

                <table cellspacing=2>
                <tr class=rowtitle>
                  <td class=rowtitle colspan=2 align=center>Filters</td>
                </tr>
                <tr>
                  <td>Project Status</td>
                  <td>
                    <!--[im_project_status_select project_status_id $project_status_id]-->
		    [im_category_select -include_empty_p 1 "Intranet Project Status" project_status_id $project_status_id]
                  </td>
                </tr>
                <tr>
                  <td><nobr>Show projects starting after:</nobr></td>
                  <td><input type=text name=start_date value='$start_date'></td>
                </tr>
                <tr>
                  <td><nobr>Show only project with differences:</nobr></td>
                  <td><input type='checkbox' name='show_diff_only_p' value='1' $show_diff_only_p_checked></td>
                </tr>
                <tr>
                  <td</td>
                  <td><input type=submit value='Submit'></td>
                </tr>
                </table>
          </td>
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
                <td><strong>TS Costs<br>im_costs</strong></td>\n
                <td><strong>TS Costs<br>(Cached)</strong></td>\n
                <td><strong>TS Costs<br>im_hours</strong></td>\n
                <td><strong>Difference</strong></td>\n
                <td><strong>Project Status</strong></td>\n
                <td><strong>Fix</strong></td>\n
             </tr>
"

set diff_total 0 
db_foreach r $sql {

    if { "" == $diff } { set diff 0 }
    if { [info exists show_diff_only_p] && 0 == $diff } { continue }

    set diff_total [expr {$diff_total + $diff}]
    ns_write "<tr>\n
		<td>$project_name</td>\n
		<td>[expr {double(round(100*$costs_no_cache_im_costs))/100}]</td>\n
		<td>$cost_timesheet_logged_cache</td>\n
		<td>[expr {double(round(100*$costs_no_cache_im_hours))/100}]</td>\n
    "

    if { 0 == $diff } {
	ns_write "<td><span style=\"color:green\">[format "%.2f" [expr {double(round(100*$diff))/100}]]</span></td>\n"
    } else {
	ns_write "<td><span style=\"color:red\">[format "%.2f" [expr {double(round(100*$diff))/100}]]</span></td>\n"
    }

    ns_write "
		<td>$status</td>\n
		<td><input type='checkbox' name='fix_project_id.$project_id'/></td>\n
	      </tr>
    "
}

ns_write "
    	<tr>\n
                <td><strong>Total:</strong></td>\n
                <td>&nbsp;</td>\n
                <td>&nbsp;</td>\n
                <td>&nbsp;</td>\n
		<td>[format "%.2f" [expr {double(round(100*$diff_total))/100}]]</td>\n
                <td colspan='2' align='right'><input name='btn' type=submit value='Fix marked projects'></td>\n
        </tr>
	</table><br><br>
        </form>
	[im_footer]
"
