<%@ Page Language="C#" %>

<script language="C#" runat="server">

void Page_Load(Object sender, EventArgs e)
{
    // Deny requests with "additional path information"
    if (Request.PathInfo.Length != 0)
    {
        Response.StatusCode = 404;
        Response.End();
    }
    
    Regex queryRegex = new Regex(@"^\?\d+;(.+)$");  // extracts the original requested URL
    Match queryMatch = queryRegex.Match(Request.Url.Query);
    UriBuilder target = null;
    
    if (queryMatch.Success)
    {
        try
        {
            target = new UriBuilder(queryMatch.Groups[1].Value);
        }
        catch (UriFormatException)
        {      
        }
    }

    if (target != null &&
        target.Scheme == Uri.UriSchemeHttp &&
        target.Host == Request.Url.Host
        )            
    {
        target.Scheme = Uri.UriSchemeHttps;
        target.Port = -1;
        Response.Redirect(target.Uri.ToString());
    }
    else
    { 
        Response.StatusCode = 404;
    }
}

</script>
