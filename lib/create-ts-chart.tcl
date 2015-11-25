
template::head::add_css -href "/intranet-sencha/css/ext-all.css" -media "screen" -order 100
template::head::add_javascript -src "/intranet-sencha/js/ext-all.js" -order 100

# Manipulate sql to extract data for chart to be created  
# Cut 'select' part 
set no_records_found_msg ""

set position_from [expr {[string first "FROM " $sql] -1}]
set sql_no_select [string range $sql $position_from end]

# Cut 'order by' part 
set position_order [expr {[string first "ORDER BY " $sql_no_select] -1}]
set sql_no_select_no_order [string range $sql_no_select 0 $position_order ]

switch $chart_type {
    chart_type_pie_customer {
	   # Construct new sql 
	   set sql_new "
	   	  	select 
     			 sum(Coalesce(h.hours, 0)) as hours,
				 c.company_path
				 $sql_no_select_no_order
			group by 
				 c.company_path
		"
	   set json_data ""

	   db_foreach rec $sql_new {
		  append json_data "{\"name\":\"$company_path\", \"data1\":\"$hours\"},"
	   }
	   if { "" == $json_data  } {
		  set no_records_found_msg [lang::message::lookup "" intranet-reporting.NoRecordsFound "No records found"]		  
	   } else {
		  # remove last comma
		  set json_data [string range $json_data 0 end-1]
		  set json_data_fields "'name', 'data1'"
	   }
    }
    chart_type_pie_project_type {
	   # Construct new sql 
	   set sql_new "
	   	  	select 
     			sum(Coalesce(h.hours, 0)) AS hours,
				(select category from im_categories where category_id = main_p.project_type_id) as project_type
				$sql_no_select_no_order
			group by 
				project_type
	   "
	   set json_data ""
	   
	   db_foreach rec $sql_new {
		  append json_data "{\"name\":\"$project_type\", \"data1\":\"$hours\"},"
	   }

        if { "" == $json_data } {
		  set no_records_found_msg [lang::message::lookup "" intranet-reporting.NoRecordsFound "No records found"]
	   } else {
		  # remove last comma
		  set json_data [string range $json_data 0 end-1]
		  set json_data_fields "'name', 'data1'"
	   }
    }

    default {
	   set json_data ""
	   set json_data_fields ""
	   set no_records_found_msg [lang::message::lookup "" intranet-reporting.NoRecordsFound "No records found"]
    }
}
