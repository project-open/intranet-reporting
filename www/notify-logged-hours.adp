<master src="../../intranet-core/www/master">
<property name=title>@page_title;noquote@</property>
<property name="context">@context;noquote@</property>
<property name="main_navbar_label">user</property>
<H1>#intranet-core.Send_Notification#</H1>
To: <%=$name_recipient%>
<table>
<form method="post" action="notify-logged-hours-2">
@export_vars;noquote@
<tr>
  <td>
<textarea name=subject rows=1 cols=70 wrap="<%=[im_html_textarea_wrap]%>">
 <%=[lang::message::lookup "" intranet-reporting.Mail_Reminder_Log_Hours_Subject "Reminder - Please log your hours"]%>
</textarea>
  </td>
</tr>
<tr>
  <td>
<textarea name=message rows=10 cols=70 wrap="<%=[im_html_textarea_wrap]%>">
 <%=[lang::message::lookup "" intranet-reporting.Mail_Reminder_Log_Hours_Text "This is a friendly reminder to log your hours for the period: \n %start_date% - %end_date% \n\n %first_names% %last_name%"] %> 
</textarea>
  </td>
</tr>
<tr>
  <td>
<center>
<input type="submit" value="<%=[lang::message::lookup "" intranet-reporting.SendMail "Send Mail"]%>" />
<input type=checkbox name=send_me_a_copy value=1>
<%= [lang::message::lookup "" intranet-core.Send_me_a_copy "Send me a copy"] %>
</center>
  </td>
</tr>
</form>
</table>
</p>



