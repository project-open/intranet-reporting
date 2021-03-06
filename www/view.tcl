# /packages/intranet-reporting/www/view.tcl
#
# Copyright (c) 2003-2007 ]project-open[
# frank.bergmann@project-open.com
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

# ---------------------------------------------------------------
# Page Contract
# ---------------------------------------------------------------

ad_page_contract {
    Show the results of a single "dynamic" report or indicator
    @param format One of {html|csv|xml|json}

    @author frank.bergmann@project-open.com
} {
    { report_id:integer "" }
    { report_code "" }
    { format "html" }
    { no_template_p 0 }
    {return_url "/intranet-reporting/index"}
    { user_id:integer 0}
    { auto_login "" }
    { email "" }
    { password "" }
}


# ---------------------------------------------------------------
# Defaults

set org_report_id $report_id
set org_report_code $report_code

# Accept a report_code as an alternative to the report_id parameter.
# This allows us to access this page via a REST interface more easily,
# because the object_id of a report may vary across systems.
if {"" != $report_code} {
    set id [db_string code_id "select report_id from im_reports where report_code = :report_code" -default ""]
    if {"" != $id} { set report_id $id }
}


# ---------------------------------------------------------------
# Authentication

set current_user_id 0

# Email + password
if {"" != $password && "" != $email} {
    array set result_array [auth::authenticate \
		    -email $email \
		    -password $password \
		   ]

    set account_status "undefined"
    set auth_message ""
    set user_id 0
    if {[info exists result_array(account_status)]} { set account_status $result_array(account_status) }
    if {[info exists result_array(user_id)]} { set user_id $result_array(user_id) }
    if {[info exists result_array(auth_message)]} { set auth_message $result_array(auth_message) }

    if {"ok" == $account_status && 0 != $user_id} { 
	set current_user_id $user_id
    } else {
        ad_return_complaint 1 "<b>[lang::message::lookup "" intranet-core.Wrong_Security_Token "Wrong Security Token"]</b>:<br>
        [lang::message::lookup "" intranet-core.Wrong_Security_Token_msg "Your security token is not valid. Please contact the system owner."]<br><pre>$auth_message</pre>"
	ad_script_abort
    }
}



if {"" != $auto_login} {

    # Provide a reasonable error message if a rookie user forgot to put user_id...
    if {"" == $user_id || 0 == $user_id} {
	set msg_l10n [lang::message::lookup "" intranet-reporting.User_id_if_auto_login "You need to specify the parameter user_id if you specify the parameter auto_login."]
	im_reporting_rest_error -format $format -error_message $msg_l10n
    }

    set valid_login_p [im_valid_auto_login_p -user_id $user_id -auto_login $auto_login]
    if {$valid_login_p} { 
	set current_user_id $user_id 
    }

}

if {0 == $current_user_id} {
    set no_redirect_p 0
    if {"xml" == $format || "json" == $format} { set no_redirect_p 1 }
    set current_user_id [im_require_login -no_redirect_p $no_redirect_p]
}


if {("xml" == $format || "json" == $format) && 0 == $current_user_id} {
    # Return a XML authentication error
    im_rest_error -http_status 401 -message "intranet-reporting/view.tcl: Not authenticated"
    ad_script_abort
}

ns_log Notice "/intranet-reporting/view: after im_require_login: user_id=$current_user_id"

# ---------------------------------------------------------------
# Check if the report exists
#
set menu_id [db_string menu "select report_menu_id from im_reports where report_id = :report_id" -default 0]
if {0 == $menu_id} {
    set msg_l10n [lang::message::lookup "" intranet-reporting.The_report_does_not_exist "The specified report does not exist: report_code=%org_report_code%, report_id=%org_report_id%"]
    im_reporting_rest_error -format $format -error_message $msg_l10n
}


# ---------------------------------------------------------------
# Check security
#
set read_p [db_string report_perms "
        select  im_object_permission_p(m.menu_id, :current_user_id, 'read')
        from    im_menus m
        where   m.menu_id = :menu_id
" -default 'f']
if {"t" ne $read_p } {
    set msg_l10n [lang::message::lookup "" intranet-reporting.You_dont_have_permissions "You don't have the necessary permissions to view this page"]
    im_reporting_rest_error -format $format -error_message $msg_l10n
}


# ---------------------------------------------------------------
# Get Report Info

db_1row report_info "
	select	r.*,
		im_category_from_id(report_type_id) as report_type
	from	im_reports r
	where	report_id = :report_id
"

set page_title "$report_type: $report_name"
set page_title $report_name
set context [im_context_bar $page_title]


# ---------------------------------------------------------------
# Variable substitution in the SQL statement
#
set substitution_list [list user_id $current_user_id]
set form_vars [ns_conn form]
foreach form_var [ad_ns_set_keys $form_vars] {
    set form_val [im_opt_val -limit_to nohtml $form_var]
    lappend substitution_list $form_var
    lappend substitution_list $form_val
}

set report_sql_subst [lang::message::format $report_sql $substitution_list]


# ---------------------------------------------------------------
# Calculate the report
#
set page_body [im_ad_hoc_query \
	-package_key "intranet-reporting" \
	-report_name $report_name \
	-format $format \
	$report_sql_subst \
]

# ---------------------------------------------------------------
# Return the right HTTP response, depending on $format
#
switch $format {
    "csv" {
	# Return file with ouput header set
	set report_key [string tolower $report_name]
	regsub -all {[^a-zA-z0-9_]} $report_key "_" report_key
	regsub -all {_+} $report_key "_" report_key
	set outputheaders [ns_conn outputheaders]
	ns_set cput $outputheaders "Content-Disposition" "attachment; filename=${report_key}.csv"
	doc_return 200 "application/csv" $page_body
	ad_script_abort
    }
    "xml" {
	# Return plain file
	doc_return 200 "application/xml" $page_body
	ad_script_abort
    }
    "json" {
	set result "{\"success\": true,\n\"message\": \"Data loaded\",\n\"data\": \[$page_body\n\]\n}"
	doc_return 200 "text/plain" $result
	ad_script_abort
    }
    "plain" {
	ad_return_complaint 1 "Not Defined Yet"
    }
    default {
	# just continue with the page to format output using template
    }
}


if {$no_template_p} {
    doc_return 200 "text/html" $page_body
    ad_script_abort
}


# ---------------------------------------------------------------
# Check for URL parameters to pass to filter form
# This is necessary because reports may have any
# type of %...% variables in the URL
# ---------------------------------------------------------------

set query_set [ns_parsequery [ns_conn query]]
set form_set [ns_getform]
array set query_hash [ns_set array [ns_set merge $query_set $form_set]]

set export_vars [list]
foreach var [array names query_hash] {
    if {$var in {"" "format" "submit"}} { continue }
    if {![regexp {^[a-zA-Z0-9_]+$} $var]} { continue }

    # Add the variable to be exported by the filter form
    lappend export_vars $var

    # Get the value in a save way and write to local variable
    set value ""
    if {[info exists query_hash($var)]} { set value $query_hash($var) }
    set $var $value
}


# ---------------------------------------------------------------
# Format the Filter
# ---------------------------------------------------------------

set filter_html "
	<form method=get name=filter action='/intranet-reporting/view'>
	[export_vars -form $export_vars]
	<table border=0 cellpadding=0 cellspacing=1>
	<tr>
	    <td class=form-label>[lang::message::lookup "" intranet-reporting.Format "Format"]</td>
	    <td class=form-widget>[im_report_output_format_select format "" $format]</td>
	</tr>
<!-- im_ad_hoc_query doesn't understand number format...
	<tr>
	    <td class=form-label>[lang::message::lookup "" intranet-reporting.Number_Format "Number Format"]</td>
	    <td class=form-widget>[im_report_number_locale_select number_format]</td>
	</tr>
-->
	<tr>
	    <td class=form-label></td>
	    <td class=form-widget>
		  <input type=submit value='[lang::message::lookup "" intranet-core.Action_Go "Go"]' name=submit>
	    </td>
	</tr>
	</table>
	</form>
"

# Left Navbar is the filter/select part of the left bar
set left_navbar_html "
	<div class='filter-block'>
        	<div class='filter-title'>
	           [lang::message::lookup "" intranet-reporting.Report_Options "Report Options"]
        	</div>
            	$filter_html
      	</div>
      <hr/>
"

append left_navbar_html "
      	<div class='filter-block'>
        <div class='filter-title'>
            [lang::message::lookup "" intranet-reporting.Description "Description"]
        </div>
	    [ns_quotehtml $report_description]
      	</div>
"
