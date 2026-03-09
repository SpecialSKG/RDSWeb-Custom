<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="../Site.xsl"?>
<?xml-stylesheet type="text/css" href="../RenderFail.css"?>
<% @Page Language="C#" Debug="false" ResponseEncoding="utf-8" ContentType="text/xml" Async="true" %>
<% @Import Namespace="System " %>
<% @Import Namespace="System.Security" %>
<% @Import Namespace="System.Threading.Tasks" %>
<% @Import Namespace="Microsoft.TerminalServices.Publishing.Portal.FormAuthentication" %>
<% @Import Namespace="Microsoft.TerminalServices.Publishing.Portal" %>
<% @Import Namespace="System.Web.Security.AntiXss" %>
<script language="C#" runat=server>

    //
    // Customizable Text
    //
    string L_CompanyName_Text = "Recursos de trabajo";

    //
    // Localizable Text
    //
    const string L_DomainUserNameLabel_Text = "Dominio\\nombreDeUsuario:";
    const string L_PasswordLabel_Text = "Contraseña:";
    const string L_PasswordExpiredChangeBeginning_Text = "Su contraseña expiró. Haga clic ";
    const string L_PasswordExpiredChangeLink_Text = "aquí";
    const string L_PasswordExpiredChangeEnding_Text = " para cambiarla.";
    const string L_PasswordExpiredNoChange_Text = "Su contraseña expiró. Póngase en contacto con el administrador para obtener ayuda.";
    const string L_ExistingWorkspaceLabel_Text = "Otro usuario del equipo está usando actualmente esta conexión. Este usuario debe desconectarse para que usted pueda iniciar sesión.";
    const string L_DisconnectedWorkspaceLabel_Text = "Otro usuario del equipo se desconectó de esta conexión. Escriba de nuevo su nombre de usuario y contraseña.";
    const string L_LogonFailureLabel_Text = "El nombre de usuario o la contraseña que especificó no son válidos. Pruebe a escribirlos de nuevo.";
    const string L_DomainNameMissingLabel_Text = "Debe especificar un nombre de dominio válido.";
    const string L_AuthorizationFailureLabel_Text = "No está autorizado a iniciar sesión en esta conexión. Póngase en contacto con el administrador del sistema para que le autorice.";
    const string L_ServerConfigChangedLabel_Text = "Su sesión de Acceso web de RD expiró debido a algunos cambios en la configuración del equipo remoto. Inicie sesión de nuevo.";
    const string L_SecurityLabel_Text = "Seguridad";
    const string L_ShowExplanationLabel_Text = "mostrar explicación";
    const string L_HideExplanationLabel_Text = "ocultar explicación";
    const string L_PublicLabel_Text = "Éste es un equipo público o compartido";
    const string L_PublicExplanationLabel_Text = "Seleccione esta opción si usa Acceso web de RD en un equipo público. Asegúrese de cerrar la sesión cuando haya acabado de usar Acceso web de RD y cierre todas las ventanas para finalizar la sesión.";
    const string L_PrivateLabel_Text = "Éste es un equipo privado";
    const string L_PrivateExplanationLabel_Text = "Seleccione esta opción si es la única persona que usa este equipo. El servidor permitirá un período más largo de inactividad antes de cerrar la sesión.";
    const string L_PrivateWarningLabel_Text = "Advertencia: al seleccionar esta opción, confirma que este equipo cumple la directiva de seguridad de la organización.";
    const string L_PrivateWarningLabelNoAx_Text = "Advertencia: al iniciar sesión en esta página web, confirma que este equipo cumple la directiva de seguridad de la organización.";
    const string L_SignInLabel_Text = "Iniciar sesión";
    const string L_TSWATimeoutLabel_Text = "Para proporcionar protección contra accesos no autorizados, el tiempo de espera de su sesión de Acceso web de Escritorio remoto se agotará automáticamente tras un período de inactividad. Si finaliza la sesión, actualice el explorador y vuelva a iniciar sesión.";
    const string L_RenderFailTitle_Text = "Error: Acceso web de RD no se puede mostrar";
    const string L_RenderFailP1_Text = "Error inesperado que impide que esta página se muestre correctamente.";
    const string L_RenderFailP2_Text = "Este error puede surgir al visualizar la página en Internet Explorer con la configuración de seguridad mejorada habilitada.";
    const string L_RenderFailP3_Text = "Pruebe a cargar la página con la configuración de seguridad mejorada deshabilitada. Si el error persiste, póngase en contacto con el administrador."; 
    const string L_GenericClaimsAuthErrorLabel_Text = "No puede iniciar sesión ahora mismo, Inténtelo más tarde.";
    const string L_WrongAxVersionWarningLabel_Text = "No tiene la versión correcta de Conexión a Escritorio remoto para usar Acceso web de RD.";
    const string L_UnsupportedBrowserWarningLabel_Text = "El explorador web no es compatible con el servicio Microsoft RemoteApp. Use un explorador compatible.";
    const string L_SupportedBrowserAxLoadErrorLabel_Text = "El explorador tiene los controles ActiveX desactivados. Vaya a la configuración del explorador para activarlos.";
    const string L_ClaimsDomainUserNameLabel_Text = "Nombreusuario@dominio:";
    const string L_CookiesDisabledWarningLabel_Text = "El explorador tiene las cookies desactivadas. Vaya a la configuración del explorador para activarlas.";

    //
    // Page Variables
    //
    public string strErrorMessageRowStyle;
    public bool bFailedLogon = false, bFailedAuthorization = false, bFailedAuthorizationOverride = false, bServerConfigChanged = false, bWorkspaceInUse = false, bWorkspaceDisconnected = false, bPasswordExpired =  false, bPasswordExpiredNoChange = false;
    public string strWorkSpaceID = "";
    public string strRDPCertificates = "";
    public string strRedirectorName = "";
    public string strClaimsHint = "";
    public string strReturnUrl = "";
    public string strReturnUrlPage = "";
    public string strPasswordExpiredQueryString = "";
    public string strEventLogUploadAddress = "";
    public string sHelpSourceServer, sLocalHelp;
    public Uri baseUrl;
    public string strPrivacyUrl = "";

    public string strPrivateModeTimeout = "240";
    public string strPublicModeTimeout = "20";

    public WorkspaceInfo objWorkspaceInfo = null;

    void Page_PreInit(object sender, EventArgs e)
    {

        // Deny requests with "additional path information"
        if (Request.PathInfo.Length != 0)
        {
            Response.StatusCode = 404;
            Response.End();
        }

        // gives us https://<hostname>[:port]/rdweb/pages/<lang>/
        baseUrl = new Uri(new Uri(RequestHelper.GetOriginalRequestUri(Request), RequestHelper.GetRequestFilePath(Request)), ".");

        sLocalHelp = ConfigurationManager.AppSettings["LocalHelp"];
        if ((sLocalHelp != null) && (sLocalHelp == "true"))
        {
            sHelpSourceServer = "./rap-help.htm";
        }
        else
        {
            sHelpSourceServer = "http://go.microsoft.com/fwlink/?LinkId=141038";
        }
        
        try
        {
            strPrivateModeTimeout = ConfigurationManager.AppSettings["PrivateModeSessionTimeoutInMinutes"].ToString();
            strPublicModeTimeout = ConfigurationManager.AppSettings["PublicModeSessionTimeoutInMinutes"].ToString();
        }
        catch (Exception objException)
        {
        }
    }
    
    protected void Page_Load(object sender, EventArgs e)
    {
        RegisterAsyncTask(new PageAsyncTask(LoginPageLoadAsync));
        ExecuteRegisteredAsyncTasks();
    }
    
    private async Task LoginPageLoadAsync()
    {
        if ( Request.QueryString != null )
        {
            NameValueCollection objQueryString = Request.QueryString;
            if ( objQueryString["ReturnUrl"] != null )
            {
                strReturnUrlPage = objQueryString["ReturnUrl"];
                strReturnUrl = "?ReturnUrl=" + AntiXssEncoder.UrlEncode(strReturnUrlPage);
            }
            if ( objQueryString["Error"] != null )
            {
                if ( objQueryString["Error"].Equals("WkSInUse", StringComparison.CurrentCultureIgnoreCase) )
                {
                    bWorkspaceInUse = true;
                }
                else if ( objQueryString["Error"].Equals("WkSDisconnected", StringComparison.CurrentCultureIgnoreCase) )
                {
                    bWorkspaceDisconnected = true;
                }
                else if ( objQueryString["Error"].Equals("UnauthorizedAccess", StringComparison.CurrentCultureIgnoreCase) )
                {
                    bFailedAuthorization = true;
                }
                else if ( objQueryString["Error"].Equals("UnauthorizedAccessOverride", StringComparison.CurrentCultureIgnoreCase) )
                {
                    bFailedAuthorization = true;
                    bFailedAuthorizationOverride = true;
                }
                else if ( objQueryString["Error"].Equals("ServerConfigChanged", StringComparison.CurrentCultureIgnoreCase) )
                {
                    bServerConfigChanged = true;
                }
                else if ( objQueryString["Error"].Equals("PasswordExpired", StringComparison.CurrentCultureIgnoreCase) )
                {
                    string strPasswordChangeEnabled = ConfigurationManager.AppSettings["PasswordChangeEnabled"];

                    if (strPasswordChangeEnabled != null && strPasswordChangeEnabled.Equals("true", StringComparison.CurrentCultureIgnoreCase))
                    {
                        bPasswordExpired = true;
                        if (objQueryString["UserName"] != null)
                        {
                            strPasswordExpiredQueryString = "?UserName=" + Uri.EscapeDataString(objQueryString["UserName"]);
                        }
                    }
                    else
                    {
                        bPasswordExpiredNoChange = true;
                    }
                }
            }
        }

        //
        // Special case to handle 'ServerConfigChanged' error from Response's Location header.
        //
        try
        {
            if ( Response.Headers != null )
            {
                NameValueCollection objResponseHeader = Response.Headers;
                if ( !String.IsNullOrEmpty( objResponseHeader["Location"] ) )
                {
                    Uri objLocationUri = new Uri( objResponseHeader["Location"] );
                    if ( objLocationUri.Query.IndexOf("ServerConfigChanged") != -1 )
                    {
                        if ( !bFailedAuthorization )
                        {
                            bServerConfigChanged = true;
                        }
                    }
                }
            }
        }
        catch (Exception objException)
        {
        }

        if ( HttpContext.Current.User.Identity.IsAuthenticated != true )
        {
            // Only do this if we are actually rendering the login page, if we are just redirecting there is no need for these potentially expensive calls
            objWorkspaceInfo = PageContentsHelper.GetWorkspaceInfo();
            if ( objWorkspaceInfo != null )
            {
                strWorkSpaceID = objWorkspaceInfo.WorkspaceId;
                strRedirectorName = objWorkspaceInfo.RedirectorName;
                string strWorkspaceName = objWorkspaceInfo.WorkspaceName;
                if ( String.IsNullOrEmpty(strWorkspaceName ) == false )
                {
                    L_CompanyName_Text = strWorkspaceName;
                }
                if (!String.IsNullOrEmpty(objWorkspaceInfo.EventLogUploadAddress))
                {
                    strEventLogUploadAddress = objWorkspaceInfo.EventLogUploadAddress;
                }
            }
            strRDPCertificates = PageContentsHelper.GetRdpSigningCertificateHash();
            strClaimsHint = PageContentsHelper.GetClaimsHint();

            strPrivacyUrl = await PageContentsHelper.GetPrivacyLinkAsync();
        }

        if ( HttpContext.Current.User.Identity.IsAuthenticated == true )
        {
            SafeRedirect(strReturnUrlPage);
        }
        else if ( HttpContext.Current.Request.HttpMethod.Equals("POST", StringComparison.CurrentCultureIgnoreCase) == true )
        {
            bFailedLogon = true;
            if ( bFailedAuthorization )
            {
                bFailedAuthorization = false; // Make sure to show one message.
            }
        }

        if (bPasswordExpired)
        {
            bFailedLogon = false;
        }

        if (bFailedAuthorizationOverride)
        {
            bFailedLogon = false;
        }
        
        Response.Cache.SetCacheability(HttpCacheability.NoCache);
    }
    
    private void SafeRedirect(string strRedirectUrl)
    {
        string strRedirectSafeUrl = null;

        if (!String.IsNullOrEmpty(strRedirectUrl))
        {
            Uri baseUrl = RequestHelper.GetOriginalRequestUri(Request);
            Uri redirectUri = new Uri(new Uri(baseUrl, RequestHelper.GetRequestFilePath(Request)), strRedirectUrl);

            if (
                redirectUri.Authority.Equals(baseUrl.Authority) &&
                redirectUri.Scheme.Equals(baseUrl.Scheme)
               )
            {
                strRedirectSafeUrl = redirectUri.AbsoluteUri;   
            }

        }

        if (strRedirectSafeUrl == null)
        {
            strRedirectSafeUrl = "default.aspx";
        }

        Response.Redirect(strRedirectSafeUrl);       
    }
</script>
<RDWAPage 
    helpurl="<%=sHelpSourceServer%>" 
    workspacename="<%=AntiXssEncoder.XmlAttributeEncode(L_CompanyName_Text)%>" 
    baseurl="<%=SecurityElement.Escape(baseUrl.AbsoluteUri)%>"
    privacyurl="<%=AntiXssEncoder.XmlAttributeEncode(strPrivacyUrl)%>"
    >
  <RenderFailureMessage>
    <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
            <title><%=L_RenderFailTitle_Text%></title>
        </head>
        <body>
            <h1><%=L_RenderFailTitle_Text%></h1>
            <p><%=L_RenderFailP1_Text%></p>
            <p><%=L_RenderFailP2_Text%></p>
            <p><%=L_RenderFailP3_Text%></p>
        </body>
    </html> 
  </RenderFailureMessage>
  <BodyAttr 
    onload="onLoginPageLoad(event)" 
    onunload="onPageUnload(event)"/>
  <HTMLMainContent>
  
      <form id="FrmLogin" name="FrmLogin" action="login.aspx<%=SecurityElement.Escape(strReturnUrl)%>" method="post" onsubmit="return onLoginFormSubmit()">

        <input type="hidden" name="WorkSpaceID" value="<%=SecurityElement.Escape(strWorkSpaceID)%>"/>
        <input type="hidden" name="RDPCertificates" value="<%=SecurityElement.Escape(strRDPCertificates)%>"/>
        <input type="hidden" name="PublicModeTimeout" value="<%=SecurityElement.Escape(strPublicModeTimeout)%>"/>
        <input type="hidden" name="PrivateModeTimeout" value="<%=SecurityElement.Escape(strPrivateModeTimeout)%>"/>
        <input type="hidden" name="WorkspaceFriendlyName" value="<%=AntiXssEncoder.UrlEncode(L_CompanyName_Text)%>"/>
        <input type="hidden" name="EventLogUploadAddress" value="<%=SecurityElement.Escape(strEventLogUploadAddress)%>"/>
        <input type="hidden" name="RedirectorName" value="<%=SecurityElement.Escape(strRedirectorName)%>"/>
        <input type="hidden" name="ClaimsHint" value="<%=SecurityElement.Escape(strClaimsHint)%>"/>
        <input type="hidden" name="ClaimsToken" value=""/>

        <input name="isUtf8" type="hidden" value="1"/>
        <input type="hidden" name="flags" value="0"/>


        <table id="tableLoginDisabled" width="300" border="0" align="center" cellpadding="0" cellspacing="0" style="display:none">

            <tr id="trWrongAxVersion" style="display:none" >
            <td>
                <table>
                <tr>
                    <td height="20">&#160;</td>
                </tr>
                <tr>
                    <td><span class="wrng"><%=L_WrongAxVersionWarningLabel_Text%></span></td>
                </tr>
                </table>
            </td>
            </tr>

            <tr id="trUnsupportedBrowser" style="display:none" >
            <td>
                <table>
                <tr>
                    <td height="20">&#160;</td>
                </tr>
                <tr>
                    <td><span class="wrng"><%=L_UnsupportedBrowserWarningLabel_Text%></span></td>
                </tr>
                </table>
            </td>
            </tr> 

            <tr id="trSupportedBrowserAxLoadError" style="display:none" >
            <td>
                <table>
                <tr>
                    <td height="20">&#160;</td>
                </tr>
                <tr>
                    <td><span class="wrng"><%=L_SupportedBrowserAxLoadErrorLabel_Text%></span></td>
                </tr>
                </table>
            </td>
            </tr> 

            <tr id="trCookiesDisabled" style="display:none" >
            <td>
                <table>
                <tr>
                    <td height="20">&#160;</td>
                </tr>
                <tr>
                    <td><span class="wrng"><%=L_CookiesDisabledWarningLabel_Text%></span></td>
                </tr>
                </table>
            </td>
            </tr> 

            <tr>
                <td height="50">&#160;</td>
            </tr>

        </table>

        <table id="tableLoginForm" width="300" border="0" align="center" cellpadding="0" cellspacing="0" style="display:none">

            <tr>
            <td height="20">&#160;</td>
            </tr>

            <tr>
            <td>
                <table width="300" border="0" cellpadding="0" cellspacing="0">
                <tr>
                    <td id="tdDomainUserNameLabel" width="130" align="right" style="display:none"><%=L_DomainUserNameLabel_Text%></td>
                    <td id="tdClaimsDomainUserNameLable" width="130" align="right" style="display:none"><%=L_ClaimsDomainUserNameLabel_Text%></td>
                    <td width="7"></td>
                    <td align="right">
                    <label><input id="DomainUserName" name="DomainUserName" type="text" class="textInputField" runat="server" size="25" autocomplete="off" /></label>
                    </td>
                </tr>
                </table>
            </td>
            </tr>
            <tr>
            <td height="7"></td>
            </tr>

            <tr>
            <td>
                <table width="300" border="0" cellpadding="0" cellspacing="0">
                <tr>
                    <td width="130" align="right"><%=L_PasswordLabel_Text%></td>
                    <td width="7"></td>
                    <td align="right">
                    <label><input id="UserPass" name="UserPass" type="password" class="textInputField" runat="server" size="25" autocomplete="off" /></label>
                    </td>
                </tr>
                </table>
            </td>
            </tr>

    <%
    strErrorMessageRowStyle = "style=\"display:none\"";
    if ( bPasswordExpiredNoChange == true)
    {
    strErrorMessageRowStyle = "style=\"display:\"";
    }
    %>
            <tr id="trPasswordExpiredNoChange" <%=strErrorMessageRowStyle%> >
            <td>
                <table>
                <tr>
                    <td height="20">&#160;</td>
                </tr>
                <tr>
                    <td><span class="wrng"><%=L_PasswordExpiredNoChange_Text%></span></td>
                </tr>
                </table>
            </td>
            </tr>
               
    <%
    strErrorMessageRowStyle = "style=\"display:none\"";
    if ( bPasswordExpired == true)
    {
    strErrorMessageRowStyle = "style=\"display:\"";
    }
    %>
            <tr id="trPasswordExpired" <%=strErrorMessageRowStyle%> >
            <td>
                <table>
                <tr>
                    <td height="20">&#160;</td>
                </tr>
                <tr>
                    <td><span class="wrng"><%=L_PasswordExpiredChangeBeginning_Text%><a id = "passwordchangelink" href="password.aspx<%=strPasswordExpiredQueryString%>"><%=L_PasswordExpiredChangeLink_Text%></a><%=L_PasswordExpiredChangeEnding_Text%></span></td>
                </tr>
                </table>
            </td>
            </tr>

    <%
    strErrorMessageRowStyle = "style=\"display:none\"";
    if ( bWorkspaceInUse == true )
    {
    strErrorMessageRowStyle = "style=\"display:\"";
    }
    %>
            <tr id="trErrorWorkSpaceInUse" <%=strErrorMessageRowStyle%> >
            <td>
                <table>
                <tr>
                    <td height="20">&#160;</td>
                </tr>
                <tr>
                    <td><span class="wrng"><%=L_ExistingWorkspaceLabel_Text%></span></td>
                </tr>
                </table>
            </td>
            </tr>

    <%
    strErrorMessageRowStyle = "style=\"display:none\"";
    if ( bWorkspaceDisconnected == true )
    {
    strErrorMessageRowStyle = "style=\"display:\"";
    }
    %>
            <tr id="trErrorWorkSpaceDisconnected" <%=strErrorMessageRowStyle%> >
            <td>
                <table>
                <tr>
                    <td height="20">&#160;</td>
                </tr>
                <tr>
                    <td><span class="wrng"><%=L_DisconnectedWorkspaceLabel_Text%></span></td>
                </tr>
                </table>
            </td>
            </tr>

    <%
    strErrorMessageRowStyle = "style=\"display:none\"";
    if ( bFailedLogon == true )
    {
    strErrorMessageRowStyle = "style=\"display:\"";
    }
    %>
            <tr id="trErrorIncorrectCredentials" <%=strErrorMessageRowStyle%> >
            <td>
                <table>
                <tr>
                    <td height="20">&#160;</td>
                </tr>
                <tr>
                    <td><span class="wrng"><%=L_LogonFailureLabel_Text%></span></td>
                </tr>
                </table>
            </td>
            </tr>

            <tr id="trErrorDomainNameMissing" style="display:none" >
            <td>
                <table>
                <tr>
                    <td height="20">&#160;</td>
                </tr>
                <tr>
                    <td><span class="wrng"><%=L_DomainNameMissingLabel_Text%></span></td>
                </tr>
                </table>
            </td>
            </tr> 

    <%
    strErrorMessageRowStyle = "style=\"display:none\"";
    if ( bFailedAuthorization || bFailedAuthorizationOverride )
    {
    strErrorMessageRowStyle = "style=\"display:\"";
    }
    %>
            <tr id="trErrorUnauthorizedAccess" <%=strErrorMessageRowStyle%> >
            <td>
                <table>
                <tr>
                    <td height="20">&#160;</td>
                </tr>
                <tr>
                    <td><span class="wrng"><%=L_AuthorizationFailureLabel_Text%></span></td>
                </tr>
                </table>
            </td>
            </tr>

    <%
    strErrorMessageRowStyle = "style=\"display:none\"";
    if ( bServerConfigChanged )
    {
    strErrorMessageRowStyle = "style=\"display:\"";
    }
    %>
            <tr id="trErrorServerConfigChanged" <%=strErrorMessageRowStyle%> >
            <td>
                <table>
                <tr>
                    <td height="20">&#160;</td>
                </tr>
                <tr>
                    <td><span class="wrng"><%=L_ServerConfigChangedLabel_Text%></span></td>
                </tr>
                </table>
            </td>
            </tr>

            <tr id="trErrorGenericClaimsAuthFailure" style="display:none" >
            <td>
                <table>
                <tr>
                    <td height="20">&#160;</td>
                </tr>
                <tr>
                    <td><span class="wrng"><%=L_GenericClaimsAuthErrorLabel_Text%></span></td>
                </tr>
                </table>
            </td>
            </tr> 

            <tr>
            <td height="20">&#160;</td>
            </tr>
            <tr>
            <td height="1" bgcolor="#CCCCCC"></td>
            </tr>
            <tr>
            <td height="20">&#160;</td>
            </tr>

            <tr>
            <td>
                <table border="0" cellspacing="0" cellpadding="0">
                <tr>
                    <td><%=L_SecurityLabel_Text%>&#160;<span id="spanToggleSecExplanation" style="display:none">(<a href="javascript:onclickExplanation('lnkShwSec')" id="lnkShwSec"><%=L_ShowExplanationLabel_Text%></a><a href="javascript:onclickExplanation('lnkHdSec')" id="lnkHdSec" style="display:none"><%=L_HideExplanationLabel_Text%></a>)</span></td>
                </tr>
                </table>
            </td>
            </tr>
            <tr>
            <td height="5"></td>
            </tr>

            <tr>
            <td>
                <table border="0" cellspacing="0" cellpadding="0" style="display:none" id="tablePublicOption" >
                <tr>
                    <td width="30">
                    <label><input id="rdoPblc" type="radio" name="MachineType" value="public" class="rdo" onclick="onClickSecurity()" /></label>
                    </td>
                    <td><%=L_PublicLabel_Text%></td>
                </tr>
                <tr id="trPubExp" style="display:none" >
                    <td width="30"></td>
                    <td><span class="expl"><%=L_PublicExplanationLabel_Text%></span></td>
                </tr>
                <tr>
                    <td height="7"></td>
                </tr>
                </table>
            </td>
            </tr>

            <tr>
            <td>
                <table border="0" cellspacing="0" cellpadding="0" style="display:none" id="tablePrivateOption" >
                <tr>
                    <td width="30">
                    <label><input id="rdoPrvt" type="radio" name="MachineType" value="private" class="rdo" onclick="onClickSecurity()" checked="checked" /></label>
                    </td>
                    <td><%=L_PrivateLabel_Text%></td>
                </tr>
                <tr id="trPrvtExp" style="display:none" >
                    <td width="30"></td>
                    <td><span class="expl"><%=L_PrivateExplanationLabel_Text%></span></td>
                </tr>
                <tr>
                    <td height="7"></td>
                </tr>
                </table>
            </td>
            </tr>

            <tr>
            <td>
                <table border="0" cellspacing="0" cellpadding="0">
                <tr id="trPrvtWrn" style="display:none" >
                    <td width="30"></td>
                    <td><span class="wrng"><%=L_PrivateWarningLabel_Text%></span></td>
                </tr>
                </table>
            </td>
            </tr>

            <tr>
            <td>
                <table border="0" cellspacing="0" cellpadding="0">
                <tr id="trPrvtWrnNoAx" style="display:none">
                    <td><span class="wrng"><%=L_PrivateWarningLabelNoAx_Text%></span></td>
                </tr>
                </table>
            </td>
            </tr>

            <tr>
            <td height="20">&#160;</td>
            </tr>

            <tr>
            <td height="20">&#160;</td>
            </tr>
            <tr>
            <td align="right"><label><input type="submit" class="formButton" id="btnSignIn" value="<%=L_SignInLabel_Text%>" /></label>
            </td>
            </tr>

            <tr>
            <td height="20">&#160;</td>
            </tr>
            <tr>
            <td height="1" bgcolor="#CCCCCC"></td>
            </tr>

            <tr>
            <td height="20">&#160;</td>
            </tr>
            <tr>
            <td><%=L_TSWATimeoutLabel_Text%></td>
            </tr>

            <tr>
            <td height="30">&#160;</td>
            </tr>

        </table>

      </form>

  
  </HTMLMainContent>
</RDWAPage>
