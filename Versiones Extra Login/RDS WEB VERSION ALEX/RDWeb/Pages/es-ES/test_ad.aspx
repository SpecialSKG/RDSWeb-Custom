<%@ Page Language="C#" %>
<%@ Import Namespace="System.DirectoryServices.AccountManagement" %>
<%@ Import Namespace="System.DirectoryServices" %>
<%
    string result = "";
    string username = Request.QueryString["user"] ?? "EXTERNO";
    try {
        using(PrincipalContext ctx = new PrincipalContext(ContextType.Domain)) {
            UserPrincipal user = UserPrincipal.FindByIdentity(ctx, username);
            if (user != null) {
                result += "PrincipalContext Success: " + user.DisplayName + "<br/>";
            } else {
                result += "PrincipalContext: User not found<br/>";
            }
        }
    } catch (Exception ex) {
        result += "PrincipalContext Exception: " + ex.Message + "<br/>" + ex.StackTrace + "<br/><br/>";
    }

    try {
        DirectoryEntry rootEntry = new DirectoryEntry("LDAP://rootDSE");
        string defaultNamingContext = rootEntry.Properties["defaultNamingContext"].Value.ToString();
        result += "DefaultContext: " + defaultNamingContext + "<br/>";
        using (DirectoryEntry entry = new DirectoryEntry("LDAP://" + defaultNamingContext)) {
            using (DirectorySearcher searcher = new DirectorySearcher(entry)) {
                searcher.Filter = "(sAMAccountName=" + username.Replace("LAB-MH\\", "") + ")";
                searcher.PropertiesToLoad.Add("displayName");
                SearchResult searchResult = searcher.FindOne();
                if (searchResult != null && searchResult.Properties["displayName"].Count > 0) {
                    result += "DirectorySearcher Success: " + searchResult.Properties["displayName"][0].ToString() + "<br/>";
                } else {
                    result += "DirectorySearcher: Not found<br/>";
                }
            }
        }
    } catch (Exception ex) {
        result += "DirectorySearcher Exception: " + ex.Message + "<br/>" + ex.StackTrace + "<br/>";
    }

    Response.Write(result);
%>
