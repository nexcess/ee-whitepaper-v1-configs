# Nexcess Varnish Configuration http://nexcess.net
# last-modified: 2013-09-06T12:43
# reference: https://ellislab.com/blog/entry/making-sites-fly-with-varnish

# backend configuration
backend default {
    .host = "ip.add.re.ss"; # IP address of your backend
    .port = "8080";         # Port your backend is listening on
    # backend health checks
    .probe = {
        .url = "/";         # test the home page
        .timeout = 10s;      # time for backend to respond
        .interval = 10s;    # check every 10s
        .window = 10;       # number of tests total
        .threshold = 8;     # number of successful tests required
    }
}


sub vcl_recv {
    ## Last resort, can use this to force client request protocol
    if(req.proto ~ "HTTP/1.0"){
        set req.proto = "HTTP/1.0";
    } else {
        set req.proto = "HTTP/1.1";
    }
   
    # forward client's IP to backend
    remove req.http.X-Forwarded-For;
    set req.http.X-Forwarded-For = client.ip;

    # if more than one site on the server, use the following to detect
    # set backend if correct domain, pass if not
    #if (req.http.host ~ "(?i)^(www\.)?domain\.com$") {
    #    set req.backend = default;
    #} else {
    #    # pass incorrect sites
    #    return (pass);
    #}

    # don't cache the following conditions
    if (req.url ~ "^/system/" ||
        req.url ~ "ACT=" ||
        req.request == "POST" ||
        # uncomment next line if ESI has been enabled in backend
        # (req.url ~ 'member_box' && req.http.Cookie ~ 'exp_sessionid'))
        # comment next line if ESI has been enabled in backend
        # don't cache for logged in users
        req.http.Cookie ~ "(exp_expiration|exp_uniqueid|exp_userhash|exp_sessionid)")
    {
        return (pass);
    }

    # pipe calls to mp3/ogg files to avoid timeouts
    if (req.url ~ "\.(mp3|ogg)") {
        return (pipe);
    }

    # don't cache captchas
    if (req.url ~ "/images/captchas/.*(jpg|gif|png)$") {
        return (pass);
    }

    # always cache static assets (except for logged in users)
    if (req.url ~ "\.(png|gif|jpg|swf|css|js)$") {
        return (lookup);
    }

    # ----- ExpressionEngine cookies -----
    # The logic will have already passed the request if the following
    # cookies are present:
    # exp_expiration
    # exp_uniqueid
    # exp_userhash
    # exp_sessionid
    #
    # So to anonymize non-logged-in visitors, we unset the request cookie
    unset req.http.Cookie;

    # Alternately, the following can be used to clean up client cookies
    # If you uncomment the following, comment out the line above.
    #if (req.http.Cookie) {
    #    set req.http.Cookie = ";" + req.http.Cookie;
    #    set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");
    #    set req.http.Cookie = regsuball(req.http.Cookie, ";(exp_expiration|exp_uniqueid|exp_userhash|exp_sessionid)=", "; \1=");
    #    set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
    #    set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");
    #
    #    if (req.http.Cookie == "") {
    #        remove req.http.Cookie;
    #    }
    #}
    # ----- END ExpressionEngine cookies -----

    # set grace time in case backend HTTP service crashes
    set req.grace = 15m;
    return (lookup);
}

sub vcl_fetch {
    # Uncomment the following if ESI is enabled
    # set beresp.do_esi = true;

    # cookie debug
    set beresp.http.X-Cookie-Request-Debug = "Request cookie: " + req.http.Cookie;
    set beresp.http.X-Cookie-Response-Debug = "Response cookie: " + beresp.http.Set-Cookie;

    # 30 second TTL for everything cached
    set beresp.ttl = 30 s;

    # set grace time in case backend HTTP service crashes
    #set beresp.grace = 15m;
    ## checking if this helps with 503s
    set beresp.grace = 15s;

    if (req.url ~ "/images/logo_small.gif") {
        set beresp.ttl = 24h;
    }

    return (deliver);
}

sub vcl_deliver {
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
        set resp.http.X-Cache-Hits = obj.hits;
    } else {
        set resp.http.X-Cache = "MISS";
    }
}

sub vcl_error {

        set obj.http.Content-Type = "text/html; charset=utf-8";
        set obj.http.Retry-After = "5";

        synthetic {"

                <head>
                <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
                <title></title>
                <style type="text/css">
                <body>
                <div style="margin: 0 auto; width: 400px; padding-top: 35px;">
                <p>
                <h1 id="logo-down">Error Logo</h1></p>
                <p>The site is experiencing technical difficulties at this time.
                We're working to resolve the problem quickly. </p>
                <p>We apologize for the inconvenience. </p>
                </div>
                </body>
                </html>
        "};

        return (deliver);
}
