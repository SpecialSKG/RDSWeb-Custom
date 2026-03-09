<%@ Page Language="C#"%>
<%
    string redirectUrl = "es-ES/Default.aspx";
    if (Request.Url.Query != null && Request.Url.Query.Length > 0) {
        redirectUrl += Request.Url.Query;
    }
    Response.Redirect(redirectUrl);
%>