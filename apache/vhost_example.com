<VirtualHost IP.AD.DR.ESS:80>

  SuexecUserGroup example example

  DocumentRoot /home/example/ee.example.com/html
  ServerName ee.example.com

  ServerAlias www.ee.example.com ftp.ee.example.com mail.ee.example.com example.com www.example.com
  ServerAlias ftp.example.com mail.example.com
  ServerAdmin webmaster@ee.example.com

  # subdomain logic
  RewriteEngine On
  RewriteOptions inherit
  RewriteCond %{HTTP_HOST} !^www\.ee\.example\.com [NC]
  RewriteCond %{HTTP_HOST} !^ee\.example\.com [NC]
  RewriteCond %{HTTP_HOST} ^([A-Z0-9a-z-.]+)\.ee\.example\.com [NC]
  RewriteCond %{DOCUMENT_ROOT}/%1 -d
  <IfModule mod_fastcgi.c>
  RewriteCond %{REQUEST_URI} !^/php\.fcgi
  </IfModule>
  RewriteRule ^(.+) %{HTTP_HOST}/$1 [C]
  RewriteRule ^([0-9A-Za-z-.]+)\.ee\.example\.com/?(.*)$ %{DOCUMENT_ROOT}/$1/$2 [L]

  RewriteCond %{HTTP_HOST} ^www\.([A-Z0-9a-z-.]+)\.ee\.example\.com [NC]
  RewriteCond %{DOCUMENT_ROOT}/%1 -d
  RewriteRule ^(.+) %{HTTP_HOST}/$1 [C]
  <IfModule mod_fastcgi.c>
  RewriteCond %{REQUEST_URI} !^/php\.fcgi
  </IfModule>
  RewriteRule ^www\.([0-9A-Za-z-.]+)\.ee\.example\.com/?(.*)$ %{DOCUMENT_ROOT}/$1/$2 [L]
  # end subdomain logic

  ErrorLog /home/example/var/ee.example.com/logs/error.log
  CustomLog /home/example/var/ee.example.com/logs/transfer.log combined

  # php: default  don't edit between this and the "end php" comment below
  <IfModule mod_suphp.c>
    suPHP_Engine On
    suPHP_UserGroup example example
    AddHandler x-httpd-php .php
    suPHP_AddHandler x-httpd-php .php
    suPHP_ConfigPath /home/example/etc
  </IfModule>

  <IfModule !mod_suphp.c>
    <IfModule mod_php5.c>
      php_admin_flag engine On
    </IfModule>
    <IfModule mod_php4.c>
      php_admin_flag engine On
    </IfModule>
  </IfModule>

  <IfModule mod_fastcgi.c>
    Alias /php.fcgi /dev/shm/example-php.fcgi
  </IfModule>
  # end php

  # cgi: 1 don't edit between this and the "end cgi" comment below
  <Directory /home/example/ee.example.com/html>
    AllowOverride  All
  </Directory>

  <Location />
    Options +ExecCGI
  </Location>
  ScriptAlias /cgi-bin/ /home/example/ee.example.com/html/cgi-bin/
  # end cgi

</VirtualHost>
